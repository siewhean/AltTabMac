import { readFileSync } from "node:fs";
import { resolve } from "node:path";

export type StableReleaseManifest = {
  schemaVersion: 1;
  channel: "stable";
  version: string;
  build: number;
  minimumMacOS: string;
  dmgURL: string;
  bytes: number;
  sha256: string;
  releaseDate: string;
  sourceSHA: string;
  appcastURL: string;
};

const MANIFEST_KEYS = [
  "appcastURL",
  "build",
  "bytes",
  "channel",
  "dmgURL",
  "minimumMacOS",
  "releaseDate",
  "schemaVersion",
  "sha256",
  "sourceSHA",
  "version",
] as const;

function isHttpsURL(value: string) {
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" &&
      parsed.username === "" &&
      parsed.password === "" &&
      parsed.search === "" &&
      parsed.hash === "";
  } catch {
    return false;
  }
}

export function parseStableReleaseManifest(value: unknown): StableReleaseManifest {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Stable release manifest must be an object");
  }

  const manifest = value as Record<string, unknown>;
  const keys = Object.keys(manifest).sort();
  if (keys.length !== MANIFEST_KEYS.length || keys.some((key, index) => key !== MANIFEST_KEYS[index])) {
    throw new Error("Stable release manifest keys do not match schema version 1");
  }
  if (manifest.schemaVersion !== 1 || manifest.channel !== "stable") {
    throw new Error("Only the stable schema version 1 release manifest is supported");
  }
  if (typeof manifest.version !== "string" || !/^\d+\.\d+\.\d+$/.test(manifest.version)) {
    throw new Error("Stable release version is invalid");
  }
  if (!Number.isInteger(manifest.build) || Number(manifest.build) < 1) {
    throw new Error("Stable release build is invalid");
  }
  if (typeof manifest.minimumMacOS !== "string" || !/^\d+\.\d+(?:\.\d+)?$/.test(manifest.minimumMacOS)) {
    throw new Error("Stable release minimum macOS is invalid");
  }
  if (typeof manifest.sourceSHA !== "string" || !/^[a-f0-9]{40}$/.test(manifest.sourceSHA)) {
    throw new Error("Stable release source SHA is invalid");
  }
  if (typeof manifest.sha256 !== "string" || !/^[a-f0-9]{64}$/.test(manifest.sha256)) {
    throw new Error("Stable release artifact SHA-256 is invalid");
  }
  if (!Number.isInteger(manifest.bytes) || Number(manifest.bytes) < 1) {
    throw new Error("Stable release artifact byte count is invalid");
  }
  const releaseDate = typeof manifest.releaseDate === "string"
    ? manifest.releaseDate.match(/^(\d{4})-(\d{2})-(\d{2})$/)
    : null;
  const parsedReleaseDate = releaseDate
    ? new Date(Date.UTC(Number(releaseDate[1]), Number(releaseDate[2]) - 1, Number(releaseDate[3])))
    : null;
  if (!releaseDate || !parsedReleaseDate ||
      parsedReleaseDate.getUTCFullYear() !== Number(releaseDate[1]) ||
      parsedReleaseDate.getUTCMonth() !== Number(releaseDate[2]) - 1 ||
      parsedReleaseDate.getUTCDate() !== Number(releaseDate[3])) {
    throw new Error("Stable release date is invalid");
  }
  if (typeof manifest.dmgURL !== "string" || !isHttpsURL(manifest.dmgURL)) {
    throw new Error("Stable release DMG URL is invalid");
  }
  const dmgPath = new URL(manifest.dmgURL).pathname;
  if (!dmgPath.includes(manifest.sourceSHA) ||
      !dmgPath.endsWith(`/CmdTab-${manifest.version}-${manifest.build}.dmg`)) {
    throw new Error("Stable release DMG URL is not immutable or does not match the release");
  }
  if (manifest.appcastURL !== "https://cmdtab.net/releases/appcast.xml") {
    throw new Error("Stable release appcast URL is invalid");
  }

  return manifest as StableReleaseManifest;
}

export function getStableReleaseManifest(): StableReleaseManifest | null {
  const manifestPath = resolve(process.cwd(), "..", "release", "stable.json");
  try {
    return parseStableReleaseManifest(JSON.parse(readFileSync(manifestPath, "utf8")));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw error;
  }
}
