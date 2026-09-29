#!/usr/bin/env node
import assert from "node:assert/strict";
import publicRoutes from "../src/content/public-routes.json" with { type: "json" };

const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");

async function fetchResource(path) {
  const response = await fetch(`${baseUrl}${path}`, {
    headers: { "User-Agent": "CmdTabRetrievalVerifier/2.0", Accept: "*/*" },
    redirect: "follow",
  });
  const body = await response.text();
  return { response, body };
}

const { response: homeResponse, body: home } = await fetchResource("/");
assert.equal(homeResponse.status, 200, `homepage returned HTTP ${homeResponse.status}`);
assert.match(home, /standalone native macOS window-switcher app/i, "homepage must identify CmdTab as a standalone macOS application");
assert.match(home, /separate from Apple(?:’|&rsquo;|&#x27;|')s built-in Command-Tab shortcut/i, "homepage must disambiguate CmdTab from Apple’s built-in shortcut");
assert.match(home, /"disambiguatingDescription":"CmdTab is a standalone macOS window-switcher application, not Apple/i, "rendered SoftwareApplication schema is missing the disambiguating description");
assert.match(home, /"permissions":\[/, "rendered SoftwareApplication schema is missing permission text");
assert.match(home, /\/showcase\/overview-poster\.webp/, "rendered SoftwareApplication schema must use the maintained showcase poster");
assert.doesNotMatch(home, /"(?:memoryRequirements|processorRequirements)":/, "rendered schema contains unproved memory or processor requirements");

const expectedRoutes = new Map([
  ["/showcase", /Short HD loops show the switcher styles and Quick Actions without recording a private desktop/i],
  ["/features/classic-grid", /A visual Mac window switcher for choosing one exact window/i],
  ["/features/command-palette", /Search open Mac windows by app name or window text/i],
  ["/features/radial-menu", /A circular Mac window switcher for directional selection/i],
  ["/features/quick-actions", /Manage the selected Mac window without switching into it first/i],
  ["/compare/cmdtab-vs-alttab", /CmdTab versus AltTab: choose the window-switching model first/i],
]);

for (const [path, marker] of expectedRoutes) {
  const { response, body } = await fetchResource(path);
  assert.equal(response.status, 200, `${path} returned HTTP ${response.status}`);
  assert.match(body, marker, `${path} is missing its distinct visible purpose`);
  assert.match(body, /<h1(?:\s|>)/i, `${path} is missing its page-level H1`);
}

const { response: llmsResponse, body: llms } = await fetchResource("/llms.txt");
assert.equal(llmsResponse.status, 200, `/llms.txt returned HTTP ${llmsResponse.status}`);
assert.match(llmsResponse.headers.get("content-type") || "", /text\/plain/i, "/llms.txt must be plain text");
for (const expected of [
  "/showcase",
  "/showcase/overview-poster.webp",
  "/showcase/overview.mp4",
  "/showcase/classic-grid-poster.webp",
  "/showcase/command-palette-poster.webp",
  "/showcase/radial-menu-poster.webp",
  "/showcase/radial-menu.mp4",
  "/showcase/quick-actions-poster.webp",
  "/showcase/quick-actions.mp4",
  "/showcase/manifest.json",
  "/features/classic-grid",
  "/features/command-palette",
  "/features/radial-menu",
  "/features/quick-actions",
  "/compare/cmdtab-vs-alttab",
  "/llms-full.txt",
]) {
  assert.ok(llms.includes(expected), `/llms.txt is missing ${expected}`);
}
assert.ok(!llms.includes("/showcase/classic-grid.mp4"), "/llms.txt advertises a nonexistent Classic Grid MP4");
assert.ok(!llms.includes("/showcase/command-palette.mp4"), "/llms.txt advertises a nonexistent Command Palette MP4");
assert.match(llms, /Radial Menu poster.*deterministic product composite/i, "/llms.txt must identify Radial Menu as composite media");
assert.match(llms, /not AI-generated/i, "/llms.txt must preserve the AI-generation boundary");
assert.match(llms, /not claimed as an AI-search requirement/i, "/llms.txt must state the consolidated helper limitation");

const { response: fullResponse, body: full } = await fetchResource("/llms-full.txt");
assert.equal(fullResponse.status, 200, `/llms-full.txt returned HTTP ${fullResponse.status}`);
assert.match(fullResponse.headers.get("content-type") || "", /text\/plain/i, "/llms-full.txt must be plain text");
assert.match(fullResponse.headers.get("x-robots-tag") || "", /noindex/i, "/llms-full.txt must be excluded from search indexing");
for (const expected of [
  "non-standard convenience export",
  "canonical HTML as authoritative",
  "HD product images and short videos",
  "Are the showcase screenshots and videos AI-generated?",
  "controlled fixture windows",
  "deterministic HD product composite",
  "No processor architecture, Universal Binary status, memory footprint",
  "Does CmdTab use ScreenCaptureKit?",
  "then uses ScreenCaptureKit for asynchronous recovery",
  "Does CmdTab publish a RAM or sub-50 ms performance claim?",
  "/showcase/overview-poster.webp",
  "/showcase/overview.mp4",
  "/showcase/classic-grid-poster.webp",
  "/showcase/command-palette-poster.webp",
  "/showcase/radial-menu.mp4",
  "/showcase/quick-actions.mp4",
]) {
  assert.ok(full.includes(expected), `/llms-full.txt is missing the boundary: ${expected}`);
}
assert.ok(!full.includes("/showcase/classic-grid.mp4"), "/llms-full.txt advertises a nonexistent Classic Grid MP4");
assert.ok(!full.includes("/showcase/command-palette.mp4"), "/llms-full.txt advertises a nonexistent Command Palette MP4");
assert.match(full, /state-space counts are synthetic model evidence/i, "/llms-full.txt must preserve the model-versus-field-data limitation");

const { response: sitemapResponse, body: sitemap } = await fetchResource("/sitemap.xml");
assert.equal(sitemapResponse.status, 200, `/sitemap.xml returned HTTP ${sitemapResponse.status}`);
const locCount = (sitemap.match(/<loc>/g) || []).length;
assert.equal(locCount, publicRoutes.length, `sitemap contains ${locCount} URLs but the canonical registry contains ${publicRoutes.length}`);
assert.ok(!sitemap.includes("llms-full.txt"), "the non-standard context export must not appear in sitemap.xml");
assert.ok(!sitemap.includes(".mp4"), "raw videos must not compete as canonical HTML sitemap entries");
for (const { path } of publicRoutes) {
  const expected = `https://cmdtab.net${path === "/" ? "/" : path}`;
  assert.ok(sitemap.includes(`<loc>${expected}</loc>`), `sitemap is missing ${expected}`);
}

console.log(`Retrieval verification passed for brand disambiguation, truthful optional-video media, ${expectedRoutes.size} distinct pages, llms.txt, noindex llms-full.txt, and ${publicRoutes.length} canonical sitemap URLs.`);
