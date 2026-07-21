# CmdTab SEO/GEO feedback implementation plan

**Prepared:** 2026-07-21  
**Input reviewed:** `seo_geo_review(1).md`  
**Target:** `cmdtab.net`

## Decision standard

The review is directionally useful, but recommendations are accepted only when they are:

1. supported by the current CmdTab source or a first-party external source;
2. useful to a human visitor, not merely a crawler-facing variation;
3. materially distinct from an existing canonical page;
4. maintainable through the current route registry and verification suite;
5. free of invented benchmark, compatibility, architecture, or adoption claims.

## Fact-check conclusions

### Accepted

- Strengthen the product entity as **CmdTab, a standalone macOS window-switcher application**, so it is not confused with Apple’s built-in Command-Tab shortcut.
- Add deep, distinct pages for Classic Grid, Command Palette, Radial Menu, and Quick Actions.
- Add one focused AltTab comparison because the user intent is sufficiently different from the existing market landscape.
- Expand the current `llms.txt` with clearer resource descriptions and an optional consolidated context export.
- Prepare a consistent, source-backed software-directory submission pack for owner-operated listings.

### Modified

- Keep comparisons under the existing `/compare/` hierarchy instead of adding duplicate `/vs/` routes. The site already has `/compare/cmdtab-vs-macos-command-tab` and `/compare/mac-window-switchers`; new comparison pages must add unique decision value.
- Add Contexts to the source-dated market landscape rather than creating a thin standalone page in this phase.
- Publish `/llms-full.txt` only as a **non-standard convenience export**. Canonical HTML remains authoritative.

### Rejected or deferred

- Do not claim that ChatGPT, Claude, Perplexity, or Google require `llms-full.txt`. The llms.txt project describes an open proposal, and Google explicitly states that no special AI text file is required for AI search features.
- Do not publish ScreenCaptureKit claims. The current implementation imports CoreGraphics and ApplicationServices and uses SkyLight/WindowServer capture plus Accessibility APIs; no ScreenCaptureKit implementation is present.
- Do not publish `<15 MB` or `<20 MB` memory usage, sub-50 ms thumbnail rendering, Universal Binary support, Apple Silicon/Intel support, or processor requirements until a reproducible build or real-machine measurement proves each statement.
- Do not claim that Contexts is dormant or slowly maintained. Its current first-party page advertises Contexts 3.9, macOS Ventura/Sonoma/Sequoia support, a free trial, and a US$9.99 license.
- Do not create multiple near-duplicate comparison pages merely to target keyword variants. Duplicate or substantially similar landing pages dilute canonical signals and provide little user value.

## Implementation phases

### Phase 1 — Entity disambiguation

- Update the site description and home definition to state that CmdTab is a standalone macOS application, not Apple’s built-in Command-Tab shortcut.
- Add an accurate `disambiguatingDescription` and explicit permission text to the SoftwareApplication entity.
- Keep the visible page text and structured data aligned.

### Phase 2 — Retrieval-oriented documentation

- Expand `/llms.txt` with descriptive links rather than a flat URL dump.
- Add `/llms-full.txt` as a generated Markdown context export containing current product facts, behavior, modes, evidence, privacy boundaries, comparisons, and source rules.
- Mark the consolidated export as non-standard and keep it out of the canonical HTML route registry and sitemap.
- Add an `X-Robots-Tag: noindex, follow` response header so the helper file does not compete with human-facing pages in search results.

### Phase 3 — Distinct feature and comparison depth

Create:

- `/features/classic-grid`
- `/features/command-palette`
- `/features/radial-menu`
- `/features/quick-actions`
- `/compare/cmdtab-vs-alttab`

Each page must include:

- unique title, description, H1, and user intent;
- visible breadcrumbs and matching structured data;
- current behavior, best-fit use cases, tradeoffs, and limitations;
- links to evidence, privacy/permissions, and adjacent modes;
- no unsupported performance, processor, memory, or compatibility claims.

Add Contexts to `/compare/mac-window-switchers` using its first-party product page and current public commercial/system facts.

### Phase 4 — Off-page distribution readiness

- Create `docs/seo/software-directory-submission-pack.md` with one maintained source for product descriptions, categories, URLs, screenshots, version, price, trial, permissions, privacy, and evidence.
- Include a status checklist for AlternativeTo, Product Hunt, MacUpdate, Softpedia, and StackShare.
- Leave all listings as owner-account actions until an authenticated account is available; do not claim submission or approval before it happens.

### Phase 5 — Regression and release gates

Extend permanent checks to require:

- every new route in the canonical registry and sitemap;
- unique metadata and one H1 per page;
- brand disambiguation in visible HTML and structured data;
- an accurate, noindex consolidated context export;
- feature-page internal links and screenshots;
- source-dated AltTab and Contexts claims;
- accessible comparison tables;
- desktop and mobile browser coverage for all public routes;
- rendered crawler-file and response-header verification.

## Acceptance criteria

The phase is complete only when:

1. source SEO checks pass;
2. TypeScript passes;
3. the production Next.js build passes;
4. rendered metadata/schema/link/header checks pass;
5. desktop and mobile browser checks pass for every maintained route;
6. the Security workflow passes;
7. the Vercel preview is READY with no build error;
8. the PR clearly records which review recommendations were accepted, modified, rejected, or deferred.

## Primary references

- Google Search Central, AI features and your website: https://developers.google.com/search/docs/appearance/ai-features
- OpenAI publisher and developer FAQ: https://help.openai.com/en/articles/12627856-publishers-and-developers-faq
- llms.txt proposal: https://llmstxt.org/
- Google SoftwareApplication structured data: https://developers.google.com/search/docs/appearance/structured-data/software-app
- Schema.org SoftwareApplication: https://schema.org/SoftwareApplication
- AltTab official pricing: https://alt-tab.app/pricing
- Contexts official product page: https://contexts.co/
