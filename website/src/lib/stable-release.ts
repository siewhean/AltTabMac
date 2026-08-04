import { readFileSync } from "node:fs";
import { resolve } from "node:path";

type ReleaseManifestBase = {
  schemaVersion: 1;
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

export type StableReleaseManifest = ReleaseManifestBase & { channel: "stable" };
export type BetaReleaseManifest = ReleaseManifestBase & { channel: "beta" };

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

function parseReleaseManifest(
  value: unknown,
  channel: "stable" | "beta",
): ReleaseManifestBase & { channel: "stable" | "beta" } {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Stable release manifest must be an object");
  }

  const manifest = value as Record<string, unknown>;
  const keys = Object.keys(manifest).sort();
  if (keys.length !== MANIFEST_KEYS.length || keys.some((key, index) => key !== MANIFEST_KEYS[index])) {
    throw new Error("Stable release manifest keys do not match schema version 1");
  }
  if (manifest.schemaVersion !== 1 || manifest.channel !== channel) {
    throw new Error(`Only the ${channel} schema version 1 release manifest is supported`);
  }
  const versionPattern = channel === "beta"
    ? /^\d+\.\d+\.\d+-beta\.\d+$/
    : /^\d+\.\d+\.\d+$/;
  if (typeof manifest.version !== "string" || !versionPattern.test(manifest.version)) {
    throw new Error(`${channel} release version is invalid`);
  }
  if (!Number.isInteger(manifest.build) || Number(manifest.build) < 1) {
    throw new Error(`${channel} release build is invalid`);
  }
  if (typeof manifest.minimumMacOS !== "string" || !/^\d+\.\d+(?:\.\d+)?$/.test(manifest.minimumMacOS)) {
    throw new Error(`${channel} release minimum macOS is invalid`);
  }
  if (typeof manifest.sourceSHA !== "string" || !/^[a-f0-9]{40}$/.test(manifest.sourceSHA)) {
    throw new Error(`${channel} release source SHA is invalid`);
  }
  if (typeof manifest.sha256 !== "string" || !/^[a-f0-9]{64}$/.test(manifest.sha256)) {
    throw new Error(`${channel} release artifact SHA-256 is invalid`);
  }
  if (!Number.isInteger(manifest.bytes) || Number(manifest.bytes) < 1) {
    throw new Error(`${channel} release artifact byte count is invalid`);
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
    throw new Error(`${channel} release date is invalid`);
  }
  if (typeof manifest.dmgURL !== "string" || !isHttpsURL(manifest.dmgURL)) {
    throw new Error(`${channel} release DMG URL is invalid`);
  }
  const dmgPath = new URL(manifest.dmgURL).pathname;
  if (!dmgPath.includes(manifest.sourceSHA) ||
      !dmgPath.endsWith(`/CmdTab-${manifest.version}-${manifest.build}.dmg`)) {
    throw new Error(`${channel} release DMG URL is not immutable or does not match the release`);
  }
  const expectedAppcast = channel === "beta"
    ? "https://cmdtab.net/releases/beta/appcast.xml"
    : "https://cmdtab.net/releases/appcast.xml";
  if (manifest.appcastURL !== expectedAppcast) {
    throw new Error(`${channel} release appcast URL is invalid`);
  }

  return manifest as ReleaseManifestBase & { channel: "stable" | "beta" };
}

export function parseStableReleaseManifest(value: unknown): StableReleaseManifest {
  return parseReleaseManifest(value, "stable") as StableReleaseManifest;
}

export function parseBetaReleaseManifest(value: unknown): BetaReleaseManifest {
  return parseReleaseManifest(value, "beta") as BetaReleaseManifest;
}

function appcastText(appcast: string, tag: string) {
  return new RegExp(`<${tag}>([^<]+)</${tag}>`).exec(appcast)?.[1];
}

function appcastAttribute(enclosure: string, name: string) {
  return new RegExp(`\\b${name}="([^"]+)"`).exec(enclosure)?.[1];
}

/** Fail closed before serving a beta feed: it must describe this exact manifest artifact. */
export function validateBetaAppcast(appcast: string, manifest: BetaReleaseManifest) {
  const items = appcast.match(/<item(?:\s[^>]*)?>[\s\S]*?<\/item>/g) ?? [];
  if (items.length !== 1) throw new Error("beta appcast must contain exactly one item");
  const item = items[0];
  if (appcastText(item, "sparkle:channel") !== "beta") {
    throw new Error("beta appcast channel is invalid");
  }
  if (appcastText(item, "sparkle:version") !== String(manifest.build)) {
    throw new Error("beta appcast build does not match the manifest");
  }
  const bundledMarketingVersion = manifest.version.replace(/-beta\.\d+$/, "");
  if (appcastText(item, "sparkle:shortVersionString") !== bundledMarketingVersion) {
    throw new Error("beta appcast short version does not match the bundled marketing version");
  }
  if (appcastText(item, "sparkle:minimumSystemVersion") !== manifest.minimumMacOS) {
    throw new Error("beta appcast minimum macOS does not match the manifest");
  }
  const enclosure = /<enclosure\s+[^>]*\/?>(?:<\/enclosure>)?/.exec(item)?.[0];
  if (!enclosure) throw new Error("beta appcast enclosure is missing");
  if (appcastAttribute(enclosure, "url") !== manifest.dmgURL) {
    throw new Error("beta appcast enclosure URL does not match the manifest");
  }
  if (appcastAttribute(enclosure, "length") !== String(manifest.bytes)) {
    throw new Error("beta appcast enclosure length does not match the manifest");
  }
  if (appcastAttribute(enclosure, "sparkle:sha256") !== manifest.sha256) {
    throw new Error("beta appcast enclosure hash does not match the manifest");
  }
  const signature = appcastAttribute(enclosure, "sparkle:edSignature");
  if (!signature || signature.length < 80) {
    throw new Error("beta appcast enclosure signature is invalid");
  }
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

export function getBetaReleaseManifest(): BetaReleaseManifest | null {
  return readBetaReleaseManifest();
}

/**
 * A beta feed is unpublished unless its manifest is complete and valid. This
 * treats missing and malformed repository artifacts alike, so callers cannot
 * expose parse details or turn release-preparation mistakes into a 500.
 */
export function readBetaReleaseManifest(
  readManifest: (path: string, encoding: BufferEncoding) => string = readFileSync,
): BetaReleaseManifest | null {
  const manifestPath = resolve(process.cwd(), "..", "release", "beta.json");
  try {
    return parseBetaReleaseManifest(JSON.parse(readManifest(manifestPath, "utf8")));
  } catch {
    return null;
  }
}
