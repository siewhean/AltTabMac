# CmdTab real app showcase media implementation plan

**Date:** 2026-07-21  
**Branch:** `agent/real-app-showcase-media`

## Goal

Create authentic, reproducible images and short silent videos of the CmdTab switcher, then publish them as a fast, accessible website showcase.

The assets must be rendered from the production SwiftUI/AppKit switcher views. They must not be AI-generated, must not contain personal desktop data, and must not be described as live user screen recordings when they use controlled fixture windows.

## Truth boundary

The planned media is:

- a real render of the production `ClassicGridView`, `CommandPaletteView`, and `RadialMenuView` implementations;
- driven by the production `SwitcherViewModel`, `PaletteSearch`, layout metrics, selection animation, item mutation transition, and exact-window item model;
- populated with deterministic fixture windows and system application icons so the build is reproducible and contains no private information;
- encoded from rendered frames into silent H.264 MP4 loops;
- accompanied by captions explaining that controlled fixture windows are used.

The planned media is not:

- a recording of an actual user's desktop;
- proof that permissions, Spaces, fullscreen activation, multi-display behavior, or exact focus succeeded on a real signed installation;
- an AI-generated approximation of the interface;
- evidence for unmeasured latency, memory, processor, architecture, or reliability claims.

## Phase 1 — Capture harness

1. Add a `--render-showcase <output-directory>` command-line mode to the existing CmdTab executable.
2. Keep normal app startup unchanged when the flag is absent.
3. Render production switcher views inside a deterministic desktop fixture.
4. Build fixture window previews with AppKit drawing and use installed system app icons where available.
5. Capture frames through AppKit view caching into bitmap images.
6. Encode silent H.264 MP4 directly with AVFoundation so the workflow does not depend on an external video service.
7. Produce:
   - Classic Grid poster and loop;
   - Command Palette poster and loop;
   - Radial Menu poster and loop;
   - Quick Actions poster and loop showing a selected target being removed, with an explanatory capture-only key annotation;
   - a combined overview loop;
   - a contact sheet for editorial and directory use;
   - a machine-readable manifest with dimensions, duration, frame rate, source type, and disclosure text.

## Phase 2 — One-time media generation

1. Run the renderer on a GitHub-hosted macOS runner.
2. Validate each PNG using `sips` and each MP4 using AVFoundation metadata checks.
3. Reject files with the wrong dimensions, duration, frame count, empty content, audio tracks, or excessive size.
4. Commit only the final media and manifest to `website/public/showcase/`.
5. Upload the complete generated package as workflow evidence.
6. Remove or disable the one-time generation workflow after the durable assets are committed.

## Phase 3 — Website showcase

1. Add `/showcase` as a canonical public page with a prominent overview video.
2. Add a reusable, accessible video component with:
   - poster image;
   - stable MP4 source;
   - muted inline looping playback;
   - explicit play/pause control;
   - reduced-motion default pause;
   - descriptive text transcript;
   - no reliance on user interaction for the `<video>` element to exist in rendered HTML.
3. Add mode-specific clips below the overview.
4. Add a compact homepage showcase section linking to the full page.
5. Replace selected synthetic website illustrations only where the real product render is clearer; retain diagrams when they explain concepts rather than claim to be screenshots.
6. Link the showcase from feature pages, navigation, footer, `llms.txt`, and `llms-full.txt`.

## Phase 4 — Video discovery and structured data

1. Add visible upload/review context and unique descriptions.
2. Add `VideoObject` structured data for the overview and mode clips using stable poster and MP4 URLs.
3. Keep structured data identical to visible captions and manifest facts.
4. Add `/showcase` to the canonical route registry, sitemap, IndexNow source, and rendered verification.
5. Do not add the raw MP4 files as canonical HTML routes.

## Phase 5 — Regression gates

The permanent website suite must verify:

- the showcase route has one H1, complete metadata, breadcrumbs, WebPage schema, and VideoObject schema;
- every poster and MP4 returns HTTP 200 at a stable URL;
- MP4 responses use an appropriate video content type and support byte ranges where the host provides them;
- the video elements are present in rendered HTML with poster, muted, playsinline, and preload metadata;
- every video has visible descriptive text;
- reduced-motion behavior does not force playback;
- desktop and mobile layouts do not overflow;
- no broken media, console exceptions, or unexplained network failures occur;
- fixture-media disclosures remain visible;
- no unsupported performance or hardware claims enter the media manifest or page.

## Planned asset profile

| Asset | Target size | Target duration | Purpose |
|---|---:|---:|---|
| Overview poster | 1280×800 PNG | — | Main showcase poster and social/editorial reuse |
| Overview loop | 1280×800 MP4 | 8–12 seconds | Three-mode product overview |
| Classic Grid poster/loop | 1280×800 | 5–7 seconds | Visual exact-window selection |
| Command Palette poster/loop | 1280×800 | 5–7 seconds | Local filtering and result selection |
| Radial Menu poster/loop | 1280×800 | 5–7 seconds | Directional selection |
| Quick Actions poster/loop | 1280×800 | 4–6 seconds | Selected-item mutation after an action |
| Contact sheet | 1600×1000 PNG | — | Press, directory, and review preparation |

## Release boundary

Merge only after:

- the macOS renderer produces valid non-empty assets;
- the final media is visually inspected from the workflow artifact;
- Swift tests remain green;
- website Security and SEO/GEO workflows pass;
- rendered and browser verification passes on all canonical routes;
- the Vercel preview is READY or an equivalent compiled production-server verification is green.

Production promotion and IndexNow submission happen only after the public domain serves the new assets and showcase page.