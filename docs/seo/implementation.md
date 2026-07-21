# CmdTab SEO, GEO, and showcase implementation

**Reviewed:** 2026-07-22

CmdTab uses one canonical public-route registry for sitemap generation, IndexNow submission, metadata verification, and browser checks. Public claims are kept narrower than the available evidence.

## Current public architecture

The site includes 22 canonical HTML routes covering the product, feature modes, evidence, comparisons, compatibility, permissions, privacy, commerce, help, and the product showcase.

Every maintained public page provides complete metadata, one H1, visible breadcrumbs, matching structured data, and factual visible content. Dashboard and API surfaces remain noindex.

## Product showcase

`/showcase` publishes a hybrid privacy-safe media set:

- authentic production SwiftUI/AppKit Radial Menu poster and MP4;
- deterministic product-composite overview and Quick Actions poster/MP4;
- deterministic product-composite Classic Grid and Command Palette posters.

The page visibly identifies each source. All media uses controlled fixtures, is not AI-generated, and is not a private desktop recording. Poster-only items use an image fallback rather than requesting nonexistent videos.

`VideoObject` data is generated only for assets with real MP4 files. `SoftwareApplication` screenshot URLs use the maintained WebP posters. Raw video files do not enter the canonical HTML sitemap.

## Discovery and evidence

- `/llms.txt` is a descriptive directory to canonical sources.
- `/llms-full.txt` is a non-standard noindex convenience export; canonical HTML is authoritative.
- `/evidence` separates automated proof from real-macOS manual acceptance.
- Comparison pages use dated first-party sources and treat missing claims as unknown.
- Unsupported ScreenCaptureKit, latency, RAM, Universal Binary, Apple Silicon, Intel, processor, and memory claims remain prohibited without reproducible evidence.

The uploaded review informed brand disambiguation, feature depth, comparison intent, and retrieval structure, but unsupported quantitative and architecture claims were rejected.

## Required checks

From `website/`:

```bash
npm ci
npm run prebuild
npm run build
```

The Vercel prebuild gate runs the production dependency audit, source SEO/media checks, and TypeScript. The permanent SEO workflow additionally runs:

```bash
npm run rendered:check
npm run webmaster:check
npm run evidence:check
npm run retrieval:check
npm run showcase:responses
npm run browser:check
```

## Production release rule

A READY deployment is not sufficient if it points to the wrong branch. Production is accepted only when the deployment metadata identifies the reviewed `main` commit and the public domain serves `/showcase`, every referenced media asset, the 22-route sitemap, and the unsupported-claim safeguards.
