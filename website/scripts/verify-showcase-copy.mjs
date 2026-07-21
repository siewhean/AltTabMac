#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const source = readFileSync(
  resolve(process.cwd(), "src/components/sections/discovery-resources-section.tsx"),
  "utf8",
);

assert.match(source, /WebP posters/, "homepage showcase resource must use the maintained WebP poster format");
assert.match(
  source,
  /authentic production Radial Menu render/,
  "homepage showcase resource must identify the authentic production render",
);
assert.match(
  source,
  /deterministic product composites/,
  "homepage showcase resource must identify composite media",
);
assert.doesNotMatch(
  source,
  /PNG posters|rendered from CmdTab(?:’|')s actual SwiftUI\/AppKit switcher views/,
  "homepage showcase resource must not overstate media format or provenance",
);

console.log("Showcase discovery copy verification passed.");
