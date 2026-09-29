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
const axeSource = readFileSync(resolve(root, "node_modules/axe-core/axe.min.js"), "utf8");
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
const freshProfileAnalyticsRequests = [];

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
  const removeFreshProfileRequestListener = client.on(
    "Network.requestWillBeSent",
    ({ request }) => {
      const url = String(request?.url || "");
      if (
        url.includes("/api/analytics") ||
        url.includes("/_vercel/insights") ||
        url.includes("/_vercel/speed-insights")
      ) {
        freshProfileAnalyticsRequests.push(url);
      }
    },
  );
  await client.send("Emulation.setEmulatedMedia", {
    media: "screen",
    features: [{ name: "prefers-reduced-motion", value: "no-preference" }],
  });

  const profiles = [
    { name: "desktop", width: 1440, height: 1000, mobile: false, motionCheck: true },
    { name: "mobile", width: 390, height: 844, mobile: true, motionCheck: true },
    // Effective CSS viewports for a 1280px desktop at 200% and 400% browser zoom.
    { name: "zoom-200", width: 640, height: 500, mobile: false, motionCheck: false },
    { name: "zoom-400", width: 320, height: 320, mobile: false, motionCheck: false },
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
          const overflowingElements = [...document.body.querySelectorAll('*')]
            .filter(visible)
            .map((element) => {
              const rect = element.getBoundingClientRect();
              let ancestor = element.parentElement;
              let containedByAccessibleScroller = false;
              while (ancestor) {
                const ancestorStyle = getComputedStyle(ancestor);
                const scrollsHorizontally =
                  ['auto', 'scroll'].includes(ancestorStyle.overflowX) &&
                  ancestor.scrollWidth > ancestor.clientWidth + 4;
                if (scrollsHorizontally) {
                  containedByAccessibleScroller =
                    ancestor.getAttribute('role') === 'region' &&
                    ancestor.tabIndex >= 0 &&
                    Boolean(ancestor.getAttribute('aria-label') || ancestor.getAttribute('aria-labelledby'));
                  break;
                }
                ancestor = ancestor.parentElement;
              }
              return {
                tag: element.tagName.toLowerCase(),
                text: (element.textContent || '').trim().slice(0, 80),
                className: typeof element.className === 'string' ? element.className.slice(0, 160) : '',
                left: Math.round(rect.left),
                right: Math.round(rect.right),
                width: Math.round(rect.width),
                containedByAccessibleScroller,
              };
            })
            .filter(({ left, right }) => left < -4 || right > window.innerWidth + 4)
            .slice(0, 12);
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
            overflowingElements,
            scrollableTables,
          };
        })()`,
        returnByValue: true,
      });
      const result = evaluated.result?.value || {};
      let seriousAxeViolations = [];
      if (profile.motionCheck) {
        await client.send("Runtime.evaluate", { expression: axeSource });
        const axeEvaluation = await client.send("Runtime.evaluate", {
          expression: `axe.run(document, { resultTypes: ['violations'] }).then(({ violations }) =>
            violations
              .filter(({ impact }) => impact === 'serious' || impact === 'critical')
              .map(({ id, impact, nodes }) => ({
                id,
                impact,
                targets: nodes.slice(0, 3).map(({ target }) => target.join(' ')),
              }))
          )`,
          awaitPromise: true,
          returnByValue: true,
        });
        seriousAxeViolations = axeEvaluation.result?.value || [];
      }

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
        seriousAxeViolations,
      });

      if (result.readyState !== "complete") fail(`${profile.name} ${path}: document did not finish loading`);
      if (result.bodyTextLength < 150) fail(`${profile.name} ${path}: rendered body is suspiciously short`);
      if (result.h1Count !== 1) fail(`${profile.name} ${path}: expected one H1, found ${result.h1Count}`);
      if (result.errorOverlay) fail(`${profile.name} ${path}: a framework error overlay is visible`);
      if (result.horizontalOverflow > 4) {
        const unexpectedOverflow = (result.overflowingElements || [])
          .filter(({ containedByAccessibleScroller }) => !containedByAccessibleScroller);
        if (unexpectedOverflow.length) {
          fail(`${profile.name} ${path}: document has ${result.horizontalOverflow}px of horizontal overflow ${JSON.stringify(unexpectedOverflow)}`);
        }
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
      if (seriousAxeViolations.length) {
        fail(`${profile.name} ${path}: axe serious/critical violations ${JSON.stringify(seriousAxeViolations)}`);
      }

      for (const target of result.ctas || []) {
        if (target.height < 44 || target.width < 44) {
          fail(`${profile.name} ${path}: CTA target is too small ${JSON.stringify(target)}`);
        }
      }

      if (profile.motionCheck && ["/", "/showcase"].includes(path)) {
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
          const expectedMode = path === "/" ? "loop" : "one-shot";
          if (!firstVideo.muted || firstVideo.loop !== (expectedMode === "loop") || !firstVideo.playsInline || firstVideo.autoplayMode !== expectedMode) {
            fail(`${profile.name} ${path}: first video is not configured for silent ${expectedMode} inline autoplay`);
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

  const freshProfileState = await client.send("Runtime.evaluate", {
    expression: `(() => ({
      consent: localStorage.getItem("cmdtab-optional-analytics-consent"),
      visitorId: localStorage.getItem("cmdtab-website-visitor-id"),
      sessionId: sessionStorage.getItem("cmdtab-website-session-id"),
      consentBannerVisible: [...document.querySelectorAll("button")].some(
        (button) => button.textContent?.trim() === "Accept optional analytics"
      ),
    }))()`,
    returnByValue: true,
  });
  const freshState = freshProfileState.result?.value || {};
  if (freshState.consent !== null || freshState.visitorId !== null || freshState.sessionId !== null) {
    fail(`fresh profile created analytics state before consent: ${JSON.stringify(freshState)}`);
  }
  if (!freshState.consentBannerVisible) {
    fail("fresh profile does not show the optional analytics consent controls");
  }
  if (freshProfileAnalyticsRequests.length) {
    fail(
      `fresh profile sent analytics requests before consent: ${freshProfileAnalyticsRequests.join(", ")}`,
    );
  }
  const declineFlow = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const decline = [...document.querySelectorAll("button")].find(
        (button) => button.textContent?.trim() === "Decline"
      );
      if (!decline) return resolve({ ok: false, reason: "decline control missing" });
      decline.click();
      await new Promise((done) => setTimeout(done, 150));
      resolve({
        ok: true,
        consent: localStorage.getItem("cmdtab-optional-analytics-consent"),
        visitorId: localStorage.getItem("cmdtab-website-visitor-id"),
        sessionId: sessionStorage.getItem("cmdtab-website-session-id"),
      });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const declinedState = declineFlow.result?.value || {};
  if (
    !declinedState.ok ||
    declinedState.consent !== "declined" ||
    declinedState.visitorId !== null ||
    declinedState.sessionId !== null
  ) {
    fail(`declining analytics did not remain identifier-free: ${JSON.stringify(declinedState)}`);
  }
  if (freshProfileAnalyticsRequests.length) {
    fail(`declining analytics sent analytics requests: ${freshProfileAnalyticsRequests.join(", ")}`);
  }
  removeFreshProfileRequestListener();

  const privacyLoadedBeforeAccept = client.waitFor("Page.loadEventFired");
  await client.send("Page.navigate", { url: `${baseUrl}/privacy` });
  await privacyLoadedBeforeAccept;
  await sleep(700);
  const consentFlowRequests = [];
  const removeConsentFlowRequestListener = client.on("Network.requestWillBeSent", ({ request }) => {
    const url = String(request?.url || "");
    if (
      url.includes("/api/analytics") ||
      url.includes("/_vercel/insights") ||
      url.includes("/_vercel/speed-insights")
    ) {
      consentFlowRequests.push(url);
    }
  });
  const consentFlow = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      localStorage.setItem("cmdtab-optional-analytics-consent", "accepted");
      window.dispatchEvent(new StorageEvent("storage", {
        key: "cmdtab-optional-analytics-consent",
        oldValue: "declined",
        newValue: "accepted",
        storageArea: localStorage,
      }));
      await new Promise((done) => setTimeout(done, 1200));
      const accepted = {
        consent: localStorage.getItem("cmdtab-optional-analytics-consent"),
        visitorId: localStorage.getItem("cmdtab-website-visitor-id"),
        sessionId: sessionStorage.getItem("cmdtab-website-session-id"),
      };
      resolve({ ok: true, accepted });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const acceptedState = consentFlow.result?.value || {};
  if (
    !acceptedState.ok ||
    acceptedState.accepted?.consent !== "accepted" ||
    !acceptedState.accepted?.visitorId ||
    !acceptedState.accepted?.sessionId
  ) {
    fail(`cross-tab acceptance did not create the expected consent-scoped IDs: ${JSON.stringify(acceptedState)}`);
  }
  if (!consentFlowRequests.some((url) => url.includes("/api/analytics"))) {
    fail("cross-tab acceptance did not send the current first-party pageview");
  }

  const privacyLoaded = client.waitFor("Page.loadEventFired");
  await client.send("Page.navigate", { url: `${baseUrl}/privacy` });
  await privacyLoaded;
  await sleep(700);
  const withdrawal = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const withdraw = [...document.querySelectorAll("button")].find(
        (button) => button.textContent?.trim() === "Withdraw consent"
      );
      if (!withdraw) return resolve({ ok: false, reason: "withdraw control missing" });
      withdraw.click();
      await new Promise((done) => setTimeout(done, 100));
      resolve({
        ok: true,
        consent: localStorage.getItem("cmdtab-optional-analytics-consent"),
        visitorId: localStorage.getItem("cmdtab-website-visitor-id"),
        sessionId: sessionStorage.getItem("cmdtab-website-session-id"),
      });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const withdrawnState = withdrawal.result?.value || {};
  if (
    !withdrawnState.ok ||
    withdrawnState.consent !== "declined" ||
    withdrawnState.visitorId !== null ||
    withdrawnState.sessionId !== null
  ) {
    fail(`withdrawing analytics did not delete stored IDs: ${JSON.stringify(withdrawnState)}`);
  }
  const firstPartyRequestsBeforeReaccept = consentFlowRequests.filter((url) =>
    url.includes("/api/analytics")
  ).length;
  const reaccept = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const accept = [...document.querySelectorAll("button")].find(
        (button) => button.textContent?.trim() === "Accept optional analytics"
      );
      if (!accept) return resolve({ ok: false, reason: "reaccept control missing" });
      accept.click();
      await new Promise((done) => setTimeout(done, 1200));
      resolve({
        ok: true,
        consent: localStorage.getItem("cmdtab-optional-analytics-consent"),
        visitorId: localStorage.getItem("cmdtab-website-visitor-id"),
        sessionId: sessionStorage.getItem("cmdtab-website-session-id"),
      });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const reacceptedState = reaccept.result?.value || {};
  const firstPartyRequestsAfterReaccept = consentFlowRequests.filter((url) =>
    url.includes("/api/analytics")
  ).length;
  if (
    !reacceptedState.ok ||
    reacceptedState.consent !== "accepted" ||
    !reacceptedState.visitorId ||
    !reacceptedState.sessionId ||
    firstPartyRequestsAfterReaccept - firstPartyRequestsBeforeReaccept !== 1
  ) {
    fail(
      `reaccepting the same path did not record exactly one pageview: ${JSON.stringify({
        reacceptedState,
        firstPartyRequestsBeforeReaccept,
        firstPartyRequestsAfterReaccept,
      })}`,
    );
  }
  const finalWithdrawal = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const withdraw = [...document.querySelectorAll("button")].find(
        (button) => button.textContent?.trim() === "Withdraw consent"
      );
      if (!withdraw) return resolve({ ok: false, reason: "final withdraw control missing" });
      withdraw.click();
      await new Promise((done) => setTimeout(done, 500));
      resolve({
        ok: true,
        consent: localStorage.getItem("cmdtab-optional-analytics-consent"),
      });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  if (
    !finalWithdrawal.result?.value?.ok ||
    finalWithdrawal.result?.value?.consent !== "declined"
  ) {
    fail(`final analytics withdrawal failed: ${JSON.stringify(finalWithdrawal.result?.value || {})}`);
  }
  const requestsAtWithdrawal = consentFlowRequests.length;
  const postWithdrawalLoaded = client.waitFor("Page.loadEventFired");
  await client.send("Page.navigate", { url: `${baseUrl}/faq` });
  await postWithdrawalLoaded;
  await sleep(700);
  if (consentFlowRequests.length !== requestsAtWithdrawal) {
    fail(
      `analytics requests continued after withdrawal: ${consentFlowRequests
        .slice(requestsAtWithdrawal)
        .join(", ")}`,
    );
  }
  removeConsentFlowRequestListener();

  const apiContracts = await client.send("Runtime.evaluate", {
    expression: `Promise.all([
      fetch("/api/analytics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ eventType: "pageview", path: "/", unexpected: true }),
      }).then((response) => response.status),
      fetch("/api/analytics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ eventType: "pageview", path: "/", eventData: { nested: {} } }),
      }).then((response) => response.status),
      fetch("/api/app-telemetry", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          installId: "install_test_123",
          eventName: "app_activation",
          licenseState: "unregistered",
          unexpected: true,
        }),
      }).then((response) => response.status),
      fetch("/api/app-telemetry", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          installId: "install_test_123",
          eventName: "app_activation",
          licenseState: "unregistered",
          metadata: { nested: {} },
        }),
      }).then((response) => response.status),
      fetch("/api/analytics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ padding: "x".repeat(9 * 1024) }),
      }).then((response) => response.status),
      fetch("/api/app-telemetry", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          installId: "install_test_123",
          eventName: "app_activation",
          licenseState: "unregistered",
          licenseId: null,
          appVersion: "1.0.0",
          osVersion: "macOS 15.5",
        }),
      }).then((response) => response.status),
      fetch("/api/analytics", {
        method: "POST",
        headers: { "Content-Type": "application/jsonp" },
        body: JSON.stringify({ eventType: "pageview", path: "/" }),
      }).then((response) => response.status),
    ])`,
    awaitPromise: true,
    returnByValue: true,
  });
  const apiStatuses = apiContracts.result?.value || [];
  if (JSON.stringify(apiStatuses) !== JSON.stringify([400, 400, 400, 400, 413, 204, 415])) {
    fail(`analytics ingestion contract returned unexpected statuses: ${JSON.stringify(apiStatuses)}`);
  }

  const rateLimitContracts = await client.send("Runtime.evaluate", {
    expression: `new Promise(async (resolve) => {
      const statuses = [];
      for (let index = 0; index < 130; index += 1) {
        const response = await fetch("/api/analytics", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            eventType: "event",
            eventName: "rate_limit_contract",
            path: "/",
            eventData: { index },
          }),
        });
        statuses.push(response.status);
      }
      resolve(statuses);
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  const rateLimitStatuses = rateLimitContracts.result?.value || [];
  if (!rateLimitStatuses.includes(429)) {
    fail(`analytics ingestion rate limit did not return 429: ${JSON.stringify(rateLimitStatuses)}`);
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
  await client.send("Page.navigate", { url: `${baseUrl}/showcase` });
  await loaded;
  await sleep(900);
  const oneShotSetup = await client.send("Runtime.evaluate", {
    expression: `(() => {
      const video = document.querySelector('video');
      if (!video) return { ok: false, reason: 'video missing' };
      if (video.readyState < 1) return { ok: false, reason: 'video metadata unavailable' };
      video.currentTime = Math.max(0, video.duration - 0.12);
      void video.play();
      return { ok: true, duration: video.duration };
    })()`,
    returnByValue: true,
  });
  if (!oneShotSetup.result?.value?.ok) {
    fail(`one-shot autoplay setup failed: ${JSON.stringify(oneShotSetup.result?.value || {})}`);
  } else {
    await sleep(500);
    await client.send("Runtime.evaluate", {
      expression: "window.scrollTo(0, document.body.scrollHeight)",
    });
    await sleep(200);
    await client.send("Runtime.evaluate", {
      expression: "window.scrollTo(0, 0)",
    });
    await sleep(500);
  }
  const oneShotEvaluation = await client.send("Runtime.evaluate", {
    expression: `(() => {
      const video = document.querySelector('video');
      if (!video) return { ok: false, reason: 'video missing' };
      return {
        ok: video.ended && video.paused && !video.loop && video.dataset.autoplayMode === 'one-shot',
        ended: video.ended,
        paused: video.paused,
        loop: video.loop,
        currentTime: video.currentTime,
        duration: video.duration,
        autoplayMode: video.dataset.autoplayMode || null,
      };
    })()`,
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
  `Browser verification passed for ${routes.length} routes at desktop, mobile, 200% zoom, and 400% zoom/320px reflow viewports, axe with no serious/critical violations, one-shot autoplay, reduced-motion safety, 44px targets, mobile navigation, and accessible wide tables.`,
);
