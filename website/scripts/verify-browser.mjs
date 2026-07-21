#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { resolve } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");
const localRun = /^http:\/\/(127\.0\.0\.1|localhost)(:|\/|$)/.test(baseUrl);
const root = process.cwd();
const routes = JSON.parse(readFileSync(resolve(root, "src/content/public-routes.json"), "utf8")).map(
  (entry) => entry.path,
);
const artifactDir = resolve(root, process.env.VERIFY_ARTIFACT_DIR || "verification-artifacts");
mkdirSync(artifactDir, { recursive: true });

function findChrome() {
  if (process.env.CHROME_BIN) return process.env.CHROME_BIN;
  for (const candidate of ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]) {
    const result = spawnSync("which", [candidate], { encoding: "utf8" });
    if (result.status === 0 && result.stdout.trim()) return result.stdout.trim();
  }
  throw new Error("Chrome or Chromium was not found");
}

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
  throw new Error(
    `Timed out waiting for Chrome DevToolsActivePort in ${userDataDir}.\n${getChromeLog()}`,
  );
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

function slug(path) {
  return path === "/" ? "home" : path.slice(1).replaceAll("/", "-");
}

function expectedLocalVercelNoise(message) {
  return (
    localRun &&
    (message.includes("/_vercel/insights/") || message.includes("/_vercel/speed-insights/"))
  );
}

function expectedLocalConsoleNoise(message) {
  return (
    expectedLocalVercelNoise(message) ||
    (localRun &&
      message.includes("Failed to load resource: the server responded with a status of 404 (Not Found)"))
  );
}

const chrome = findChrome();
const chromeUserDataDir = mkdtempSync("/tmp/cmdtab-chrome-");
const chromeLogPath = resolve(artifactDir, "chrome.log");
const chromeProcess = spawn(
  chrome,
  [
    "--headless=new",
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--disable-gpu",
    "--disable-background-networking",
    "--disable-default-apps",
    "--disable-extensions",
    "--disable-sync",
    "--hide-scrollbars",
    "--no-first-run",
    "--no-default-browser-check",
    "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=0",
    `--user-data-dir=${chromeUserDataDir}`,
    "about:blank",
  ],
  { stdio: ["ignore", "ignore", "pipe"] },
);
let chromeLog = "";
chromeProcess.stderr.on("data", (chunk) => {
  chromeLog += chunk.toString();
});

const failures = [];
const report = [];
const fail = (message) => failures.push(message);
let client;

try {
  const debuggingPort = await waitForDevToolsPort(
    chromeUserDataDir,
    chromeProcess,
    () => chromeLog,
  );
  const targetResponse = await fetch(`http://127.0.0.1:${debuggingPort}/json/new?about:blank`, {
    method: "PUT",
  });
  assert.equal(targetResponse.ok, true, "could not create a Chrome page target");
  const target = await targetResponse.json();
  client = new CDPClient(target.webSocketDebuggerUrl);
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
      const requestUrls = new Map();
      const cleanups = [
        client.on("Network.requestWillBeSent", ({ requestId, request }) => {
          requestUrls.set(requestId, String(request?.url || ""));
        }),
        client.on("Runtime.exceptionThrown", ({ exceptionDetails }) => {
          exceptions.push(
            exceptionDetails?.exception?.description || exceptionDetails?.text || "unknown exception",
          );
        }),
        client.on("Runtime.consoleAPICalled", ({ type, args }) => {
          if (!["error", "assert"].includes(type)) return;
          const message =
            args?.map((item) => item.value || item.description || "").join(" ") || type;
          if (!expectedLocalConsoleNoise(message)) consoleErrors.push(message);
        }),
        client.on("Log.entryAdded", ({ entry }) => {
          if (entry?.level !== "error") return;
          const message = `${entry.level}: ${entry.text || ""}`;
          if (!expectedLocalConsoleNoise(message)) consoleErrors.push(message);
        }),
        client.on("Network.loadingFailed", ({ requestId, errorText, canceled }) => {
          if (canceled || String(errorText).includes("ERR_ABORTED")) return;
          const url = requestUrls.get(requestId) || "unknown URL";
          if (!expectedLocalVercelNoise(url)) failedRequests.push(`${errorText}: ${url}`);
        }),
        client.on("Network.responseReceived", ({ response, type }) => {
          const url = String(response?.url || "");
          const status = Number(response?.status || 0);
          if (url.startsWith(baseUrl) && status >= 400 && !expectedLocalVercelNoise(url)) {
            badResponses.push(`${type || "resource"} ${status} ${url}`);
          }
        }),
      ];

      const loaded = client.waitFor("Page.loadEventFired");
      await client.send("Page.navigate", { url: `${baseUrl}${path}` });
      await loaded;
      await sleep(350);

      await client.send("Runtime.evaluate", {
        expression: `new Promise(async (resolve) => {
          if (document.fonts?.ready) await document.fonts.ready;
          document.documentElement.style.scrollBehavior = 'auto';
          document.body.style.scrollBehavior = 'auto';
          const max = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
          for (let y = 0; y <= max; y += Math.max(450, window.innerHeight * 0.7)) {
            window.scrollTo(0, y);
            await new Promise((done) => setTimeout(done, 60));
          }
          await Promise.race([
            Promise.all([...document.images].map((image) => image.complete
              ? Promise.resolve()
              : new Promise((done) => {
                  image.addEventListener('load', done, { once: true });
                  image.addEventListener('error', done, { once: true });
                }))),
            new Promise((done) => setTimeout(done, 8000)),
          ]);
          window.scrollTo(0, 0);
          await new Promise((done) => setTimeout(done, 300));
          resolve(true);
        })`,
        awaitPromise: true,
        returnByValue: true,
      });

      const evaluated = await client.send("Runtime.evaluate", {
        expression: `(() => {
          const visible = (element) => {
            const style = getComputedStyle(element);
            const rect = element.getBoundingClientRect();
            return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
          };
          const images = [...document.images];
          const scrollableTables = [...document.querySelectorAll('table')]
            .map((table) => ({ table, container: table.parentElement }))
            .filter(({ table, container }) => container && table.scrollWidth > container.clientWidth + 2)
            .map(({ container }) => ({
              role: container.getAttribute('role'),
              tabIndex: container.tabIndex,
              overflowX: getComputedStyle(container).overflowX,
              ariaLabel: container.getAttribute('aria-label'),
            }));
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
            visibleHeaderControls: [...document.querySelectorAll('header a, header button, header summary')]
              .filter(visible)
              .map((element) => (element.textContent || element.getAttribute('aria-label') || '').trim())
              .filter(Boolean),
            mobileMenuPresent: Boolean(document.querySelector('header details nav[aria-label="Mobile navigation"]')),
            unnamedVisibleControls: [...document.querySelectorAll('a, button, summary')]
              .filter(visible)
              .filter((element) => !(element.textContent || element.getAttribute('aria-label') || element.getAttribute('title') || '').trim())
              .map((element) => element.outerHTML.slice(0, 180)),
            scrollableTables,
          };
        })()`,
        returnByValue: true,
      });
      const result = evaluated.result?.value || {};

      let mobileMenuResult = null;
      if (profile.mobile) {
        const menuEvaluation = await client.send("Runtime.evaluate", {
          expression: `new Promise(async (resolve) => {
            const details = document.querySelector('header details');
            if (!details) return resolve({ present: false, visibleLinks: 0 });
            details.open = true;
            await new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)));
            const links = [...details.querySelectorAll('nav a')].filter((link) => {
              const style = getComputedStyle(link);
              const rect = link.getBoundingClientRect();
              return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
            });
            resolve({ present: true, visibleLinks: links.length });
          })`,
          awaitPromise: true,
          returnByValue: true,
        });
        mobileMenuResult = menuEvaluation.result?.value || {};
        if (path === "/" && mobileMenuResult.present) {
          const menuScreenshot = await client.send("Page.captureScreenshot", {
            format: "png",
            fromSurface: true,
          });
          writeFileSync(
            resolve(artifactDir, "mobile-home-menu-open.png"),
            Buffer.from(menuScreenshot.data, "base64"),
          );
        }
        await client.send("Runtime.evaluate", {
          expression: `(() => { const details = document.querySelector('header details'); if (details) details.open = false; })()`,
        });
      }

      report.push({
        profile: profile.name,
        path,
        ...result,
        mobileMenuResult,
        consoleErrors,
        exceptions,
        failedRequests,
        badResponses,
      });

      if (result.readyState !== "complete") fail(`${profile.name} ${path}: document did not finish loading`);
      if (result.bodyTextLength < 250) fail(`${profile.name} ${path}: rendered body is suspiciously short`);
      if (result.h1Count !== 1) fail(`${profile.name} ${path}: expected one H1, found ${result.h1Count}`);
      if (result.errorOverlay) fail(`${profile.name} ${path}: a framework error overlay is visible`);
      if (result.horizontalOverflow > 4) {
        fail(`${profile.name} ${path}: document has ${result.horizontalOverflow}px of horizontal overflow`);
      }
      if (result.brokenImages?.length) {
        fail(`${profile.name} ${path}: broken images ${result.brokenImages.join(", ")}`);
      }
      if (result.incompleteImages?.length) {
        fail(`${profile.name} ${path}: images did not finish loading ${result.incompleteImages.join(", ")}`);
      }
      if (result.unnamedVisibleControls?.length) {
        fail(`${profile.name} ${path}: visible controls lack accessible names`);
      }
      for (const table of result.scrollableTables || []) {
        if (table.role !== "region" || table.tabIndex < 0 || !table.ariaLabel) {
          fail(`${profile.name} ${path}: a horizontally scrollable table is not an accessible named keyboard region`);
        }
        if (!["auto", "scroll"].includes(table.overflowX)) {
          fail(`${profile.name} ${path}: a wide table is clipped instead of horizontally scrollable`);
        }
      }
      if (consoleErrors.length) fail(`${profile.name} ${path}: console errors ${consoleErrors.join(" | ")}`);
      if (exceptions.length) fail(`${profile.name} ${path}: runtime exceptions ${exceptions.join(" | ")}`);
      if (failedRequests.length) fail(`${profile.name} ${path}: failed requests ${failedRequests.join(" | ")}`);
      if (badResponses.length) fail(`${profile.name} ${path}: bad same-origin responses ${badResponses.join(" | ")}`);
      if (profile.mobile) {
        if ((result.visibleHeaderControls?.length || 0) < 2) {
          fail(`mobile ${path}: header exposes fewer than two visible navigation controls`);
        }
        if (!mobileMenuResult?.present || mobileMenuResult.visibleLinks < 6) {
          fail(`mobile ${path}: mobile navigation does not expose the maintained site links`);
        }
      }

      if (screenshotRoutes.has(path)) {
        const screenshot = await client.send("Page.captureScreenshot", {
          format: "png",
          fromSurface: true,
        });
        writeFileSync(
          resolve(artifactDir, `${profile.name}-${slug(path)}.png`),
          Buffer.from(screenshot.data, "base64"),
        );
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
  const homeLoaded = client.waitFor("Page.loadEventFired");
  await client.send("Page.navigate", { url: `${baseUrl}/` });
  await homeLoaded;
  await sleep(700);
  const interaction = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const buttonByText = (text) => [...document.querySelectorAll('button')]
        .find((button) => button.textContent.includes(text));
      buttonByText('Pause auto-demo')?.click();
      const paletteButton = buttonByText('Command Palette');
      if (!paletteButton) return resolve({ ok: false, reason: 'Command Palette control missing' });
      paletteButton.click();
      await new Promise((done) => setTimeout(done, 450));
      const input = document.querySelector('input[placeholder="Type to filter…"]');
      if (!input) return resolve({ ok: false, reason: 'Command Palette input missing' });
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      setter.call(input, 'Spotify');
      input.dispatchEvent(new Event('input', { bubbles: true }));
      await new Promise((done) => setTimeout(done, 300));
      const text = document.body.innerText;
      resolve({
        ok: input.value === 'Spotify' && text.includes('Spotify') && text.includes('Deep work mix') && !text.includes('No matches'),
        value: input.value,
        resultTextPresent: text.includes('Deep work mix'),
      });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const interactionResult = interaction.result?.value || {};
  if (!interactionResult.ok) {
    fail(`homepage interactive demo failed: ${JSON.stringify(interactionResult)}`);
  }
} catch (error) {
  fail(`browser harness failed: ${error.stack || error.message || String(error)}`);
} finally {
  try {
    client?.close();
  } catch {
    // Best effort.
  }
  if (chromeProcess.exitCode === null) {
    chromeProcess.kill("SIGTERM");
    await Promise.race([
      new Promise((resolveExit) => chromeProcess.once("exit", resolveExit)),
      sleep(2000),
    ]);
  }
  writeFileSync(
    resolve(artifactDir, "browser-report.json"),
    JSON.stringify({ baseUrl, routes, report, failures }, null, 2),
  );
  try {
    rmSync(chromeUserDataDir, {
      recursive: true,
      force: true,
      maxRetries: 5,
      retryDelay: 100,
    });
  } catch (error) {
    chromeLog += `\nNon-fatal Chrome profile cleanup warning: ${error.message || String(error)}\n`;
  }
  writeFileSync(chromeLogPath, chromeLog);
}

if (failures.length) {
  console.error("Browser verification FAILED:");
  failures.forEach((message, index) => console.error(`  ${index + 1}. ${message}`));
  process.exit(1);
}

console.log(
  `Browser verification passed for ${routes.length} routes at desktop and mobile viewports, mobile navigation, accessible wide tables, and the live demo interaction.`,
);
