#!/usr/bin/env node

import { readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = resolve(root, "public/showcase");
const manifestPath = resolve(outputDir, "manifest.json");
const overviewPath = resolve(outputDir, "overview.mp4");
const normalizedPath = resolve(outputDir, "overview.accessible.mp4");
const targetDurationSeconds = 4.8;

let ffmpegPath = process.env.FFMPEG_PATH;
if (!ffmpegPath) {
  const module = await import("ffmpeg-static");
  ffmpegPath = module.default;
}
if (!ffmpegPath) throw new Error("ffmpeg binary was not found");

await rm(normalizedPath, { force: true });

const args = [
  "-hide_banner",
  "-loglevel",
  "error",
  "-y",
  "-i",
  overviewPath,
  "-vf",
  "setpts=0.6*PTS,fps=30,scale=1920:1200:flags=lanczos,format=yuv420p",
  "-an",
  "-c:v",
  "libx264",
  "-preset",
  "medium",
  "-crf",
  "18",
  "-pix_fmt",
  "yuv420p",
  "-t",
  String(targetDurationSeconds),
  "-movflags",
  "+faststart",
  normalizedPath,
];

await new Promise((resolveExit, rejectExit) => {
  const child = spawn(ffmpegPath, args, { stdio: ["ignore", "inherit", "inherit"] });
  child.once("error", rejectExit);
  child.once("exit", (code) =>
    code === 0 ? resolveExit() : rejectExit(new Error(`ffmpeg exited with ${code}`)),
  );
});

await rename(normalizedPath, overviewPath);

const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const overview = manifest.assets.find((asset) => asset.id === "overview");
if (!overview) throw new Error("overview asset is missing from showcase manifest");
overview.durationSeconds = targetDurationSeconds;
manifest.motionPolicy =
  "Autoplay clips run once, never loop, last no more than five seconds, and remain static when reduced motion is requested.";

await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Normalized overview autoplay to ${targetDurationSeconds} seconds and recorded one-shot motion policy.`);
