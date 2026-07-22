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
    (localRun && message.includes("Failed to load resource: the server responded with a status of 404"))
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
    "--autoplay-policy=no-user-gesture-required",
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
  await client.send("Emulation.setEmulatedMedia", {
    media: "screen",
    features: [{ name: "prefers-reduced-motion", value: "no-preference" }],
  });

  const profiles = [
    { name: "desktop", width: 1440, height: 1000, mobile: false },
    { name: "mobile", width: 390, height: 844, mobile: true },
  ];
  const screenshotRoutes = new Set(["/", "/showcase", "/features/window-switcher", "/buy"]);

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
          const message = args?.map((item) => item.value || item.description || "").join(" ") || type;
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
      await sleep(path === "/" || path === "/showcase" ? 1400 : 350);

      await client.send("Runtime.evaluate", {
        expression: `new Promise(async (resolve) => {
          if (document.fonts?.ready) await document.fonts.ready;
          document.documentElement.style.scrollBehavior = 'auto';
          document.body.style.scrollBehavior = 'auto';
          await Promise.race([
            Promise.all([...document.images].map((image) => image.complete
              ? Promise.resolve()
              : new Promise((done) => {
                  image.addEventListener('load', done, { once: true });
                  image.addEventListener('error', done, { once: true });
                }))),
            new Promise((done) => setTimeout(done, 8000)),
          ]);
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
          const size = (element) => {
            const rect = element.getBoundingClientRect();
            return { text: (element.textContent || element.getAttribute('aria-label') || '').trim(), width: rect.width, height: rect.height };
          };
          const images = [...document.images];
          const videos = [...document.querySelectorAll('video')].map((video) => ({
            autoplay: video.autoplay,
            autoplayMode: video.dataset.autoplayMode || null,
            muted: video.muted,
            loop: video.loop,
            playsInline: video.playsInline,
            paused: video.paused,
            ended: video.ended,
            currentTime: video.currentTime,
            duration: Number.isFinite(video.duration) ? video.duration : null,
            readyState: video.readyState,
            width: video.getBoundingClientRect().width,
            height: video.getBoundingClientRect().height,
          }));
          const visibleControls = [...document.querySelectorAll('a, button, summary')].filter(visible);
          const playbackControls = visibleControls
            .filter((element) => /^(play|pause)(?:\s|$)/i.test((element.textContent || element.getAttribute('aria-label') || '').trim()))
            .map(size);
          const descriptionControls = visibleControls
            .filter((element) => /read the media description/i.test((element.textContent || '').trim()))
            .map(size);
          const ctas = visibleControls
            .filter((element) => /trial|buy|watch cmdtab|download|start/i.test((element.textContent || element.getAttribute('aria-label') || '').trim()))
            .map(size);
          const modeMetadata = [...document.querySelectorAll('dt')]
            .filter(visible)
            .map((element) => (element.textContent || '').trim())
            .filter((text) => /^(resolution|format|source|frame rate|duration)$/i.test(text));
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
            errorOverlay: Boolean(document.querySelector('[data-nextjs-dialog], #webpack-dev-server-client-overlay, .vite-error-overlay')),
            horizontalOverflow: Math.max(document.body.scrollWidth, document.documentElement.scrollWidth) - window.innerWidth,
            brokenImages: images.filter((image) => image.complete && image.naturalWidth === 0).map((image) => image.currentSrc || image.src),
            incompleteImages: images.filter((image) => !image.complete).map((image) => image.currentSrc || image.src),
            visibleHeaderControls: [...document.querySelectorAll('header a, header button, header summary')].filter(visible).map(size),
            unnamedVisibleControls: visibleControls
              .filter((element) => !(element.textContent || element.getAttribute('aria-label') || element.getAttribute('title') || '').trim())
              .map((element) => element.outerHTML.slice(0, 180)),
            playbackControls,
            descriptionControls,
            ctas,
            modeMetadata,
            videos,
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
            if (!details) return resolve({ present: false, links: [] });
            details.open = true;
            await new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)));
            const links = [...details.querySelectorAll('nav a')].filter((link) => {
              const style = getComputedStyle(link);
              const rect = link.getBoundingClientRect();
              return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
            }).map((link) => {
              const rect = link.getBoundingClientRect();
              return { text: (link.textContent || '').trim(), width: rect.width, height: rect.height };
            });
            resolve({ present: true, links });
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
      if (result.bodyTextLength < 150) fail(`${profile.name} ${path}: rendered body is suspiciously short`);
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

      for (const target of result.ctas || []) {
        if (target.height < 44 || target.width < 44) {
          fail(`${profile.name} ${path}: CTA target is too small ${JSON.stringify(target)}`);
        }
      }

      if (["/", "/showcase"].includes(path)) {
        if (result.playbackControls?.length) {
          fail(`${profile.name} ${path}: play or pause controls are still visible`);
        }
        if (result.descriptionControls?.length) {
          fail(`${profile.name} ${path}: media description controls are still visible`);
        }
        if (path === "/showcase" && result.modeMetadata?.length) {
          fail(`${profile.name} ${path}: removed media metadata is still visible`);
        }
        if (!result.videos?.length) {
          fail(`${profile.name} ${path}: autoplay product video is missing`);
        } else {
          const firstVideo = result.videos[0];
          if (!firstVideo.muted || firstVideo.loop || !firstVideo.playsInline || firstVideo.autoplayMode !== "one-shot") {
            fail(`${profile.name} ${path}: first video is not configured for silent one-shot inline autoplay`);
          }
          if (firstVideo.duration === null || firstVideo.duration > 5.05) {
            fail(`${profile.name} ${path}: first autoplay video exceeds five seconds`);
          }
          if (firstVideo.paused || firstVideo.readyState < 2) {
            fail(`${profile.name} ${path}: first video did not start autoplaying`);
          }
        }
      }

      if (profile.mobile) {
        if ((result.visibleHeaderControls?.length || 0) < 2) {
          fail(`mobile ${path}: header exposes fewer than two visible navigation controls`);
        }
        for (const target of result.visibleHeaderControls || []) {
          if (target.height < 44 || target.width < 44) {
            fail(`mobile ${path}: header target is too small ${JSON.stringify(target)}`);
          }
        }
        if (!mobileMenuResult?.present || (mobileMenuResult.links?.length || 0) < 6) {
          fail(`mobile ${path}: mobile navigation does not expose the maintained site links`);
        }
        for (const target of mobileMenuResult?.links || []) {
          if (target.height < 44 || target.width < 44) {
            fail(`mobile ${path}: menu target is too small ${JSON.stringify(target)}`);
          }
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
  await client.send("Emulation.setEmulatedMedia", {
    media: "screen",
    features: [{ name: "prefers-reduced-motion", value: "no-preference" }],
  });
  let loaded = client.waitFor("Page.loadEventFired");
  await client.send("Page.navigate", { url: `${baseUrl}/` });
  await loaded;
  await sleep(900);
  const oneShotEvaluation = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const video = document.querySelector('video');
      if (!video) return resolve({ ok: false, reason: 'video missing' });
      await new Promise((done) => {
        if (video.readyState >= 1) done();
        else video.addEventListener('loadedmetadata', done, { once: true });
      });
      video.currentTime = Math.max(0, video.duration - 0.12);
      await video.play();
      await new Promise((done) => setTimeout(done, 500));
      window.scrollTo(0, document.body.scrollHeight);
      await new Promise((done) => setTimeout(done, 200));
      window.scrollTo(0, 0);
      await new Promise((done) => setTimeout(done, 500));
      resolve({
        ok: video.ended && video.paused && !video.loop && video.dataset.autoplayMode === 'one-shot',
        ended: video.ended,
        paused: video.paused,
        loop: video.loop,
        currentTime: video.currentTime,
        duration: video.duration,
        autoplayMode: video.dataset.autoplayMode || null,
      });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const oneShotResult = oneShotEvaluation.result?.value || {};
  if (!oneShotResult.ok) {
    fail(`one-shot autoplay replay guard failed: ${JSON.stringify(oneShotResult)}`);
  }

  await client.send("Emulation.setEmulatedMedia", {
    media: "screen",
    features: [{ name: "prefers-reduced-motion", value: "reduce" }],
  });
  loaded = client.waitFor("Page.loadEventFired");
  await client.send("Page.navigate", { url: `${baseUrl}/` });
  await loaded;
  await sleep(900);
  const reducedMotionEvaluation = await client.send("Runtime.evaluate", {
    expression: `(() => {
      const video = document.querySelector('video');
      if (!video) return { ok: false, reason: 'video missing' };
      return {
        ok: video.paused && video.currentTime <= 0.1,
        paused: video.paused,
        currentTime: video.currentTime,
      };
    })()`,
    returnByValue: true,
  });
  const reducedMotionResult = reducedMotionEvaluation.result?.value || {};
  if (!reducedMotionResult.ok) {
    fail(`reduced-motion autoplay guard failed: ${JSON.stringify(reducedMotionResult)}`);
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
  `Browser verification passed for ${routes.length} routes at desktop and mobile viewports, one-shot autoplay, reduced-motion safety, 44px targets, mobile navigation, and accessible wide tables.`,
);
