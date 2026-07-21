# Website SEO and GEO operating contract

CmdTab treats search and generative discovery as a maintained product surface.

## Canonical sources

- `src/content/public-routes.json` — canonical HTML routes and modification dates.
- `src/content/product-facts.ts` — version, compatibility, permissions, commercial facts, and telemetry.
- `src/content/showcase.ts` — maintained media URLs, optional video state, descriptions, and provenance.
- `public/showcase/manifest.json` — media dimensions, durations, frame rate, source type, and fixture policy.
- `scripts/verify-showcase-media.mjs` — file and source-contract verification.
- `scripts/verify-showcase-responses.mjs` — compiled route and media-response verification.

## Showcase contract

The canonical page is `/showcase`.

- Radial Menu is an authentic production SwiftUI/AppKit render.
- Overview, Quick Actions, Classic Grid, and Command Palette are visibly labelled deterministic product composites.
- Every item has a WebP poster.
- Only overview, Radial Menu, and Quick Actions currently have MP4 loops.
- Poster-only items must render an image fallback and must not advertise missing videos.
- All media uses controlled fixture windows, is not AI-generated, and is not a private desktop capture.
- VideoObject data is emitted only for actual MP4s.
- Raw media is excluded from the HTML sitemap.

The showcase is presentation evidence, not proof of signed-app permissions, focused-window activation, Spaces, displays, fullscreen, signing, notarization, performance, memory use, processor support, or architecture coverage.

## Search and retrieval rules

- Visible HTML is authoritative.
- `llms.txt` is a directory, not a ranking mechanism.
- `llms-full.txt` is a non-standard noindex convenience export.
- Comparisons use first-party sources, visible review dates, and fair decision guidance.
- Missing competitor information is unknown, not proof of absence.
- Do not publish fake ratings, testimonials, listings, benchmarks, processor coverage, or unsupported compatibility claims.
- Do not publish ScreenCaptureKit, sub-50 ms, RAM, Universal Binary, Apple Silicon, or Intel claims without reproducible release evidence.

## Release checks

```bash
npm ci
npm run prebuild
npm run build
npm run rendered:check
npm run webmaster:check
npm run evidence:check
npm run retrieval:check
npm run showcase:responses
npm run browser:check
```

Production is accepted only when Vercel identifies the reviewed `main` commit and `cmdtab.net` serves every canonical page and referenced media file successfully.
