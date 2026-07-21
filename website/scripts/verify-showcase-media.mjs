#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path));
const readText = (path) => read(path).toString("utf8");
const manifest = JSON.parse(readText("public/showcase/manifest.json"));

const expected = new Map([
  ["overview", { duration: 8.0, poster: "overview-poster.png", video: "overview.mp4" }],
  ["classic-grid", { duration: 5.1, poster: "classic-grid-poster.png", video: "classic-grid.mp4" }],
  ["command-palette", { duration: 4.8, poster: "command-palette-poster.png", video: "command-palette.mp4" }],
  ["radial-menu", { duration: 4.8, poster: "radial-menu-poster.png", video: "radial-menu.mp4" }],
  ["quick-actions", { duration: 3.6, poster: "quick-actions-poster.png", video: "quick-actions.mp4" }],
]);

assert.equal(manifest.schemaVersion, 1, "showcase manifest schema version changed unexpectedly");
assert.match(manifest.source, /production SwiftUI\/AppKit views/, "manifest must identify production app views");
assert.match(manifest.fixturePolicy, /no private desktop capture/, "fixture privacy policy is missing");
assert.deepEqual(new Set(manifest.assets.map((asset) => asset.id)), new Set(expected.keys()), "showcase asset IDs changed");

for (const asset of manifest.assets) {
  const contract = expected.get(asset.id);
  assert.ok(contract, `unexpected showcase asset ${asset.id}`);
  assert.equal(asset.poster, contract.poster, `${asset.id} poster filename changed`);
  assert.equal(asset.video, contract.video, `${asset.id} video filename changed`);
  assert.equal(asset.width, 1280, `${asset.id} width changed`);
  assert.equal(asset.height, 800, `${asset.id} height changed`);
  assert.equal(asset.frameRate, 20, `${asset.id} frame rate changed`);
  assert.ok(Math.abs(asset.durationSeconds - contract.duration) <= 0.11, `${asset.id} duration changed`);
  assert.equal(asset.videoCodec, "H.264", `${asset.id} codec must remain H.264`);
  assert.equal(asset.hasAudio, false, `${asset.id} must remain silent`);
  assert.match(asset.sourceType, /production SwiftUI render/, `${asset.id} source disclosure is missing`);
  assert.match(asset.disclosure, /controlled fixture windows/, `${asset.id} fixture disclosure is missing`);

  const posterPath = `public/showcase/${asset.poster}`;
  const videoPath = `public/showcase/${asset.video}`;
  const poster = read(posterPath);
  const video = read(videoPath);
  assert.equal(statSync(resolve(root, posterPath)).size, asset.posterBytes, `${asset.id} poster bytes diverge from manifest`);
  assert.equal(statSync(resolve(root, videoPath)).size, asset.videoBytes, `${asset.id} video bytes diverge from manifest`);
  assert.ok(poster.length >= 80_000 && poster.length <= 3_500_000, `${asset.id} poster size is implausible`);
  assert.ok(video.length >= 50_000 && video.length <= 8_000_000, `${asset.id} MP4 size is implausible`);

  assert.equal(poster.subarray(0, 8).toString("hex"), "89504e470d0a1a0a", `${asset.id} poster is not PNG`);
  assert.equal(poster.readUInt32BE(16), 1280, `${asset.id} PNG width is wrong`);
  assert.equal(poster.readUInt32BE(20), 800, `${asset.id} PNG height is wrong`);

  assert.equal(video.subarray(4, 8).toString("ascii"), "ftyp", `${asset.id} is not an ISO MP4 file`);
  assert.ok(video.includes(Buffer.from("avc1")), `${asset.id} does not advertise H.264/avc1`);
  assert.ok(video.includes(Buffer.from("moov")), `${asset.id} is missing MP4 movie metadata`);
  assert.ok(!video.includes(Buffer.from("mp4a")), `${asset.id} unexpectedly advertises AAC audio`);
  assert.ok(!video.includes(Buffer.from("soun")), `${asset.id} unexpectedly advertises an audio handler`);
}

const contactSheet = read("public/showcase/contact-sheet.png");
assert.equal(contactSheet.subarray(0, 8).toString("hex"), "89504e470d0a1a0a", "contact sheet is not PNG");
assert.equal(contactSheet.readUInt32BE(16), 1600, "contact sheet width changed");
assert.equal(contactSheet.readUInt32BE(20), 1100, "contact sheet height changed");
assert.ok(contactSheet.length >= 250_000, "contact sheet is implausibly small");

const showcaseContent = readText("src/content/showcase.ts");
const showcasePage = readText("src/app/showcase/page.tsx");
const player = readText("src/components/showcase/showcase-video.tsx");
const structuredData = readText("src/lib/structured-data.ts");
const routes = JSON.parse(readText("src/content/public-routes.json"));

assert.ok(routes.some((route) => route.path === "/showcase"), "showcase route is missing from canonical registry");
for (const { poster, video } of expected.values()) {
  assert.ok(showcaseContent.includes(`/showcase/${poster}`), `${poster} is missing from content contract`);
  assert.ok(showcaseContent.includes(`/showcase/${video}`), `${video} is missing from content contract`);
}
assert.match(showcaseContent, /not AI-generated/i, "visible showcase disclosure must reject AI-generated media");
assert.match(showcaseContent, /controlled fixture windows/i, "visible fixture disclosure is missing");
assert.match(showcasePage, /createVideoStructuredData/, "showcase page is missing VideoObject markup");
assert.match(showcasePage, /headingAs="h1"/, "showcase page is missing its page-level H1");
assert.match(showcasePage, /breadcrumbs=\{breadcrumbs\}/, "showcase page is missing visible breadcrumbs");
assert.match(player, /<video/, "showcase player must render a native video element");
assert.match(player, /poster=\{asset\.poster\}/, "showcase player must use a stable poster URL");
assert.match(player, /muted/, "showcase player must be muted");
assert.match(player, /playsInline/, "showcase player must play inline");
assert.match(player, /prefers-reduced-motion/, "showcase player must respect reduced motion");
assert.match(player, /Read the clip transcript/, "showcase player must expose a text transcript");
assert.match(structuredData, /"VideoObject"/, "VideoObject structured data is missing");
assert.match(structuredData, /thumbnailUrl/, "VideoObject thumbnail URL is missing");
assert.match(structuredData, /contentUrl/, "VideoObject content URL is missing");
assert.match(structuredData, /uploadDate/, "VideoObject upload date is missing");
for (const unsupported of ["ScreenCaptureKit fast", "sub-50", "< 20MB", "Universal Binary"]) {
  assert.ok(!showcaseContent.includes(unsupported), `unsupported claim entered showcase content: ${unsupported}`);
}

console.log(`Showcase media verification passed for ${manifest.assets.length} real production-view MP4 loops.`);
