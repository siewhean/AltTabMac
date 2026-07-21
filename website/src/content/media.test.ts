import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { screenshotAssets } from "./media";

const productAssetIDs = Object.keys(screenshotAssets).filter((id) => id !== "permissions");

function publicPath(src: string) {
  return join(process.cwd(), "public", src.replace(/^\//, ""));
}

function pngDimensions(src: string) {
  const data = readFileSync(publicPath(src));
  expect(data.subarray(1, 4).toString("ascii")).toBe("PNG");
  return { width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}

describe("product media", () => {
  it("uses real raster captures instead of generated product SVGs", () => {
    for (const id of productAssetIDs) {
      const asset = screenshotAssets[id];
      expect(asset.src, id).not.toMatch(/\.svg$/i);
      expect(() => readFileSync(publicPath(asset.src)), id).not.toThrow();
    }
  });

  it("declares the exact dimensions of every image and video poster", () => {
    for (const id of productAssetIDs) {
      const asset = screenshotAssets[id];
      const imageSrc = asset.kind === "video" ? asset.posterSrc : asset.src;
      expect(imageSrc, `${id} poster`).toBeTruthy();
      expect(pngDimensions(imageSrc!)).toEqual({
        width: asset.width,
        height: asset.height,
      });
    }
  });

  it("requires a local MP4 and poster for future recorded walkthroughs", () => {
    for (const id of productAssetIDs) {
      const asset = screenshotAssets[id];
      if (asset.kind !== "video") continue;
      expect(asset.src, id).toMatch(/^\/screenshots\/.+\.mp4$/);
      expect(asset.posterSrc, id).toMatch(/^\/screenshots\/.+\.png$/);
      expect(() => readFileSync(publicPath(asset.src)), id).not.toThrow();
    }
  });
});
