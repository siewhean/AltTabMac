#!/usr/bin/env node

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";
import ffmpegPath from "ffmpeg-static";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path));
const readText = (path) => read(path).toString("utf8");
const sha256 = (buffer) => createHash("sha256").update(buffer).digest("hex");
const manifest = JSON.parse(readText("public/showcase/manifest.json"));

const HD_WIDTH = 1920;
const HD_HEIGHT = 1200;
const HD_FPS = 30;
const MAX_AUTOPLAY_SECONDS = 5;
const expected = new Map([
  ["overview", { poster: "overview-poster.webp", video: "overview.mp4", duration: 4.8 }],
  ["classic-grid", { poster: "classic-grid-poster.webp", video: null }],
  ["command-palette", { poster: "command-palette-poster.webp", video: null }],
  ["radial-menu", { poster: "radial-menu-poster.webp", video: "radial-menu.mp4", duration: 5 }],
  ["quick-actions", { poster: "quick-actions-poster.webp", video: "quick-actions.mp4", duration: 4 }],
]);

function webpDimensions(buffer, name) {
  assert.equal(buffer.subarray(0, 4).toString("ascii"), "RIFF", `${name} is not a RIFF file`);
  assert.equal(buffer.subarray(8, 12).toString("ascii"), "WEBP", `${name} is not WebP`);
  const chunk = buffer.subarray(12, 16).toString("ascii");
  if (chunk === "VP8X") return { width: 1 + buffer.readUIntLE(24, 3), height: 1 + buffer.readUIntLE(27, 3) };
  if (chunk === "VP8 ") {
    assert.equal(buffer.subarray(23, 26).toString("hex"), "9d012a", `${name} has an invalid VP8 frame header`);
    return { width: buffer.readUInt16LE(26) & 0x3fff, height: buffer.readUInt16LE(28) & 0x3fff };
  }
  if (chunk === "VP8L") {
    assert.equal(buffer[20], 0x2f, `${name} has an invalid VP8L signature`);
    const bits = buffer.readUInt32LE(21);
    return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
  }
  throw new Error(`${name} uses unsupported WebP chunk ${JSON.stringify(chunk)}`);
}

function verifyVideo(path, id) {
  assert.ok(ffmpegPath, "ffmpeg-static did not provide a binary");
  const result = spawnSync(
    ffmpegPath,
    ["-hide_banner", "-i", resolve(root, path), "-map", "0:v:0", "-frames:v", "1", "-f", "null", "-"],
    { encoding: "utf8" },
  );
  const report = `${result.stdout || ""}\n${result.stderr || ""}`;
  assert.equal(result.status, 0, `${id} could not be decoded by ffmpeg:\n${report}`);
  assert.match(report, /Video:\s+h264/i, `${id} is not decoded as H.264`);
  assert.match(report, /1920x1200/, `${id} is not decoded at 1920x1200`);
  assert.match(report, /30 fps/, `${id} is not decoded at 30 fps`);
  assert.doesNotMatch(
    report,
    /Stream #\d+:\d+(?:\[[^\]]+\])?(?:\([^)]+\))?:\s*Audio:/i,
    `${id} unexpectedly contains an audio stream`,
  );
}

assert.equal(manifest.schemaVersion, 5, "showcase manifest schema version must be 5");
assert.equal(manifest.reviewedAt, "2026-07-22", "showcase review date is stale");
assert.match(manifest.source, /deterministic privacy-safe HD product showcase/i, "HD source boundary is missing");
assert.match(manifest.fixturePolicy, /no private desktop capture/i, "fixture privacy policy is missing");
assert.match(manifest.fixturePolicy, /no AI-generated product screenshots/i, "AI-generation boundary is missing");
assert.match(manifest.qualityPolicy, /1920x1200/i, "HD dimensions are missing from the quality policy");
assert.match(manifest.qualityPolicy, /30 fps/i, "30 fps is missing from the quality policy");
assert.match(manifest.disclosure, /Every showcase asset is a deterministic HD product composite/i, "HD composite disclosure is missing");
assert.match(manifest.motionPolicy, /run once/i, "one-shot autoplay policy is missing");
assert.match(manifest.motionPolicy, /no more than five seconds/i, "autoplay duration boundary is missing");
assert.match(manifest.motionPolicy, /reduced motion/i, "reduced-motion policy is missing");
assert.deepEqual(new Set(manifest.assets.map((asset) => asset.id)), new Set(expected.keys()), "showcase asset IDs changed");

for (const asset of manifest.assets) {
  const contract = expected.get(asset.id);
  assert.ok(contract, `unexpected showcase asset ${asset.id}`);
  assert.equal(asset.poster, contract.poster, `${asset.id} poster filename changed`);
  assert.equal(asset.video ?? null, contract.video, `${asset.id} video contract changed`);
  assert.equal(asset.posterWidth, HD_WIDTH, `${asset.id} poster must be HD width`);
  assert.equal(asset.posterHeight, HD_HEIGHT, `${asset.id} poster must be HD height`);
  assert.equal(asset.sourceType, "deterministic-product-composite", `${asset.id} must use the truthful deterministic source type`);
  assert.match(asset.sourceLabel, /^HD deterministic product (?:composite|poster)$/i, `${asset.id} source label is not HD`);
  assert.equal(asset.hasAudio, false, `${asset.id} must remain silent`);

  const posterPath = `public/showcase/${asset.poster}`;
  const poster = read(posterPath);
  const posterStat = statSync(resolve(root, posterPath));
  assert.ok(posterStat.size >= 20_000, `${asset.id} poster is implausibly small for HD`);
  assert.equal(asset.posterBytes, posterStat.size, `${asset.id} poster byte count diverges from manifest`);
  assert.equal(asset.posterSha256, sha256(poster), `${asset.id} poster checksum diverges from manifest`);
  const dimensions = webpDimensions(poster, asset.poster);
  assert.deepEqual(dimensions, { width: HD_WIDTH, height: HD_HEIGHT }, `${asset.id} WebP dimensions diverge from HD contract`);

  if (contract.video) {
    assert.equal(asset.videoWidth, HD_WIDTH, `${asset.id} video must be HD width`);
    assert.equal(asset.videoHeight, HD_HEIGHT, `${asset.id} video must be HD height`);
    assert.equal(asset.frameRate, HD_FPS, `${asset.id} video must be 30 fps`);
    assert.ok(Math.abs(asset.durationSeconds - contract.duration) <= 0.06, `${asset.id} duration changed`);
    assert.ok(asset.durationSeconds <= MAX_AUTOPLAY_SECONDS, `${asset.id} exceeds the autoplay motion limit`);
    const videoPath = `public/showcase/${asset.video}`;
    const video = read(videoPath);
    const videoStat = statSync(resolve(root, videoPath));
    assert.ok(video.length >= 100_000 && video.length <= 15_000_000, `${asset.id} MP4 size is implausible for HD`);
    assert.equal(asset.videoBytes, videoStat.size, `${asset.id} video byte count diverges from manifest`);
    assert.equal(asset.videoSha256, sha256(video), `${asset.id} video checksum diverges from manifest`);
    assert.equal(video.subarray(4, 8).toString("ascii"), "ftyp", `${asset.id} is not an ISO MP4 file`);
    assert.ok(video.includes(Buffer.from("avc1")), `${asset.id} does not advertise H.264/avc1`);
    const moovIndex = video.indexOf(Buffer.from("moov"));
    const mdatIndex = video.indexOf(Buffer.from("mdat"));
    assert.ok(moovIndex >= 0 && mdatIndex >= 0, `${asset.id} is missing MP4 movie or media data`);
    assert.ok(moovIndex < mdatIndex, `${asset.id} is not fast-start encoded`);
    assert.ok(!video.includes(Buffer.from("mp4a")), `${asset.id} unexpectedly advertises AAC audio`);
    assert.ok(!video.includes(Buffer.from("soun")), `${asset.id} unexpectedly advertises an audio handler`);
    verifyVideo(videoPath, asset.id);
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
assert.doesNotMatch(showcaseContent, /production-swiftui-render|authentic production SwiftUI/i, "HD composites must not retain the old production-render claim");
assert.match(showcaseContent, /1920 × 1200/i, "visible HD dimensions are missing");
assert.match(showcaseContent, /not AI-generated/i, "visible showcase disclosure must reject AI-generated media");
assert.match(showcaseContent, /controlled fixture windows/i, "visible fixture disclosure is missing");
assert.match(showcaseContent, /run once for no more than five seconds/i, "visible autoplay boundary is missing");
assert.match(showcasePage, /createVideoStructuredData/, "showcase page is missing VideoObject markup");
assert.match(showcasePage, /headingAs="h1"/, "showcase page is missing its page-level H1");
assert.match(showcasePage, /breadcrumbs=\{breadcrumbs\}/, "showcase page is missing visible breadcrumbs");
assert.doesNotMatch(showcasePage, /<dl|<dt|<dd/, "mode media must not render metadata tables");
assert.doesNotMatch(showcasePage, /Item \{String|Resolution|Silent H\.264 MP4 \+ WebP/, "mode media still contains verbose item metadata");
assert.match(player, /asset\.video \?/, "showcase player must distinguish video and poster-only assets");
assert.match(player, /<video/, "showcase player must render native video elements when a clip exists");
assert.match(player, /<img/, "showcase player must render a poster fallback when a clip does not exist");
assert.match(player, /poster=\{asset\.poster\}/, "showcase player must use a stable poster URL");
assert.match(player, /data-autoplay-mode="one-shot"/, "showcase player must declare one-shot autoplay");
assert.match(player, /hasCompletedRef/, "showcase player must remember completed playback");
assert.match(player, /onEnded/, "showcase player must freeze after one playback");
assert.match(player, /video\.play\(\)/, "showcase media must autoplay when visible");
assert.match(player, /muted/, "showcase player must be muted");
assert.match(player, /playsInline/, "showcase player must play inline");
assert.match(player, /prefers-reduced-motion/, "showcase player must respect reduced motion");
assert.doesNotMatch(player, /\bloop\b/, "showcase autoplay must not loop");
assert.doesNotMatch(player, /togglePlayback|<button|Read the media description|<details/, "showcase media must not expose playback or transcript controls");
assert.match(structuredData, /videos = assets\.filter/, "VideoObject generation must exclude poster-only entries");
assert.equal(packageJson.scripts["security:deps"], "npm audit --audit-level=moderate", "dependency audit must fail on moderate advisories");
assert.match(packageJson.scripts["showcase:generate"], /normalize-showcase-autoplay/, "build must normalize autoplay duration");
assert.ok(
  packageJson.scripts.prebuild.includes("showcase:generate") || packageJson.scripts["seo:check"].includes("showcase:generate"),
  "Vercel prebuild path must generate HD media",
);
assert.equal(packageJson.dependencies.next, "16.2.11", "Next.js patch is not pinned");
assert.equal(packageJson.dependencies.resend, "6.18.0", "Resend patch is not pinned");
assert.equal(packageJson.dependencies.sharp, "0.35.3", "Sharp patch is not pinned");
assert.equal(packageJson.devDependencies.postcss, "8.5.21", "PostCSS patch is not pinned");
for (const unsupported of ["ScreenCaptureKit fast", "sub-50", "< 20MB", "Universal Binary"]) {
  assert.ok(!showcaseContent.includes(unsupported), `unsupported claim entered showcase content: ${unsupported}`);
}

console.log(`Showcase media verification passed for ${manifest.assets.length} sharp 1920x1200 assets and ${manifest.assets.filter((asset) => asset.video).length} silent one-shot H.264 videos at 30 fps with exact manifest checksums.`);
