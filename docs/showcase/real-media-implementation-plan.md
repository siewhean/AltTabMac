# CmdTab real app showcase media implementation plan

**Date:** 2026-07-21  
**Branch:** `agent/real-app-showcase-media`  
**Draft PR:** `#20`

## Goal

Create authentic, reproducible images and short silent videos of the CmdTab switcher, then publish them as a fast, accessible website showcase.

The assets must be rendered from the production SwiftUI/AppKit switcher views. They must not be AI-generated, must not contain personal desktop data, and must not be described as live user screen recordings when they use controlled fixture windows.

## Truth boundary

The media is designed to be:

- a real render of production `ClassicGridView`, `CommandPaletteView`, and `RadialMenuView` implementations;
- driven by production `SwitcherViewModel`, `PaletteSearch`, layout metrics, item cards, rows, selection styling, item mutation, and exact-window item models;
- populated with deterministic fixture windows and system application icons so the build is reproducible and contains no private information;
- encoded from rendered frames into silent H.264 MP4 loops;
- accompanied by captions explaining that controlled fixture windows are used.

The media is not:

- a recording of an actual user's desktop;
- proof that permissions, Spaces, fullscreen activation, multi-display behavior, or exact focus succeeded on a real signed installation;
- an AI-generated approximation of the interface;
- evidence for unmeasured latency, memory, processor, architecture, or reliability claims.

## Current status

### Completed source work

- Added `CmdTab --render-showcase <output-directory>` while preserving normal app startup when the flag is absent.
- Added deterministic fixture windows and system-app icon lookup.
- Added production-view rendering for Classic Grid, Command Palette, Radial Menu, Quick Actions, and an overview.
- Added silent H.264 encoding with AVFoundation.
- Added poster, video, contact-sheet, manifest, and README outputs.
- Added macOS media validation for image dimensions, visual variance, central product-region variance, video duration, codec, audio absence, bytes, and disclosure.
- Added `/showcase`, homepage footage, feature-hub footage, mode-specific video embeds, stable transcripts, reduced-motion playback, and VideoObject structured data.
- Added stable media URLs to navigation, footer, social metadata, SoftwareApplication screenshots, `llms.txt`, `llms-full.txt`, and directory preparation.
- Added source and rendered media-response regression checks.

### Rejected first pass

The first macOS generation pass produced valid files and an authentic Radial Menu render, but Classic Grid, Command Palette, Quick Actions, and the overview contained blank central panels. SwiftUI `LazyVGrid` and `LazyVStack` did not instantiate their children under offscreen `ImageRenderer` capture.

Those files were rejected and were not committed to the website. The renderer now uses capture-only eager equivalents while reusing the same production Classic Grid item cards and Command Palette rows. Normal application rendering remains on the original lazy containers.

A new central product-region variance check would reject the original blank output even if the surrounding decorative desktop remains visually complex.

### Current blocker

GitHub-hosted workflows are currently failing before any workflow steps begin across Swift, Security, SEO/GEO, and the one-time render job. Retrying a failed macOS render job also failed before checkout. This prevents execution of the corrected renderer and generation of the final authentic multi-mode binary assets in the current connected environment.

The branch and PR must remain draft. No blank or partially invalid media may be merged merely to satisfy a delivery deadline.

## Phase 1 — Capture harness

1. Add a `--render-showcase <output-directory>` command-line mode to the existing CmdTab executable. **Complete**
2. Keep normal app startup unchanged when the flag is absent. **Complete**
3. Render production switcher views inside a deterministic desktop fixture. **Complete**
4. Build fixture window previews with AppKit/SwiftUI drawing and use installed system app icons where available. **Complete**
5. Capture production SwiftUI views with `ImageRenderer`; use eager capture-only containers where lazy containers cannot instantiate offscreen children. **Complete**
6. Encode silent H.264 MP4 directly with AVFoundation. **Complete**
7. Produce Classic Grid, Command Palette, Radial Menu, Quick Actions, overview, contact sheet, manifest, and README. **Source complete; final binary generation blocked**

## Phase 2 — One-time media generation

1. Run the corrected renderer on a macOS host. **Blocked by pre-step GitHub Actions failure**
2. Validate each PNG and MP4 through the macOS validator. **Validator complete; final run pending**
3. Reject wrong dimensions, durations, empty product content, audio tracks, excessive size, or missing disclosure. **Complete**
4. Visually inspect every poster and representative video frame. **Pending corrected output**
5. Commit only the final media and manifest to `website/public/showcase/`. **Pending**
6. Upload the complete generated package as workflow evidence. **Pending**
7. Remove temporary generation workflow/write permissions after the durable assets are committed. **Pending**

## Phase 3 — Website showcase

1. Add `/showcase` as a canonical public page with a prominent overview video. **Source complete**
2. Add a reusable accessible video component with poster, stable MP4, muted inline loop, explicit play/pause, reduced-motion pause, visible transcript, and server-rendered video markup. **Complete**
3. Add mode-specific clips below the overview. **Complete, awaiting binary assets**
4. Add the real overview poster to the homepage hero and an overview video lower on the homepage. **Complete, awaiting binary assets**
5. Replace selected synthetic feature images with real posters/videos where the real render is clearer. **Complete, awaiting binary assets**
6. Link the showcase from feature pages, navigation, footer, `llms.txt`, and `llms-full.txt`. **Complete**

## Phase 4 — Video discovery and structured data

1. Add visible upload/review context and unique descriptions. **Complete**
2. Add `VideoObject` structured data for the overview and mode clips. **Complete**
3. Keep structured data identical to visible captions and manifest facts. **Protected by source checks**
4. Add `/showcase` to the canonical route registry, sitemap, IndexNow source, and rendered verification. **Complete**
5. Keep raw MP4 files out of the canonical HTML route registry and sitemap. **Complete**

## Phase 5 — Regression gates

The website and macOS validators protect:

- one H1, complete metadata, breadcrumbs, WebPage schema, and VideoObject schema;
- stable poster, MP4, contact-sheet, and manifest paths;
- PNG signatures and dimensions;
- MP4 container metadata, H.264/avc1, no audio, byte counts, duration, and dimensions;
- HTTP content types, response bytes, and range responses where supported;
- native video elements with poster, muted, loop, playsinline, and MP4 sources;
- explicit play/pause controls;
- reduced-motion behavior;
- visible transcripts and fixture disclosures;
- desktop/mobile overflow, broken requests, console exceptions, and unnamed controls;
- absence of unsupported performance, architecture, memory, and ScreenCaptureKit claims;
- central product-region visual variance so decorative context cannot hide a blank switcher panel.

## Planned asset profile

| Asset | Target size | Target duration | Purpose |
|---|---:|---:|---|
| Overview poster | 1280×800 PNG | — | Homepage hero, watch page, social/editorial reuse |
| Overview loop | 1280×800 MP4 | about 8 seconds | Three-mode and Quick Action overview |
| Classic Grid poster/loop | 1280×800 | about 5.1 seconds | Visual exact-window selection |
| Command Palette poster/loop | 1280×800 | about 4.8 seconds | Local filtering and result selection |
| Radial Menu poster/loop | 1280×800 | about 4.8 seconds | Directional selection |
| Quick Actions poster/loop | 1280×800 | about 3.6 seconds | Selected-item mutation after an annotated action |
| Contact sheet | 1600×1100 PNG | — | Press, directory, and review preparation |

## Local macOS completion command

From the repository root on a Mac with Swift 5.10+ and AVFoundation/AppKit available:

```bash
rm -rf website/public/showcase
mkdir -p website/public/showcase
swift run \
  -c release \
  --scratch-path /tmp/CmdTab-showcase \
  CmdTab \
  --render-showcase "$PWD/website/public/showcase"
swift scripts/showcase/validate_showcase_media.swift "$PWD/website/public/showcase"
```

After validation, visually inspect every poster and at least the first, middle, and final frame of each MP4 before committing the directory.

## Release boundary

Merge only after:

- the corrected macOS renderer produces valid non-empty assets;
- the final media is visually inspected;
- Swift tests remain green;
- website Security and SEO/GEO workflows pass with committed media;
- rendered and browser verification passes on all 22 canonical routes;
- the Vercel preview or an equivalent compiled production-server verification is green;
- temporary generation write permissions are removed.

Production promotion and IndexNow submission happen only after the public domain serves the new assets and showcase page.