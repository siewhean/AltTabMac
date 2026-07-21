# Website SEO and GEO operating contract

CmdTab treats search and generative discovery as a maintained product surface, not a one-time metadata task.

## Canonical sources

- `src/content/public-routes.json` — public canonical HTML routes and reviewed modification dates.
- `src/content/product-facts.ts` — current version, system requirements, permissions, commercial facts, and telemetry contract.
- `src/content/showcase.ts` — stable poster/video URLs, durations, transcripts, review date, source disclosure, and signed-app validation boundary.
- `public/showcase/manifest.json` — generated media dimensions, frame rate, duration, codec, audio state, byte counts, source type, and fixture policy.
- `src/content/feature-depth.ts` — factual Classic Grid, Command Palette, Radial Menu, and Quick Actions behavior, fit, tradeoffs, and adjacent sources.
- `src/content/faq.ts` — visible factual answers used by the canonical FAQ page and matching structured data.
- `src/content/evidence.ts` — automated evidence, public QA artifacts, model interpretation, and manual validation boundary.
- `src/content/market-landscape.ts` — source-dated first-party market facts and comparison methodology.
- `src/content/alttab-comparison.ts` — focused, source-dated AltTab facts, adoption context, and fair decision guidance.
- `src/lib/structured-data.ts` — entity, software, webpage, article, citation, FAQ, offer, permission, VideoObject, and breadcrumb markup.
- `scripts/verify-seo.mjs` — source and source-of-truth invariants.
- `scripts/verify-showcase-media.mjs` — committed poster/MP4 signatures, dimensions, codec, audio, byte, manifest, disclosure, and source contracts.
- `scripts/verify-showcase-responses.mjs` — compiled watch page, VideoObject markup, media content types, response bytes, and range-response verification.
- `scripts/verify-rendered-site.py` — compiled route, metadata, schema, link, crawler, and header verification.
- `scripts/verify-retrieval-surfaces.mjs` — rendered entity disambiguation, real-media references, deep-page purpose, `llms.txt`, `llms-full.txt`, and sitemap-boundary verification.
- `scripts/verify-webmaster-metadata.mjs` — rendered Google and Bing ownership-meta verification.
- `scripts/verify-public-evidence.mjs` — byte-for-byte public QA artifact verification.
- `scripts/verify-browser.mjs` — desktop, mobile, navigation, table, image, media-request, console, network, and demo verification.

## Required release checks

Run from `website/`:

```bash
npm ci
npm run seo:check
npm run typecheck
npx next build --webpack
npm audit --omit=dev --audit-level=high
```

The permanent SEO/GEO workflow must also start the compiled server and pass:

```bash
npm run rendered:check
npm run webmaster:check
npm run evidence:check
npm run retrieval:check
npm run showcase:responses
npm run browser:check
```

## Entity and brand disambiguation

- Visible homepage copy and SoftwareApplication schema must identify CmdTab as a standalone macOS window-switcher application.
- CmdTab must be distinguished from Apple’s built-in Command-Tab shortcut.
- Page titles and descriptions should use `CmdTab macOS window switcher`, `CmdTab window switcher`, or another clear product phrase when ambiguity is likely.
- Entity clarification must remain visible in canonical HTML; structured data cannot carry a materially different or stronger claim.

## Real showcase media rules

The canonical watch page is `/showcase`. It exists to make real product presentation inspectable without exposing a developer’s private desktop.

- The switcher panels must be rendered from production SwiftUI/AppKit views and the production view model/search paths.
- Controlled fixture windows, generic titles, and system application icons are allowed to make capture deterministic and privacy-safe.
- The surrounding desktop, fixture contents, and Quick Action key badge are explanatory capture context and must be disclosed visibly.
- The media must not be described as an actual user desktop recording, end-to-end signed-app proof, or AI-generated imagery.
- PNG posters and silent H.264 MP4 loops must use stable URLs under `/showcase/`.
- `manifest.json` must describe dimensions, frame rate, duration, codec, audio state, bytes, source type, and fixture disclosure.
- The watch page must use native video elements with posters, muted inline playback, explicit play/pause controls, visible transcripts, and reduced-motion behavior.
- VideoObject structured data must match visible titles, descriptions, poster URLs, MP4 URLs, dates, durations, and dimensions.
- SoftwareApplication screenshots must use the real showcase posters rather than an unlabelled illustration.
- A controlled product render proves presentation code and deterministic state changes only. It does not prove Accessibility, Screen Recording, exact focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, signing, or notarization.
- Raw MP4 files and the noindex helper file are not canonical HTML routes and must not be added to the XML sitemap.

### Capture implementation rules

- `CmdTab --render-showcase <output-directory>` is the only supported renderer entry point.
- Normal application startup must remain unchanged when the flag is absent.
- Offscreen `ImageRenderer` capture may use eager equivalents for lazy grid/list containers only while `ShowcaseRenderingMode` is enabled. The same production item cards and rows must be used.
- The macOS validator must inspect central product-region variance so a decorative desktop cannot hide a blank switcher panel.
- The final assets must be visually inspected from the workflow artifact before merge.
- The one-time generation workflow and temporary write permission in Swift CI must be removed after durable assets are committed.

## Deep feature rules

Canonical deep references exist for:

```text
/features/classic-grid
/features/command-palette
/features/radial-menu
/features/quick-actions
```

Each feature page must:

- answer a distinct selection or window-management problem;
- state current behavior rather than an aspirational benchmark;
- include one H1, visible breadcrumbs, WebPage schema, a real maintained poster/video, and a named keyboard-scrollable behavior table;
- describe best fit plus tradeoffs and limits;
- link to the full showcase, evidence, privacy, permissions, or adjacent modes as appropriate;
- avoid duplicating another page merely to target a keyword variation.

## Public evidence rules

- `/evidence` must separate automated evidence from real-macOS manual acceptance.
- Public model counts must be labelled as synthetic state-space evidence, not observed field failure rates.
- Files under `public/evidence/` must remain byte-identical to their canonical `docs/qa/` sources.
- Evidence links must return HTTP 200, non-HTML content, and exact canonical bytes from the compiled server.
- A green CI badge or showcase clip must never be described as proof of permissions, Spaces, displays, focused `CGWindowID`, signing, or other real-desktop states that were not executed.

## Comparison rules

- Use first-party product sources or platform-owner documentation.
- Display the review date and comparison method visibly.
- Treat missing information as unknown, not as proof that a feature is absent.
- Recheck prices, feature tiers, compatibility, download counts, adoption figures, and telemetry claims before changing the review date.
- Adoption signals such as downloads or GitHub stars must not be presented as controlled reliability or performance measurements.
- Explain who each option may suit instead of manufacturing a universal winner.
- Keep structured `citation` values aligned with visible source links.
- Keep focused comparisons under the established `/compare/` architecture and add one only when it answers a materially distinct decision.
- Do not publish fake reviews, ratings, benchmarks, testimonials, or unsupported platform claims.

## Retrieval-oriented files

`/llms.txt` is a descriptive directory to canonical product, showcase, feature, evidence, comparison, compatibility, permission, privacy, and changelog sources.

`/llms-full.txt` is an optional consolidated Markdown context export with these constraints:

- it is explicitly described as a non-standard convenience export;
- canonical HTML remains authoritative;
- it returns `X-Robots-Tag: noindex, follow`;
- it is excluded from the canonical HTML route registry and XML sitemap;
- it must not contain unique product claims;
- it must describe the real-media source, controlled fixture boundary, unsupported-spec boundary, and real-desktop validation boundary.

Neither file may be described as an AI-search ranking requirement. Ordinary crawlability, indexability, useful canonical content, internal links, evidence, and external authority remain the operative discovery foundations.

## Unsupported technical claims

Do not publish or add to structured data or showcase overlays without reproducible evidence:

- ScreenCaptureKit implementation;
- RAM or memory-footprint figures;
- sub-50 ms or other fixed reveal/render latency figures;
- Universal Binary status;
- Apple Silicon, Intel, or processor coverage;
- processor or memory requirements;
- benchmark-derived superiority.

Current source uses CoreGraphics, Accessibility APIs, and a WindowServer/SkyLight capture path. A different API or performance claim requires an implementation change plus measured validation before publication.

## Off-page distribution rules

`../docs/seo/software-directory-submission-pack.md` is the maintained preparation source for AlternativeTo, Product Hunt, MacUpdate, Softpedia, and StackShare. The validated showcase contact sheet and stable posters may be referenced after the public release is deployed.

- A prepared row is not a submission, approval, review, or indexed listing.
- Every external listing status remains `Not submitted` until an owner-account action occurs and its URL/date are recorded.
- Do not submit a downloadable-product listing before the signed, notarized release and direct trial/download flow are ready where the destination requires them.
- Do not manufacture community discussion, votes, testimonials, accounts, alternative relationships, or reviews.

## Webmaster verification

The root layout supports:

```text
GOOGLE_SITE_VERIFICATION
BING_SITE_VERIFICATION
```

Google uses the standard `google-site-verification` metadata field. Bing uses `msvalidate.01`. The SEO workflow supplies deterministic CI tokens and verifies their rendered HTML after the production build.

Adding code support does not verify the domain. Owner-account verification, sitemap submission, URL inspection, and platform reporting remain account operations.

## Publishing changed URLs

After deploying changed canonical pages and confirming the public IndexNow ownership key:

```bash
npm run indexnow:submit
```

The sitemap and IndexNow payload share the canonical public-route registry. `llms.txt` describes those pages but may also link noindex helper, raw media, manifest, and evidence files. Do not submit private, API, preview, helper-file, raw-media, or unchanged duplicate URLs.

## Controlled deployment retries

- A Git-integration build-rate rejection is not a production deployment and must not be reported as live.
- A framework deployment may consume multiple build units because generated Functions can count separately; consult the provider’s current limits before retriggering.
- Wait for the provider’s rolling build window to clear, then trigger one audited main-branch deployment retry rather than creating a burst of empty commits.
- A later READY preview of the same tree does not repair an earlier failed main-commit deployment status; trigger one fresh audited main commit after capacity returns.
- A READY preview can validate the website build, but it does not replace the production-domain check or public alias.
- Run the full public-domain crawler, browser, evidence-byte, retrieval, showcase-response, and runtime-error checks after the production alias changes.
- Submit IndexNow only after the changed canonical URLs are publicly deployed.

## Measurement boundaries

The first-party pageview tracker classifies broad discovery sources such as ChatGPT, Perplexity, Copilot, Gemini, Claude, Google, and Bing. It does not collect prompt or search-query text. Referral classification is directional because browsers, privacy tools, redirectors, copied links, and in-app browsers can remove or alter referrer information.

Use Search Console, Bing Webmaster Tools, `/dashboard/discovery`, Vercel Analytics, trial starts, purchases, support outcomes, and showcase engagement together. Citation screenshots or video-rich-result eligibility alone are not a GEO KPI.

## Content rules

- Keep every public claim visible in canonical HTML.
- Keep structured data consistent with visible content and the generated media manifest.
- Link external platform and competitor claims to primary sources.
- Publish real version and compatibility facts; do not invent processor coverage, benchmarks, ratings, testimonials, or directory status.
- Keep product and media claims aligned with protected Swift regressions and explicit manual-test boundaries.
- Date factual comparisons and review them when either product changes.
- Keep the consolidated retrieval export subordinate to canonical HTML.
