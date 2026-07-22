#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const read = (path) => readFileSync(resolve(process.cwd(), path), "utf8");
const discovery = read("src/components/sections/discovery-resources-section.tsx");
const hero = read("src/components/sections/hero-section.tsx");
const realShowcase = read("src/components/sections/real-showcase-section.tsx");
const showcase = read("src/content/showcase.ts");

for (const [name, source] of [
  ["homepage discovery", discovery],
  ["homepage hero", hero],
  ["homepage showcase section", realShowcase],
  ["showcase contract", showcase],
]) {
  assert.match(source, /HD|1920/i, `${name} must identify the sharp HD media contract`);
  assert.doesNotMatch(
    source,
    /authentic production Radial Menu render|production-swiftui-render|rendered from CmdTab(?:’|')s actual SwiftUI\/AppKit switcher views/i,
    `${name} must not retain the old production-render provenance claim`,
  );
}

assert.match(discovery, /1920 × 1200|1920x1200/i, "homepage showcase resource must state the HD resolution");
assert.match(discovery, /30 fps/i, "homepage showcase resource must state the motion frame rate");
assert.match(showcase, /deterministic HD product composite/i, "showcase contract must identify deterministic HD composites");
assert.match(showcase, /not AI-generated/i, "showcase contract must preserve the non-AI boundary");
assert.match(showcase, /controlled fixture windows/i, "showcase contract must preserve the fixture boundary");
assert.doesNotMatch(
  `${discovery}\n${hero}\n${realShowcase}\n${showcase}`,
  /PNG posters|480 × 300|480x300|720 × 450|800 × 500/,
  "showcase copy must not advertise obsolete low-resolution media",
);

console.log("HD showcase discovery copy verification passed.");
