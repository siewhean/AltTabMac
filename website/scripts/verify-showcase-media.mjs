#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path));
const readText = (path) => read(path).toString("utf8");
const manifest = JSON.parse(readText("public/showcase/manifest.json"));

const expected = new Map([
  ["overview", { poster: "overview-poster.webp", video: "overview.mp4", posterWidth: 720, posterHeight: 450, videoWidth: 480, videoHeight: 300, frameRate: 6, duration: 8, source: "deterministic-product-composite" }],
  ["classic-grid", { poster: "classic-grid-poster.webp", video: null, posterWidth: 720, posterHeight: 450, source: "deterministic-product-composite" }],
  ["command-palette", { poster: "command-palette-poster.webp", video: null, posterWidth: 800, posterHeight: 500, source: "deterministic-product-composite" }],
  ["radial-menu", { poster: "radial-menu-poster.webp", video: "radial-menu.mp4", posterWidth: 800, posterHeight: 500, videoWidth: 480, videoHeight: 300, frameRate: 8, duration: 4.833333, source: "production-swiftui-render" }],
  ["quick-actions", { poster: "quick-actions-poster.webp", video: "quick-actions.mp4", posterWidth: 720, posterHeight: 450, videoWidth: 480, videoHeight: 300, frameRate: 8, duration: 3.583333, source: "deterministic-product-composite" }],
]);

function webpDimensions(buffer, name) {
  assert.equal(buffer.subarray(0, 4).toString("ascii"), "RIFF", `${name} is not a RIFF file`);
  assert.equal(buffer.subarray(8, 12).toString("ascii"), "WEBP", `${name} is not WebP`);
  const chunk = buffer.subarray(12, 16).toString("ascii");
  if (chunk === "VP8X") {
    return {
      width: 1 + buffer.readUIntLE(24, 3),
      height: 1 + buffer.readUIntLE(27, 3),
    };
  }
  if (chunk === "VP8 ") {
    assert.equal(buffer.subarray(23, 26).toString("hex"), "9d012a", `${name} has an invalid VP8 frame header`);
    return {
      width: buffer.readUInt16LE(26) & 0x3fff,
      height: buffer.readUInt16LE(28) & 0x3fff,
    };
  }
  if (chunk === "VP8L") {
    assert.equal(buffer[20], 0x2f, `${name} has an invalid VP8L signature`);
    const bits = buffer.readUInt32LE(21);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >> 14) & 0x3fff) + 1,
    };
  }
  throw new Error(`${name} uses unsupported WebP chunk ${JSON.stringify(chunk)}`);
}

assert.equal(manifest.schemaVersion, 3, "showcase manifest schema version changed unexpectedly");
assert.match(manifest.source, /hybrid privacy-safe product showcase/i, "showcase source boundary is missing");
assert.match(manifest.fixturePolicy, /no private desktop capture/i, "fixture privacy policy is missing");
assert.match(manifest.fixturePolicy, /no AI-generated product screenshots/i, "AI-generation boundary is missing");
assert.match(manifest.disclosure, /Radial Menu is an authentic production SwiftUI\/AppKit render/i, "authentic Radial provenance is missing");
assert.match(manifest.disclosure, /deterministic product composites/i, "composite provenance is missing");
assert.deepEqual(new Set(manifest.assets.map((asset) => asset.id)), new Set(expected.keys()), "showcase asset IDs changed");

for (const asset of manifest.assets) {
  const contract = expected.get(asset.id);
  assert.ok(contract, `unexpected showcase asset ${asset.id}`);
  assert.equal(asset.poster, contract.poster, `${asset.id} poster filename changed`);
  assert.equal(asset.video ?? null, contract.video, `${asset.id} video contract changed`);
  assert.equal(asset.posterWidth, contract.posterWidth, `${asset.id} poster width changed`);
  assert.equal(asset.posterHeight, contract.posterHeight, `${asset.id} poster height changed`);
  assert.equal(asset.sourceType, contract.source, `${asset.id} source type changed`);
  assert.equal(asset.hasAudio, false, `${asset.id} must remain silent`);

  const posterPath = `public/showcase/${asset.poster}`;
  const poster = read(posterPath);
  assert.ok(statSync(resolve(root, posterPath)).size >= 10_000, `${asset.id} poster is implausibly small`);
  const dimensions = webpDimensions(poster, asset.poster);
  assert.equal(dimensions.width, asset.posterWidth, `${asset.id} WebP width diverges from manifest`);
  assert.equal(dimensions.height, asset.posterHeight, `${asset.id} WebP height diverges from manifest`);

  if (contract.video) {
    assert.equal(asset.videoWidth, contract.videoWidth, `${asset.id} video width changed`);
    assert.equal(asset.videoHeight, contract.videoHeight, `${asset.id} video height changed`);
    assert.equal(asset.frameRate, contract.frameRate, `${asset.id} frame rate changed`);
    assert.ok(Math.abs(asset.durationSeconds - contract.duration) <= 0.06, `${asset.id} duration changed`);
    const videoPath = `public/showcase/${asset.video}`;
    const video = read(videoPath);
    assert.ok(video.length >= 40_000 && video.length <= 8_000_000, `${asset.id} MP4 size is implausible`);
    assert.equal(video.subarray(4, 8).toString("ascii"), "ftyp", `${asset.id} is not an ISO MP4 file`);
    assert.ok(video.includes(Buffer.from("avc1")), `${asset.id} does not advertise H.264/avc1`);
    assert.ok(video.includes(Buffer.from("moov")), `${asset.id} is missing MP4 movie metadata`);
    assert.ok(video.includes(Buffer.from("mdat")), `${asset.id} is missing MP4 media data`);
    assert.ok(!video.includes(Buffer.from("mp4a")), `${asset.id} unexpectedly advertises AAC audio`);
    assert.ok(!video.includes(Buffer.from("soun")), `${asset.id} unexpectedly advertises an audio handler`);
  } else {
    assert.equal(asset.video, null, `${asset.id} must remain poster-only until a reviewed clip is committed`);
  }
}

const showcaseContent = readText("src/content/showcase.ts");
const showcasePage = readText("src/app/showcase/page.tsx");
const player = readText("src/components/showcase/showcase-video.tsx");
const structuredData = readText("src/lib/structured-data.ts");
const routes = JSON.parse(readText("src/content/public-routes.json"));
const packageJson = JSON.parse(readText("package.json"));

assert.ok(routes.some((route) => route.path === "/showcase"), "showcase route is missing from canonical registry");
for (const contract of expected.values()) {
  assert.ok(showcaseContent.includes(`/showcase/${contract.poster}`), `${contract.poster} is missing from content contract`);
  if (contract.video) assert.ok(showcaseContent.includes(`/showcase/${contract.video}`), `${contract.video} is missing from content contract`);
}
assert.doesNotMatch(showcaseContent, /classic-grid\.mp4|command-palette\.mp4/, "poster-only media must not advertise missing MP4s");
assert.match(showcaseContent, /not AI-generated/i, "visible showcase disclosure must reject AI-generated media");
assert.match(showcaseContent, /deterministic product composites/i, "composite provenance disclosure is missing");
assert.match(showcaseContent, /controlled fixture windows/i, "visible fixture disclosure is missing");
assert.match(showcasePage, /createVideoStructuredData/, "showcase page is missing VideoObject markup");
assert.match(showcasePage, /headingAs="h1"/, "showcase page is missing its page-level H1");
assert.match(showcasePage, /breadcrumbs=\{breadcrumbs\}/, "showcase page is missing visible breadcrumbs");
assert.match(player, /asset\.video \?/, "showcase player must distinguish video and poster-only assets");
assert.match(player, /<video/, "showcase player must render native video elements when a clip exists");
assert.match(player, /<img/, "showcase player must render a poster fallback when a clip does not exist");
assert.match(player, /poster=\{asset\.poster\}/, "showcase player must use a stable poster URL");
assert.match(player, /muted/, "showcase player must be muted");
assert.match(player, /playsInline/, "showcase player must play inline");
assert.match(player, /prefers-reduced-motion/, "showcase player must respect reduced motion");
assert.match(player, /asset\.sourceLabel/, "showcase player must display per-asset provenance");
assert.match(structuredData, /videos = assets\.filter/, "VideoObject generation must exclude poster-only entries");
assert.match(structuredData, /"VideoObject"/, "VideoObject structured data is missing");
assert.equal(packageJson.scripts.prebuild, "npm run security:deps && npm run seo:check && npm run typecheck", "Vercel prebuild guard is missing");
for (const unsupported of ["ScreenCaptureKit fast", "sub-50", "< 20MB", "Universal Binary"]) {
  assert.ok(!showcaseContent.includes(unsupported), `unsupported claim entered showcase content: ${unsupported}`);
}

console.log(`Showcase media verification passed for ${manifest.assets.length} truthful WebP/optional-MP4 assets.`);
