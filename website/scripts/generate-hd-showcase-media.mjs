#!/usr/bin/env node

import { mkdir, rm, writeFile, stat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import sharp from "sharp";

const WIDTH = 1920;
const HEIGHT = 1200;
const FPS = 30;
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = resolve(root, "public/showcase");
let ffmpegPath = process.env.FFMPEG_PATH;
if (!ffmpegPath) {
  const module = await import("ffmpeg-static");
  ffmpegPath = module.default;
}
if (!ffmpegPath) throw new Error("ffmpeg binary was not found");

const apps = [
  { name: "Notes", title: "Launch checklist", color: "#F6C85F", accent: "#FBE6A4" },
  { name: "Code", title: "CmdTab Website", color: "#5CC8FF", accent: "#A7E4FF" },
  { name: "Browser", title: "Release dashboard", color: "#8B7CFF", accent: "#C5BCFF" },
  { name: "Mail", title: "Launch support", color: "#FF769B", accent: "#FFBED0" },
  { name: "Music", title: "Deep work mix", color: "#66D99A", accent: "#B4F2CF" },
  { name: "Calendar", title: "Founder launch week", color: "#FF9A61", accent: "#FFD0B6" },
];

function esc(value) {
  return String(value).replace(/[&<>\"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[char]);
}

function defs() {
  return `<defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#040812"/><stop offset=".55" stop-color="#091526"/><stop offset="1" stop-color="#0B2035"/></linearGradient>
    <radialGradient id="glow"><stop stop-color="#45CFFF" stop-opacity=".28"/><stop offset="1" stop-color="#45CFFF" stop-opacity="0"/></radialGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="180%"><feDropShadow dx="0" dy="34" stdDeviation="36" flood-color="#000" flood-opacity=".55"/></filter>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="24"/></filter>
  </defs>`;
}

function chrome(label = "CmdTab showcase", state = "Controlled fixtures") {
  return `<g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
    <rect x="34" y="28" width="1852" height="74" rx="28" fill="#07101D" fill-opacity=".86" stroke="#FFFFFF" stroke-opacity=".12"/>
    <circle cx="78" cy="65" r="13" fill="#69D6FF"/><text x="108" y="75" fill="#F3F7FF" font-size="27" font-weight="650">${esc(label)}</text>
    <rect x="1540" y="49" width="292" height="34" rx="17" fill="#FFFFFF" fill-opacity=".06"/>
    <text x="1686" y="73" fill="#AEBBD0" font-size="18" text-anchor="middle">${esc(state)}</text>
  </g>`;
}

function desktopBackdrop() {
  return `<rect width="${WIDTH}" height="${HEIGHT}" fill="url(#bg)"/>
    <circle cx="1580" cy="175" r="430" fill="url(#glow)"/>
    <circle cx="215" cy="1080" r="330" fill="#745BFF" fill-opacity=".08"/>
    <g opacity=".22" filter="url(#soft)"><rect x="75" y="160" width="555" height="360" rx="34" fill="#17263D"/><rect x="1260" y="180" width="560" height="350" rx="34" fill="#13283D"/><rect x="170" y="735" width="600" height="350" rx="34" fill="#231C34"/></g>`;
}

function titleBand(eyebrow, title, detail) {
  return `<g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
    <text x="100" y="1080" fill="#69D6FF" font-size="20" font-weight="750" letter-spacing="5">${esc(eyebrow.toUpperCase())}</text>
    <text x="100" y="1124" fill="#F3F7FF" font-size="31" font-weight="650">${esc(title)}</text>
    <text x="100" y="1160" fill="#98A8BE" font-size="19">${esc(detail)}</text>
  </g>`;
}

function windowPreview(app, x, y, w, h, selected = false, alpha = 1) {
  const scale = selected ? 1.018 : 1;
  const cx = x + w / 2;
  const cy = y + h / 2;
  return `<g opacity="${alpha}" transform="translate(${cx} ${cy}) scale(${scale}) translate(${-cx} ${-cy})" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
    ${selected ? `<rect x="${x - 12}" y="${y - 12}" width="${w + 24}" height="${h + 24}" rx="34" fill="#69D6FF" fill-opacity=".12" stroke="#69D6FF" stroke-width="6"/>` : ""}
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="26" fill="#0B1220" stroke="#FFFFFF" stroke-opacity=".12" filter="url(#shadow)"/>
    <rect x="${x}" y="${y}" width="${w}" height="48" rx="26" fill="#121C2D"/><rect x="${x}" y="${y + 24}" width="${w}" height="24" fill="#121C2D"/>
    <circle cx="${x + 24}" cy="${y + 24}" r="7" fill="#FF6B6B"/><circle cx="${x + 46}" cy="${y + 24}" r="7" fill="#F7C953"/><circle cx="${x + 68}" cy="${y + 24}" r="7" fill="#63D97A"/>
    <rect x="${x + 24}" y="${y + 72}" width="${w - 48}" height="${h - 128}" rx="18" fill="${app.color}" fill-opacity=".14"/>
    <rect x="${x + 46}" y="${y + 94}" width="${Math.round(w * .36)}" height="17" rx="8" fill="${app.accent}" fill-opacity=".82"/>
    <rect x="${x + 46}" y="${y + 126}" width="${Math.round(w * .68)}" height="12" rx="6" fill="#F3F7FF" fill-opacity=".25"/>
    <rect x="${x + 46}" y="${y + 151}" width="${Math.round(w * .52)}" height="12" rx="6" fill="#F3F7FF" fill-opacity=".16"/>
    <rect x="${x + 46}" y="${y + 190}" width="${Math.round(w * .72)}" height="${Math.max(36, h - 250)}" rx="14" fill="#02050A" fill-opacity=".32"/>
    <circle cx="${x + 42}" cy="${y + h - 34}" r="16" fill="${app.color}"/><text x="${x + 70}" y="${y + h - 27}" fill="#F3F7FF" font-size="21" font-weight="650">${esc(app.name)}</text>
    <text x="${x + w - 24}" y="${y + h - 27}" fill="#8FA0B8" font-size="17" text-anchor="end">${esc(app.title)}</text>
  </g>`;
}

function classicScene(progress = 0, selected = 1) {
  const cols = 3;
  const w = 460;
  const h = 300;
  const gapX = 36;
  const gapY = 38;
  const startX = (WIDTH - (cols * w + (cols - 1) * gapX)) / 2;
  const startY = 175;
  const cards = apps.map((app, index) => {
    const col = index % cols;
    const row = Math.floor(index / cols);
    const yNudge = index === selected ? -8 * Math.sin(Math.min(1, progress) * Math.PI) : 0;
    return windowPreview(app, startX + col * (w + gapX), startY + row * (h + gapY) + yNudge, w, h, index === selected);
  }).join("");
  return `${desktopBackdrop()}${chrome("CmdTab Classic Grid", "Exact-window targets")}${cards}${titleBand("Classic Grid", "Choose one exact window", "Separate windows remain visible in one global recent-use sequence")}`;
}

function paletteScene(progress = 0) {
  // "launch" matches three fixture windows (Notes, Mail, Calendar), so the poster shows a successful search.
  const query = "launch";
  const typed = query.slice(0, Math.max(0, Math.min(query.length, Math.floor(progress * 9))));
  const results = apps.filter((app) => !typed || `${app.name} ${app.title}`.toLowerCase().includes(typed));
  return `${desktopBackdrop()}${chrome("CmdTab Command Palette", "Local matching")}
    <g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" filter="url(#shadow)">
      <rect x="290" y="205" width="1340" height="720" rx="38" fill="#07101D" fill-opacity=".97" stroke="#FFFFFF" stroke-opacity=".14"/>
      <rect x="350" y="270" width="1220" height="92" rx="26" fill="#111C2E" stroke="#69D6FF" stroke-opacity=".5"/>
      <circle cx="400" cy="316" r="17" fill="none" stroke="#69D6FF" stroke-width="5"/><line x1="412" y1="329" x2="430" y2="347" stroke="#69D6FF" stroke-width="5" stroke-linecap="round"/>
      <text x="455" y="329" fill="${typed ? "#F3F7FF" : "#7789A2"}" font-size="34" font-weight="520">${esc(typed || "Type an app or window title")}</text>
      <rect x="1400" y="294" width="118" height="44" rx="22" fill="#FFFFFF" fill-opacity=".07"/><text x="1459" y="324" fill="#A9B8CB" font-size="17" text-anchor="middle">LOCAL</text>
      ${results.length ? results.slice(0, 4).map((app, i) => {
        const y = 405 + i * 118;
        const selected = i === 0;
        return `<g><rect x="350" y="${y}" width="1220" height="94" rx="24" fill="${selected ? "#69D6FF" : "#FFFFFF"}" fill-opacity="${selected ? ".10" : ".035"}" stroke="${selected ? "#69D6FF" : "#FFFFFF"}" stroke-opacity="${selected ? ".70" : ".08"}" stroke-width="${selected ? 3 : 1}"/>
          <circle cx="405" cy="${y + 47}" r="24" fill="${app.color}"/><text x="452" y="${y + 41}" fill="#F3F7FF" font-size="25" font-weight="650">${esc(app.name)}</text><text x="452" y="${y + 69}" fill="#91A2B8" font-size="18">${esc(app.title)}</text>
          ${selected ? `<rect x="1424" y="${y + 27}" width="92" height="40" rx="20" fill="#69D6FF" fill-opacity=".15"/><text x="1470" y="${y + 54}" fill="#69D6FF" font-size="17" text-anchor="middle">RETURN</text>` : ""}
        </g>`;
      }).join("") : `<text x="960" y="580" fill="#9AABC0" font-size="28" text-anchor="middle">No matching fixture windows</text>`}
    </g>${titleBand("Command Palette", "Search app and window text", "Matching stays on the Mac; raw queries are not sent in app telemetry")}`;
}

function radialScene(progress = 0) {
  const cx = 960;
  const cy = 585;
  const radius = 330;
  const selected = Math.floor(progress * apps.length) % apps.length;
  const nodes = apps.map((app, index) => {
    const angle = -Math.PI / 2 + index * (Math.PI * 2 / apps.length);
    const x = cx + Math.cos(angle) * radius;
    const y = cy + Math.sin(angle) * radius;
    const isSelected = index === selected;
    return `<g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
      ${isSelected ? `<circle cx="${x}" cy="${y}" r="92" fill="#69D6FF" fill-opacity=".12" stroke="#69D6FF" stroke-width="6"/>` : `<circle cx="${x}" cy="${y}" r="78" fill="#101A2B" stroke="#FFFFFF" stroke-opacity=".12"/>`}
      <circle cx="${x}" cy="${y - 10}" r="32" fill="${app.color}"/><text x="${x}" y="${y + 49}" fill="${isSelected ? "#F3F7FF" : "#A9B7CA"}" font-size="19" font-weight="650" text-anchor="middle">${esc(app.name)}</text>
    </g>`;
  }).join("");
  const active = apps[selected];
  return `${desktopBackdrop()}${chrome("CmdTab Radial Menu", "Directional selection")}
    <circle cx="${cx}" cy="${cy}" r="430" fill="#07101D" fill-opacity=".80" stroke="#FFFFFF" stroke-opacity=".09" filter="url(#shadow)"/>
    <circle cx="${cx}" cy="${cy}" r="235" fill="none" stroke="#69D6FF" stroke-opacity=".18" stroke-width="2" stroke-dasharray="9 16"/>
    ${nodes}
    <g font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif"><circle cx="${cx}" cy="${cy}" r="140" fill="#0C1728" stroke="#69D6FF" stroke-opacity=".35"/>
      <circle cx="${cx}" cy="${cy - 30}" r="40" fill="${active.color}"/><text x="${cx}" y="${cy + 36}" fill="#F3F7FF" font-size="28" font-weight="700" text-anchor="middle">${esc(active.name)}</text><text x="${cx}" y="${cy + 70}" fill="#94A5BA" font-size="19" text-anchor="middle">${esc(active.title)}</text></g>
    ${titleBand("Radial Menu", "Switch by direction and position", "The same exact-window sequence, arranged for spatial recall")}`;
}

function quickScene(progress = 0) {
  const gone = progress > .55;
  const visibleApps = gone ? apps.filter((_, index) => index !== 1) : apps;
  const cols = 3;
  const w = 460;
  const h = 300;
  const gapX = 36;
  const gapY = 38;
  const startX = (WIDTH - (cols * w + (cols - 1) * gapX)) / 2;
  const startY = 175;
  const cards = visibleApps.map((app, index) => {
    const col = index % cols;
    const row = Math.floor(index / cols);
    const originalIndex = apps.indexOf(app);
    const alpha = originalIndex === 1 && progress > .35 ? Math.max(0, 1 - (progress - .35) * 5) : 1;
    return windowPreview(app, startX + col * (w + gapX), startY + row * (h + gapY), w, h, originalIndex === 1 && !gone, alpha);
  }).join("");
  return `${desktopBackdrop()}${chrome("CmdTab Quick Actions", "Selected target mutation")}${cards}
    ${titleBand("Quick Actions", "Act without entering the window", "Hide, minimize, close, or quit from the current selection")}`;
}

function svg(body) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">${defs()}${body}</svg>`;
}

async function renderWebP(filename, body) {
  await sharp(Buffer.from(svg(body))).webp({ quality: 92, effort: 5, smartSubsample: true }).toFile(resolve(outputDir, filename));
}

async function encodeVideo(filename, keyframes, durationSeconds) {
  const tempDir = resolve(outputDir, `.frames-${filename.replace(/\W+/g, "-")}`);
  await rm(tempDir, { recursive: true, force: true });
  await mkdir(tempDir, { recursive: true });
  const concatLines = [];
  for (let index = 0; index < keyframes.length; index += 1) {
    const framePath = resolve(tempDir, `frame-${String(index).padStart(3, "0")}.png`);
    await sharp(Buffer.from(svg(keyframes[index].body))).png({ compressionLevel: 4 }).toFile(framePath);
    concatLines.push(`file '${framePath.replaceAll("'", "'\\''")}'`, `duration ${keyframes[index].duration}`);
  }
  const finalPath = resolve(tempDir, `frame-${String(keyframes.length - 1).padStart(3, "0")}.png`);
  concatLines.push(`file '${finalPath.replaceAll("'", "'\\''")}'`);
  const listPath = resolve(tempDir, "concat.txt");
  await writeFile(listPath, `${concatLines.join("\n")}\n`);
  const target = resolve(outputDir, filename);
  const args = [
    "-hide_banner", "-loglevel", "error", "-y",
    "-f", "concat", "-safe", "0", "-i", listPath,
    "-vf", `fps=${FPS},scale=${WIDTH}:${HEIGHT}:flags=lanczos,format=yuv420p`,
    "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
    "-r", String(FPS), "-t", String(durationSeconds), "-movflags", "+faststart", target,
  ];
  await new Promise((resolveExit, rejectExit) => {
    const child = spawn(ffmpegPath, args, { stdio: ["ignore", "inherit", "inherit"] });
    child.once("error", rejectExit);
    child.once("exit", (code) => code === 0 ? resolveExit() : rejectExit(new Error(`ffmpeg exited with ${code}`)));
  });
  await rm(tempDir, { recursive: true, force: true });
}

async function fileSha(path) {
  const buffer = await import("node:fs/promises").then(({ readFile }) => readFile(path));
  return createHash("sha256").update(buffer).digest("hex");
}

await mkdir(outputDir, { recursive: true });
for (const name of [
  "overview-poster.webp", "overview.mp4", "classic-grid-poster.webp", "command-palette-poster.webp",
  "radial-menu-poster.webp", "radial-menu.mp4", "quick-actions-poster.webp", "quick-actions.mp4",
]) await rm(resolve(outputDir, name), { force: true });

await renderWebP("overview-poster.webp", classicScene(.7, 1));
await renderWebP("classic-grid-poster.webp", classicScene(.7, 1));
await renderWebP("command-palette-poster.webp", paletteScene(.78));
await renderWebP("radial-menu-poster.webp", radialScene(.42));
await renderWebP("quick-actions-poster.webp", quickScene(.18));

await encodeVideo("overview.mp4", [
  { body: classicScene(.25, 0), duration: .65 }, { body: classicScene(.55, 1), duration: .65 }, { body: classicScene(.85, 2), duration: .65 },
  { body: paletteScene(.18), duration: .55 }, { body: paletteScene(.48), duration: .55 }, { body: paletteScene(.78), duration: .65 },
  { body: radialScene(.05), duration: .55 }, { body: radialScene(.34), duration: .55 }, { body: radialScene(.68), duration: .65 },
  { body: quickScene(.18), duration: .65 }, { body: quickScene(.48), duration: .65 }, { body: quickScene(.78), duration: 1.1 },
], 8);
await encodeVideo("radial-menu.mp4", [
  { body: radialScene(.02), duration: .8 }, { body: radialScene(.18), duration: .8 }, { body: radialScene(.35), duration: .8 },
  { body: radialScene(.52), duration: .8 }, { body: radialScene(.69), duration: .8 }, { body: radialScene(.86), duration: 1.0 },
], 5);
await encodeVideo("quick-actions.mp4", [
  { body: quickScene(.18), duration: 1.15 }, { body: quickScene(.48), duration: 1.15 }, { body: quickScene(.78), duration: 1.7 },
], 4);

const assetSpecs = [
  { id: "overview", title: "CmdTab app switcher overview", poster: "overview-poster.webp", video: "overview.mp4", durationSeconds: 8 },
  { id: "classic-grid", title: "Classic Grid exact-window preview", poster: "classic-grid-poster.webp", video: null },
  { id: "command-palette", title: "Command Palette local window search", poster: "command-palette-poster.webp", video: null },
  { id: "radial-menu", title: "Radial Menu directional selection", poster: "radial-menu-poster.webp", video: "radial-menu.mp4", durationSeconds: 5 },
  { id: "quick-actions", title: "Quick Actions selected-item mutation", poster: "quick-actions-poster.webp", video: "quick-actions.mp4", durationSeconds: 4 },
];
const assets = [];
for (const spec of assetSpecs) {
  const posterPath = resolve(outputDir, spec.poster);
  const entry = {
    ...spec,
    posterWidth: WIDTH,
    posterHeight: HEIGHT,
    sourceType: "deterministic-product-composite",
    sourceLabel: spec.video ? "HD deterministic product composite" : "HD deterministic product poster",
    hasAudio: false,
    posterBytes: (await stat(posterPath)).size,
    posterSha256: await fileSha(posterPath),
  };
  if (spec.video) {
    const videoPath = resolve(outputDir, spec.video);
    Object.assign(entry, {
      videoWidth: WIDTH,
      videoHeight: HEIGHT,
      frameRate: FPS,
      videoBytes: (await stat(videoPath)).size,
      videoSha256: await fileSha(videoPath),
    });
  }
  assets.push(entry);
}
const manifest = {
  schemaVersion: 5,
  reviewedAt: "2026-07-22",
  title: "CmdTab HD product showcase",
  source: "Deterministic privacy-safe HD product showcase",
  fixturePolicy: "Controlled fixture windows only; no private desktop capture; no AI-generated product screenshots.",
  qualityPolicy: `All posters and videos are ${WIDTH}x${HEIGHT}. Videos are silent H.264 at ${FPS} fps with fast-start metadata.`,
  disclosure: "Every showcase asset is a deterministic HD product composite based on CmdTab’s current production geometry, styling, item model, and documented behavior contract.",
  assets,
};
await writeFile(resolve(outputDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Generated ${assets.length} HD showcase assets at ${WIDTH}x${HEIGHT}; videos are ${FPS} fps.`);
