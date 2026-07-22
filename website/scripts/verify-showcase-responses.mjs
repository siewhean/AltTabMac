#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");
const manifest = JSON.parse(readFileSync(resolve(process.cwd(), "public/showcase/manifest.json"), "utf8"));

async function fetchPath(path, init = {}) {
  return fetch(`${baseUrl}${path}`, {
    redirect: "follow",
    headers: {
      "User-Agent": "CmdTabShowcaseVerifier/3.0",
      ...(init.headers || {}),
    },
    ...init,
  });
}

const pageResponse = await fetchPath("/showcase");
assert.equal(pageResponse.status, 200, `/showcase returned HTTP ${pageResponse.status}`);
const page = await pageResponse.text();
assert.match(page, /CmdTab in motion/i, "showcase H1 is missing");
assert.match(page, /without recording a private desktop/i, "privacy-safe showcase boundary is missing");
assert.match(page, /<video/i, "rendered showcase page is missing video elements");
assert.match(page, /<img/i, "rendered showcase page is missing poster-only fallback images");
assert.match(page, /<video[^>]*\splaysinline(?:="")?/i, "rendered showcase videos must play inline");
assert.match(page, /<video[^>]*\smuted(?:="")?/i, "rendered showcase videos must be muted");
assert.match(page, /<video[^>]*\sautoplay(?:="")?/i, "overview video must autoplay");
assert.doesNotMatch(page, /aria-label="(?:Play|Pause) /i, "showcase must not render play or pause buttons");
assert.doesNotMatch(page, /Read the media description/i, "showcase must not render transcript disclosures");
assert.doesNotMatch(page, /<details[^>]*>\s*<summary[^>]*>\s*Read the media description/i, "showcase contains a media description accordion");
assert.doesNotMatch(page, /<dt[^>]*>\s*(?:Resolution|Format|Source)/i, "showcase contains the removed media metadata table");
assert.match(page, /poster="\/showcase\/overview-poster\.webp"/i, "overview poster is missing from rendered HTML");
assert.match(page, /<source[^>]*src="\/showcase\/overview\.mp4"[^>]*type="video\/mp4"/i, "overview MP4 source is missing from rendered HTML");
assert.match(page, /src="\/showcase\/classic-grid-poster\.webp"/i, "Classic Grid poster fallback is missing");
assert.match(page, /src="\/showcase\/command-palette-poster\.webp"/i, "Command Palette poster fallback is missing");
assert.doesNotMatch(page, /classic-grid\.mp4|command-palette\.mp4/, "rendered page advertises nonexistent MP4s");
assert.match(page, /"@type":"VideoObject"/, "rendered VideoObject schema is missing");
assert.match(page, /"thumbnailUrl":"https:\/\/cmdtab\.net\/showcase\/overview-poster\.webp"/, "VideoObject thumbnail URL is wrong");
assert.match(page, /"contentUrl":"https:\/\/cmdtab\.net\/showcase\/overview\.mp4"/, "VideoObject content URL is wrong");

for (const asset of manifest.assets) {
  const posterPath = `/showcase/${asset.poster}`;
  assert.ok(page.includes(`src="${posterPath}"`) || page.includes(`poster="${posterPath}"`), `${posterPath} is not wired into rendered HTML`);

  const posterResponse = await fetchPath(posterPath);
  assert.equal(posterResponse.status, 200, `${posterPath} returned HTTP ${posterResponse.status}`);
  assert.match(posterResponse.headers.get("content-type") || "", /image\/webp/i, `${posterPath} has the wrong content type`);
  const posterBytes = Buffer.from(await posterResponse.arrayBuffer());
  assert.equal(posterBytes.length, statSync(resolve(process.cwd(), `public/showcase/${asset.poster}`)).size, `${posterPath} response bytes diverge from committed file`);
  assert.equal(posterBytes.subarray(0, 4).toString("ascii"), "RIFF", `${posterPath} is not RIFF WebP`);
  assert.equal(posterBytes.subarray(8, 12).toString("ascii"), "WEBP", `${posterPath} is not WebP`);

  if (!asset.video) continue;
  const videoPath = `/showcase/${asset.video}`;
  assert.ok(page.includes(`src="${videoPath}"`), `${videoPath} is not wired into rendered HTML`);
  const videoResponse = await fetchPath(videoPath);
  assert.equal(videoResponse.status, 200, `${videoPath} returned HTTP ${videoResponse.status}`);
  assert.match(videoResponse.headers.get("content-type") || "", /video\/mp4/i, `${videoPath} has the wrong content type`);
  const videoBytes = Buffer.from(await videoResponse.arrayBuffer());
  assert.equal(videoBytes.length, statSync(resolve(process.cwd(), `public/showcase/${asset.video}`)).size, `${videoPath} response bytes diverge from committed file`);
  assert.equal(videoBytes.subarray(4, 8).toString("ascii"), "ftyp", `${videoPath} is not an MP4`);

  const rangeResponse = await fetchPath(videoPath, { headers: { Range: "bytes=0-1023" } });
  assert.ok([200, 206].includes(rangeResponse.status), `${videoPath} range request returned HTTP ${rangeResponse.status}`);
  if (rangeResponse.status === 206) {
    assert.match(rangeResponse.headers.get("content-range") || "", /^bytes 0-1023\//, `${videoPath} range response is malformed`);
  }
}

const manifestResponse = await fetchPath("/showcase/manifest.json");
assert.equal(manifestResponse.status, 200, `/showcase/manifest.json returned HTTP ${manifestResponse.status}`);
assert.match(manifestResponse.headers.get("content-type") || "", /application\/json/i, "showcase manifest content type is wrong");

console.log(`Rendered showcase verification passed for ${manifest.assets.length} posters and ${manifest.assets.filter((asset) => asset.video).length} autoplay MP4 loops.`);
