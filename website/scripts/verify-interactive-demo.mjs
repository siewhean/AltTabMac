#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
const baseUrl = process.env.VERIFY_BASE_URL || "http://127.0.0.1:44117";
if (!["127.0.0.1", "localhost", "[::1]"].includes(new URL(baseUrl).hostname)) throw new Error("Demo QA only supports a local server");
const artifactDir = resolve(process.env.VERIFY_ARTIFACT_DIR || "/tmp/cmdtab-demo-qa/browser");
mkdirSync(artifactDir, { recursive: true });
const chrome = process.env.CHROME_BIN || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
async function waitForDevToolsPort(userDataDir, processHandle, getChromeLog, timeoutMs = 25_000) {
  const portFile = resolve(userDataDir, "DevToolsActivePort");
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (processHandle.exitCode !== null) {
      throw new Error(
        `Chrome exited before DevTools started (exit ${processHandle.exitCode}).\n${getChromeLog()}`,
      );
    }
    if (existsSync(portFile)) {
      const [portLine] = readFileSync(portFile, "utf8").trim().split(/\r?\n/);
      const port = Number.parseInt(portLine, 10);
      if (Number.isInteger(port) && port > 0 && port <= 65535) return port;
    }
    await sleep(100);
  }
  throw new Error(`Timed out waiting for Chrome DevToolsActivePort.\n${getChromeLog()}`);
}

class CDPClient {
  constructor(url) {
    this.socket = new WebSocket(url);
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
  }

  async open() {
    await new Promise((resolveOpen, rejectOpen) => {
      const timer = setTimeout(
        () => rejectOpen(new Error("Timed out opening the Chrome DevTools websocket")),
        10_000,
      );
      this.socket.addEventListener(
        "open",
        () => {
          clearTimeout(timer);
          resolveOpen();
        },
        { once: true },
      );
      this.socket.addEventListener(
        "error",
        (event) => {
          clearTimeout(timer);
          rejectOpen(new Error(`Chrome DevTools websocket error: ${event.message || "unknown"}`));
        },
        { once: true },
      );
    });
    this.socket.addEventListener("message", (event) => this.handleMessage(event.data));
  }

  handleMessage(raw) {
    const message = JSON.parse(String(raw));
    if (message.id) {
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      if (message.error) pending.reject(new Error(`${pending.method}: ${message.error.message}`));
      else pending.resolve(message.result || {});
      return;
    }
    for (const listener of [...(this.listeners.get(message.method) || [])]) {
      listener(message.params || {});
    }
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolveSend, rejectSend) => {
      this.pending.set(id, { resolve: resolveSend, reject: rejectSend, method });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }

  on(method, listener) {
    const listeners = this.listeners.get(method) || [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
    return () => {
      this.listeners.set(
        method,
        (this.listeners.get(method) || []).filter((candidate) => candidate !== listener),
      );
    };
  }

  waitFor(method, timeoutMs = 25_000) {
    return new Promise((resolveEvent, rejectEvent) => {
      const cleanup = this.on(method, (params) => {
        clearTimeout(timer);
        cleanup();
        resolveEvent(params);
      });
      const timer = setTimeout(() => {
        cleanup();
        rejectEvent(new Error(`Timed out waiting for Chrome event ${method}`));
      }, timeoutMs);
    });
  }

  close() {
    this.socket.close();
  }
}


const profile = mkdtempSync('/tmp/cmdtab-demo-chrome-');
let client;
let chromeLog = '';
const processHandle = spawn(chrome, ['--headless=new', '--disable-gpu', '--no-first-run', '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank']);
processHandle.stderr.on('data', data => chromeLog += String(data));
const failures = [];
const errors = [];
try {
  const port = await waitForDevToolsPort(profile, processHandle, () => chromeLog);
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  client = new CDPClient(tabs.find(tab => tab.type === 'page').webSocketDebuggerUrl);
  await client.open();
  await client.send('Page.enable'); await client.send('Runtime.enable');
  client.on('Runtime.exceptionThrown', event => errors.push(event.exceptionDetails.text));
  await client.send('Fetch.enable', {patterns:[{urlPattern:'*',requestStage:'Request'}]});
  client.on('Fetch.requestPaused', event => { void client.send(event.request.method === 'GET' || event.request.method === 'HEAD' ? 'Fetch.continueRequest' : 'Fetch.failRequest', event.request.method === 'GET' || event.request.method === 'HEAD' ? {requestId:event.requestId} : {requestId:event.requestId,errorReason:'BlockedByClient'}); });
  const evaluate = async expression => {
    const result = await client.send('Runtime.evaluate', {expression,returnByValue:true,awaitPromise:true});
    if(result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result.value;
  };
  const click = async text => { await evaluate(`(()=>{const button=[...document.querySelectorAll('[data-demo] button')].find(b=>b.textContent.trim()===${JSON.stringify(text)}||b.firstElementChild?.textContent.trim()===${JSON.stringify(text)}); if(!button)throw new Error('Missing control'); button.click()})()`); await sleep(100); };
  const check = async (name, expression) => { if(!await evaluate(expression))failures.push(name); };
  for(const [name,width,height,reduced] of [['desktop',1440,1000,false],['mobile',390,844,false],['narrow',320,720,true]]) {
    await client.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
    await client.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
    await client.send('Page.navigate',{url:baseUrl});
    for(let attempt=0;attempt<100;attempt++){if(await evaluate(`Boolean(document.querySelector('[data-demo-window-id]'))`))break; await sleep(100);}
    await sleep(700);
    await evaluate(`(()=>{const b=[...document.querySelectorAll('button')].find(e=>e.textContent.trim()==='Decline');b?.click()})()`); await sleep(100);
    const count = `document.querySelectorAll('[data-demo-window-id]').length`;
    const status = `document.querySelector('[data-demo] [role=status]').textContent`;
    const key = async (value, code, vk) => { await client.send('Input.dispatchKeyEvent',{type:'keyDown',key:value,code,windowsVirtualKeyCode:vk,text:value}); await client.send('Input.dispatchKeyEvent',{type:'keyUp',key:value,code,windowsVirtualKeyCode:vk}); await sleep(100); };
    const focusStage = () => evaluate(`document.querySelector('[aria-label="Sample window switcher"]').focus()`);
    await check(`${name}: ten distinct sample windows`, `${count}===10 && new Set([...document.querySelectorAll('[data-demo-window-id]')].map(e=>e.dataset.demoWindowId)).size===10`);
    await check(`${name}: quick-action buttons show native shortcuts`, `['hide:⌘H','minimize:⌘M','close:⌘W','quit:⌘Q'].every(pair=>{const [kind,shortcut]=pair.split(':');return document.querySelector('[data-demo-action="'+kind+'"] kbd')?.textContent===shortcut})`);
    await check(`${name}: include minimized defaults off`, `document.querySelector('[data-demo] input[type=checkbox]').checked===false`);
    await evaluate(`document.querySelector('[aria-label="Sample window switcher"]').focus()`);
    await client.send('Input.dispatchKeyEvent',{type:'keyDown',key:'ArrowRight',code:'ArrowRight',windowsVirtualKeyCode:39}); await sleep(100);
    await check(`${name}: arrow changes selection`, `document.querySelector('[data-demo-window-id][aria-current=true]').dataset.demoWindowId==='claude-review'`);
    await client.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9}); await sleep(100);
    await check(`${name}: Tab moves focus`, `document.activeElement!==document.querySelector('[aria-label="Sample window switcher"]')`);
    await check(`${name}: two Finder windows`, `[...document.querySelectorAll('[data-demo-window-id]')].filter(e=>e.getAttribute('aria-label').startsWith('Activate Finder:')).length===2`);
    await evaluate(`document.querySelector('[data-demo-window-id="finder-downloads"]').click()`); await sleep(100);
    await check(`${name}: exact click commits`, `document.querySelector('[data-demo] [role=status]').textContent.includes('Finder · Downloads') && !document.querySelector('[data-demo-window-id]')`);
    await click('Open sample switcher');
    await check(`${name}: current window last`, `[...document.querySelectorAll('[data-demo-window-id]')].at(-1).dataset.demoWindowId==='finder-downloads'`);
    await click('Hide app');
    await check(`${name}: hidden app retains both windows`, `[...document.querySelectorAll('[data-demo-window-id]')].filter(e=>e.textContent.includes('Hidden app')).length===2`);
    await click('Minimize window');
    await check(`${name}: minimize leaves the window out by default`, `${count}===9 && !document.querySelector('[data-demo-window-id="finder-project"]') && ${status}.includes('left out of the switcher by default')`);
    await evaluate(`document.querySelector('[data-demo] input[type=checkbox]').click()`); await sleep(100);
    await check(`${name}: include minimized lists it again`, `${count}===10 && document.querySelector('[data-demo-window-id="finder-project"]').textContent.includes('Minimized window')`);
    await click('Close window'); await check(`${name}: close only one`, `${count}===9`);
    await click('Reset sample windows'); await click('Quit app'); await check(`${name}: quit removes app siblings`, `${count}===8`);
    await click('Reset sample windows'); await focusStage();
    await key('h','KeyH',72); await check(`${name}: H hides the selected app`, `${status}.includes('Hidden sample app: Finder')`);
    await key('q','KeyQ',81); await check(`${name}: bare Q does not quit`, `${count}===10 && ${status}.includes('Q on its own does nothing')`);
    await key('w','KeyW',87); await check(`${name}: W closes one window`, `${count}===9 && ${status}.includes('Closed sample window')`);
    await key('m','KeyM',77); await check(`${name}: M minimizes and leaves it out`, `${count}===8 && ${status}.includes('Minimized sample window')`);
    await click('Reset sample windows'); await click('Command Palette');
    await evaluate(`document.querySelector('input[aria-label="Search sample windows"]').focus()`);
    await key('w','KeyW',87); await check(`${name}: palette letters type into search`, `document.querySelector('input[aria-label="Search sample windows"]').value==='w' && !${status}.includes('Closed')`);
    await evaluate(`(()=>{const i=document.querySelector('input[aria-label="Search sample windows"]'); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(i,'Downloads'); i.dispatchEvent(new Event('input',{bubbles:true}));i.focus()})()`); await sleep(100);
    await check(`${name}: title ranking`, `document.querySelector('[data-demo-window-id][aria-current=true]').dataset.demoWindowId==='finder-downloads'`);
    await client.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',windowsVirtualKeyCode:13}); await sleep(100);
    await check(`${name}: Enter commits search`, `document.querySelector('[data-demo] [role=status]').textContent.includes('Finder · Downloads')`);
    await click('Open sample switcher');
    await client.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27}); await sleep(100);
    await check(`${name}: Escape cancels`, `document.querySelector('[data-demo] [role=status]').textContent.includes('Cancelled')`);
    await check(`${name}: cancel focus recovery`, `document.activeElement.textContent==='Open sample switcher'`);
    await evaluate(`document.querySelector('[aria-label="Sample window switcher"]').dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}))`);
    await check(`${name}: cancelled stage cannot activate`, `document.querySelector('[data-demo] [role=status]').textContent.includes('Cancelled')`);
    await click('Reset sample windows'); await click('Radial Menu');
    await check(`${name}: radial eight slots`, `${count}===8 && Boolean(document.querySelector('[data-demo-radial-overflow]'))`);
    await check(`${name}: centered icons and selectors`, `(()=>{const nodes=[...document.querySelectorAll('[data-demo-radial-selector]')];return nodes.length===8&&nodes.every(n=>{const b=n.getBoundingClientRect(),i=n.querySelector('img').getBoundingClientRect();return Math.abs(b.x+b.width/2-i.x-i.width/2)<0.5&&Math.abs(b.y+b.height/2-i.y-i.height/2)<0.5&&b.width>=44&&i.width>=b.width*0.65&&i.width<b.width})})()`);
    await check(`${name}: ring selectors do not overlap`, `(()=>{const a=[...document.querySelectorAll('[data-demo-radial-selector]')].map(n=>n.getBoundingClientRect());return a.every((b,j)=>a.slice(j+1).every(c=>Math.hypot(b.x+b.width/2-c.x-c.width/2,b.y+b.height/2-c.y-c.height/2)>(b.width+c.width)/2))})()`);
    await focusStage();
    for (let step = 0; step < 4; step++) await client.send('Input.dispatchKeyEvent',{type:'keyDown',key:'ArrowRight',code:'ArrowRight',windowsVirtualKeyCode:39});
    await sleep(100);
    await check(`${name}: radial scrolls the ninth window onto the ring`, `${count}===8 && Boolean(document.querySelector('[data-demo-window-id="calendar-release"]')) && document.querySelector('[data-demo-window-id][aria-current=true]').dataset.demoWindowId==='claude-research'`);
    await evaluate(`document.querySelector('[aria-label="Sample window switcher"]').scrollIntoView({block:'start'})`);
    await check(`${name}: no horizontal overflow`, `document.documentElement.scrollWidth<=${width}+1`);
    await check(`${name}: no animation`, `[...document.querySelectorAll('[data-demo] *')].every(e=>getComputedStyle(e).animationName==='none')`);
    const screenshot=await client.send('Page.captureScreenshot',{format:'png'});
    writeFileSync(resolve(artifactDir,`${name}-radial.png`),Buffer.from(screenshot.data,'base64'));
    await click('Classic Grid');
    const gridShot=await client.send('Page.captureScreenshot',{format:'png'});
    writeFileSync(resolve(artifactDir,`${name}-grid.png`),Buffer.from(gridShot.data,'base64'));
  }
  assert.deepEqual(errors,[], 'Browser runtime errors');
  assert.deepEqual(failures,[], 'Demo interaction failures');
  writeFileSync(resolve(artifactDir,'report.json'),JSON.stringify({status:'PASS',profiles:3,failures,errors,mutatingRequests:'blocked'},null,2));
  console.log('Interactive demo browser checks passed on desktop, mobile, and reduced-motion narrow layouts.');
} finally {client?.close();processHandle.kill(); await sleep(500); rmSync(profile,{recursive:true,force:true,maxRetries:5,retryDelay:200});}
