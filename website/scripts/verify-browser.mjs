#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");
const root = process.cwd();
const routes = JSON.parse(readFileSync(resolve(root, "src/content/public-routes.json"), "utf8")).map((entry) => entry.path);
const artifactDir = resolve(root, process.env.VERIFY_ARTIFACT_DIR || "verification-artifacts");
mkdirSync(artifactDir, { recursive: true });

function findChrome() {
  if (process.env.CHROME_BIN) return process.env.CHROME_BIN;
  for (const candidate of ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]) {
    const result = spawnSync("which", [candidate], { encoding: "utf8" });
    if (result.status === 0 && result.stdout.trim()) return result.stdout.trim();
  }
  throw new Error("Chrome/Chromium executable not found");
}

async function waitForJson(url, timeoutMs = 20_000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok) return await response.json();
    } catch {
      // Retry while Chrome starts.
    }
    await sleep(150);
  }
  throw new Error(`Timed out waiting for ${url}`);
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
      const timer = setTimeout(() => rejectOpen(new Error("Timed out opening Chrome DevTools websocket")), 10_000);
      this.socket.addEventListener("open", () => {
        clearTimeout(timer);
        resolveOpen();
      }, { once: true });
      this.socket.addEventListener("error", (event) => {
        clearTimeout(timer);
        rejectOpen(new Error(`Chrome DevTools websocket error: ${event.message || "unknown"}`));
      }, { once: true });
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
    const listeners = this.listeners.get(message.method) || [];
    for (const listener of [...listeners]) listener(message.params || {});
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
    return () => this.listeners.set(method, (this.listeners.get(method) || []).filter((item) => item !== listener));
  }

  waitFor(method, timeoutMs = 20_000) {
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

function routeSlug(path) {
  return path === "/" ? "home" : path.slice(1).replaceAll("/", "-");
}

const chrome = findChrome();
const debuggingPort = 9222 + Math.floor(Math.random() * 500);
const chromeLog = resolve(artifactDir, "chrome.log");
const chromeProcess = spawn(chrome, [
  "--headless=new",
  "--no-sandbox",
  "--disable-dev-shm-usage",
  "--disable-gpu",
  "--hide-scrollbars",
  `--remote-debugging-port=${debuggingPort}`,
  `--user-data-dir=/tmp/cmdtab-chrome-${process.pid}`,
  "about:blank",
], {
  stdio: ["ignore", "ignore", "pipe"],
});
let chromeLogText = "";
chromeProcess.stderr.on("data", (chunk) => {
  chromeLogText += chunk.toString();
});

const failures = [];
const report = [];
const fail = (message) => failures.push(message);

try {
  await waitForJson(`http://127.0.0.1:${debuggingPort}/json/version`);
  const targetResponse = await fetch(`http://127.0.0.1:${debuggingPort}/json/new?about:blank`, { method: "PUT" });
  assert.equal(targetResponse.ok, true, "could not create Chrome page target");
  const target = await targetResponse.json();
  const client = new CDPClient(target.webSocketDebuggerUrl);
  await client.open();
  await Promise.all([
    client.send("Page.enable"),
    client.send("Runtime.enable"),
    client.send("Network.enable"),
    client.send("Log.enable"),
  ]);

  const profiles = [
    { name: "desktop", width: 1440, height: 1000, mobile: false },
    { name: "mobile", width: 390, height: 844, mobile: true },
  ];
  const screenshotRoutes = new Set([
    "/",
    "/features/window-switcher",
    "/guides/switch-between-windows-on-mac",
    "/compare/cmdtab-vs-macos-command-tab",
    "/faq",
    "/buy",
    "/privacy",
  ]);

  for (const profile of profiles) {
    await client.send("Emulation.setDeviceMetricsOverride", {
      width: profile.width,
      height: profile.height,
      deviceScaleFactor: 1,
      mobile: profile.mobile,
      screenWidth: profile.width,
      screenHeight: profile.height,
    });

    for (const path of routes) {
      const consoleErrors = [];
      const exceptions = [];
      const failedRequests = [];
      const badResponses = [];
      const cleanups = [
        client.on("Runtime.exceptionThrown", ({ exceptionDetails }) => {
          exceptions.push(exceptionDetails?.exception?.description || exceptionDetails?.text || "unknown exception");
        }),
        client.on("Runtime.consoleAPICalled", ({ type, args }) => {
          if (["error", "assert"].includes(type)) {
            consoleErrors.push(args?.map((item) => item.value || item.description || "").join(" ") || type);
          }
        }),
        client.on("Log.entryAdded", ({ entry }) => {
          if (["error", "warning"].includes(entry?.level) && !String(entry?.text || "").includes("favicon")) {
            consoleErrors.push(`${entry.level}: ${entry.text}`);
          }
        }),
        client.on("Network.loadingFailed", ({ requestId, errorText, canceled }) => {
          if (!canceled && !String(errorText).includes("ERR_ABORTED")) failedRequests.push(`${requestId}: ${errorText}`);
        }),
        client.on("Network.responseReceived", ({ response, type }) => {
          const url = String(response?.url || "");
          if (url.startsWith(baseUrl) && !url.includes("/_vercel/") && Number(response?.status || 0) >= 400) {
            badResponses.push(`${type || "resource"} ${response.status} ${url}`);
          }
        }),
      ];

      const loaded = client.waitFor("Page.loadEventFired", 25_000);
      await client.send("Page.navigate", { url: `${baseUrl}${path}` });
      await loaded;
      await sleep(500);
      await client.send("Runtime.evaluate", {
        expression: `new Promise(async (resolve) => {
          const max = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
          for (let y = 0; y <= max; y += Math.max(500, window.innerHeight * 0.8)) {
            window.scrollTo(0, y);
            await new Promise((r) => setTimeout(r, 25));
          }
          window.scrollTo(0, 0);
          await new Promise((r) => setTimeout(r, 250));
          resolve(true);
        })`,
        awaitPromise: true,
        returnByValue: true,
      });

      const evaluated = await client.send("Runtime.evaluate", {
        expression: `(() => {
          const images = [...document.images];
          const visiblePrimaryLinks = [...document.querySelectorAll('header a, header button, header summary')]
            .filter((element) => {
              const style = getComputedStyle(element);
              const rect = element.getBoundingClientRect();
              return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
            })
            .map((element) => (element.textContent || element.getAttribute('aria-label') || '').trim())
            .filter(Boolean);
          return {
            url: location.href,
            title: document.title,
            readyState: document.readyState,
            bodyTextLength: document.body.innerText.trim().length,
            h1Count: document.querySelectorAll('h1').length,
            h1Text: [...document.querySelectorAll('h1')].map((node) => node.textContent.trim()),
            errorOverlay: Boolean(document.querySelector('[data-nextjs-dialog], #webpack-dev-server-client-overlay, .vite-error-overlay')),
            horizontalOverflow: Math.max(document.body.scrollWidth, document.documentElement.scrollWidth) - window.innerWidth,
            brokenImages: images.filter((image) => image.complete && image.naturalWidth === 0).map((image) => image.currentSrc || image.src),
            incompleteImages: images.filter((image) => !image.complete).map((image) => image.currentSrc || image.src),
            visiblePrimaryLinks,
          };
        })()`,
        returnByValue: true,
      });
      const result = evaluated.result?.value || {};
      report.push({ profile: profile.name, path, ...result, consoleErrors, exceptions, failedRequests, badResponses });

      if (result.readyState !== "complete") fail(`${profile.name} ${path}: document did not reach complete state`);
      if (result.bodyTextLength < 250) fail(`${profile.name} ${path}: body is suspiciously short`);
      if (result.h1Count !== 1) fail(`${profile.name} ${path}: expected one H1, found ${result.h1Count}`);
      if (result.errorOverlay) fail(`${profile.name} ${path}: framework error overlay is visible`);
      if (result.horizontalOverflow > 4) fail(`${profile.name} ${path}: horizontal overflow is ${result.horizontalOverflow}px`);
      if (result.brokenImages?.length) fail(`${profile.name} ${path}: broken images ${result.brokenImages.join(", ")}`);
      if (result.incompleteImages?.length) fail(`${profile.name} ${path}: images did not finish loading ${result.incompleteImages.join(", ")}`);
      if (consoleErrors.length) fail(`${profile.name} ${path}: console errors ${consoleErrors.join(" | ")}`);
      if (exceptions.length) fail(`${profile.name} ${path}: runtime exceptions ${exceptions.join(" | ")}`);
      if (failedRequests.length) fail(`${profile.name} ${path}: failed requests ${failedRequests.join(" | ")}`);
      if (badResponses.length) fail(`${profile.name} ${path}: bad same-origin responses ${badResponses.join(" | ")}`);
      if (profile.mobile && path !== "/" && (result.visiblePrimaryLinks?.length || 0) < 2) {
        fail(`mobile ${path}: header exposes fewer than two visible navigation controls`);
      }

      if (screenshotRoutes.has(path)) {
        const screenshot = await client.send("Page.captureScreenshot", { format: "png", fromSurface: true });
        writeFileSync(resolve(artifactDir, `${profile.name}-${routeSlug(path)}.png`), Buffer.from(screenshot.data, "base64"));
      }
      cleanups.forEach((cleanup) => cleanup());
    }
  }

  await client.send("Emulation.setDeviceMetricsOverride", {
    width: 1440,
    height: 1000,
    deviceScaleFactor: 1,
    mobile: false,
  });
  const loaded = client.waitFor("Page.loadEventFired", 25_000);
  await client.send("Page.navigate", { url: `${baseUrl}/` });
  await loaded;
  await sleep(700);
  const interaction = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const buttonByText = (text) => [...document.querySelectorAll('button')].find((button) => button.textContent.includes(text));
      const pause = buttonByText('Pause auto-demo');
      if (pause) pause.click();
      const commandPalette = buttonByText('Command Palette');
      if (!commandPalette) return resolve({ ok: false, reason: 'Command Palette control missing' });
      commandPalette.click();
      await new Promise((r) => setTimeout(r, 450));
      const input = document.querySelector('input[placeholder="Type to filter…"]');
      if (!input) return resolve({ ok: false, reason: 'Command Palette input missing after mode change' });
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      setter.call(input, 'Spotify');
      input.dispatchEvent(new Event('input', { bubbles: true }));
      await new Promise((r) => setTimeout(r, 250));
      const bodyText = document.body.innerText;
      resolve({
        ok: bodyText.includes('Spotify') && !bodyText.includes('No matches'),
        value: input.value,
        resultTextPresent: bodyText.includes('Deep work mix'),
      });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const interactionResult = interaction.result?.value || {};
  if (!interactionResult.ok || interactionResult.value !== "Spotify" || !interactionResult.resultTextPresent) {
    fail(`homepage interactive demo failed: ${JSON.stringify(interactionResult)}`);
  }

  client.close();
} finally {
  chromeProcess.kill("SIGTERM");
  writeFileSync(chromeLog, chromeLogText);
  writeFileSync(resolve(artifactDir, "browser-report.json"), JSON.stringify({ baseUrl, report, failures }, null, 2));
}

if (failures.length) {
  console.error("Browser verification FAILED:");
  failures.forEach((message, index) => console.error(`  ${index + 1}. ${message}`));
  process.exit(1);
}

console.log(`Browser verification passed for ${routes.length} routes at desktop and mobile viewports, plus the live demo interaction.`);
