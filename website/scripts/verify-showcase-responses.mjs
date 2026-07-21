#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");
const manifest = JSON.parse(readFileSync(resolve(process.cwd(), "public/showcase/manifest.json"), "utf8"));

async function fetchPath(path, init = {}) {
  return fetch(`${baseUrl}${path}`, {
    redirect: "follow",
    headers: {
      "User-Agent": "CmdTabShowcaseVerifier/1.0",
      ...(init.headers || {}),
    },
    ...init,
  });
}

const pageResponse = await fetchPath("/showcase");
assert.equal(pageResponse.status, 200, `/showcase returned HTTP ${pageResponse.status}`);
const page = await pageResponse.text();
assert.match(page, /See the CmdTab switcher move, search, and reflow/i, "showcase H1 is missing");
assert.match(page, /real renders of CmdTab’s production SwiftUI\/AppKit switcher views/i, "showcase production-view disclosure is missing");
assert.match(page, /not AI-generated/i, "showcase AI-generation disclosure is missing");
assert.match(page, /<video/i, "rendered showcase page is missing video elements");
assert.match(page, /playsinline=""/i, "rendered showcase videos must play inline");
assert.match(page, /muted=""/i, "rendered showcase videos must be muted");
assert.match(page, /poster="\/showcase\/overview-poster\.png"/i, "overview poster is missing from rendered HTML");
assert.match(page, /"@type":"VideoObject"/, "rendered VideoObject schema is missing");
assert.match(page, /"thumbnailUrl":"https:\/\/cmdtab\.net\/showcase\/overview-poster\.png"/, "VideoObject thumbnail URL is wrong");
assert.match(page, /"contentUrl":"https:\/\/cmdtab\.net\/showcase\/overview\.mp4"/, "VideoObject content URL is wrong");
assert.match(page, /Read the clip transcript/i, "visible video transcripts are missing");

for (const asset of manifest.assets) {
  const posterPath = `/showcase/${asset.poster}`;
  const videoPath = `/showcase/${asset.video}`;

  const posterResponse = await fetchPath(posterPath);
  assert.equal(posterResponse.status, 200, `${posterPath} returned HTTP ${posterResponse.status}`);
  assert.match(posterResponse.headers.get("content-type") || "", /image\/png/i, `${posterPath} has the wrong content type`);
  const posterBytes = Buffer.from(await posterResponse.arrayBuffer());
  assert.equal(posterBytes.length, asset.posterBytes, `${posterPath} byte count diverges from manifest`);

  const videoResponse = await fetchPath(videoPath);
  assert.equal(videoResponse.status, 200, `${videoPath} returned HTTP ${videoResponse.status}`);
  assert.match(videoResponse.headers.get("content-type") || "", /video\/mp4/i, `${videoPath} has the wrong content type`);
  const videoBytes = Buffer.from(await videoResponse.arrayBuffer());
  assert.equal(videoBytes.length, asset.videoBytes, `${videoPath} byte count diverges from manifest`);

  const rangeResponse = await fetchPath(videoPath, { headers: { Range: "bytes=0-1023" } });
  assert.ok([200, 206].includes(rangeResponse.status), `${videoPath} range request returned HTTP ${rangeResponse.status}`);
  if (rangeResponse.status === 206) {
    assert.match(rangeResponse.headers.get("content-range") || "", /^bytes 0-1023\//, `${videoPath} range response is malformed`);
  }
}

const manifestResponse = await fetchPath("/showcase/manifest.json");
assert.equal(manifestResponse.status, 200, `/showcase/manifest.json returned HTTP ${manifestResponse.status}`);
assert.match(manifestResponse.headers.get("content-type") || "", /application\/json/i, "showcase manifest content type is wrong");

console.log(`Rendered showcase verification passed for ${manifest.assets.length} posters and MP4 loops.`);
