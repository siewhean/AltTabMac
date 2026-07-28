#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const read = (path) => readFileSync(resolve(process.cwd(), path), "utf8");
const homePage = read("src/app/page.tsx");
const hero = read("src/components/sections/hero-section.tsx");
const showcasePage = read("src/app/showcase/page.tsx");
const showcase = read("src/content/showcase.ts");
const player = read("src/components/showcase/showcase-video.tsx");
const generator = read("scripts/generate-hd-showcase-media.mjs");

assert.match(hero, /ShowcaseVideo/, "homepage hero must keep the autoplay product demonstration");
assert.match(hero, /ShowcaseVideo[\s\S]*loopPlayback/, "homepage hero video must opt into looping playback");
assert.match(hero, /showOverlay=\{false\}/, "homepage hero must hide the overview text overlay");
assert.match(showcasePage, /CmdTab in motion/, "showcase page must use the simplified visible heading");
assert.doesNotMatch(
  homePage,
  /RealShowcaseSection|WalkthroughSection|ProductFactsSection|DiscoveryResourcesSection|FaqSection/,
  "homepage must not restore the removed long-form sections",
);
assert.doesNotMatch(
  `${homePage}\n${hero}\n${showcasePage}`,
  /What is shown|Read the media description|Resolution<|Format<|Source/,
  "visible marketing pages must not restore removed explanatory clutter",
);
assert.match(showcase, /deterministic HD product composite/i, "showcase contract must identify deterministic HD composites");
assert.match(showcase, /not AI-generated/i, "showcase contract must preserve the non-AI boundary");
assert.match(showcase, /controlled fixture windows/i, "showcase contract must preserve the fixture boundary");
assert.match(showcase, /homepage hero overview loops while visible/i, "showcase contract must state the hero loop boundary");
assert.match(showcase, /showcase-page autoplay clips run once for no more than five seconds/i, "showcase contract must state the one-shot showcase boundary");
assert.match(showcase, /prefer reduced motion/i, "showcase contract must state the reduced-motion boundary");
assert.match(player, /loopPlayback = false/, "showcase player must default to one-shot playback");
assert.match(player, /showOverlay = true/, "showcase player must keep overlays by default outside the hero");
assert.match(player, /\{showOverlay \? \(/, "showcase player must conditionally render its visible title overlay");
assert.match(player, /loop=\{loopPlayback\}/, "showcase player must apply the native loop attribute only when requested");
assert.match(
  player,
  /data-autoplay-mode=\{loopPlayback \? "loop" : "one-shot"\}/,
  "showcase player must expose its selected autoplay mode",
);
assert.match(player, /if \(!loopPlayback\) hasCompletedRef\.current = true/, "one-shot players must freeze after completion");

// These assertions protect both text layers: the React overlay and the labels burned into generated frames.
assert.doesNotMatch(
  generator,
  /⌘\s*W|Command-W|Close selected window|QUICK ACTION/,
  "generated showcase frames must not contain the removed central shortcut badge",
);
assert.doesNotMatch(
  showcase,
  /Command-W badge|Command-W annotation/,
  "showcase descriptions must not claim the removed shortcut badge is visible",
);
assert.doesNotMatch(
  `${hero}\n${showcasePage}\n${showcase}`,
  /authentic production Radial Menu render|production-swiftui-render|rendered from CmdTab(?:’|')s actual SwiftUI\/AppKit switcher views/i,
  "marketing copy must not retain the old production-render provenance claim",
);
assert.doesNotMatch(
  `${hero}\n${showcasePage}\n${showcase}`,
  /PNG posters|480 × 300|480x300|720 × 450|800 × 500/,
  "showcase copy must not advertise obsolete low-resolution media",
);

console.log("Clean hero overlay, hero loop, and one-shot showcase autoplay verification passed.");
