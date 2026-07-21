# Website SEO and GEO operating contract

CmdTab treats search and generative discovery as a maintained product surface, not a one-time metadata task.

## Canonical sources

- `src/content/public-routes.json` — public canonical HTML routes and reviewed modification dates.
- `src/content/product-facts.ts` — current version, system requirements, permissions, commercial facts, and telemetry contract.
- `src/content/feature-depth.ts` — factual Classic Grid, Command Palette, Radial Menu, and Quick Actions behavior, fit, tradeoffs, and adjacent sources.
- `src/content/faq.ts` — visible factual answers used by the canonical FAQ page and matching structured data.
- `src/content/evidence.ts` — automated evidence, public QA artifacts, model interpretation, and manual validation boundary.
- `src/content/market-landscape.ts` — source-dated first-party market facts and comparison methodology.
- `src/content/alttab-comparison.ts` — focused, source-dated AltTab facts, adoption context, and fair decision guidance.
- `src/lib/structured-data.ts` — entity, software, webpage, article, citation, FAQ, offer, permission, and breadcrumb markup.
- `scripts/verify-seo.mjs` — source and source-of-truth invariants.
- `scripts/verify-rendered-site.py` — compiled route, metadata, schema, link, crawler, and header verification.
- `scripts/verify-retrieval-surfaces.mjs` — rendered entity disambiguation, deep-page purpose, `llms.txt`, `llms-full.txt`, and sitemap-boundary verification.
- `scripts/verify-webmaster-metadata.mjs` — rendered Google and Bing ownership-meta verification.
- `scripts/verify-public-evidence.mjs` — byte-for-byte public QA artifact verification.
- `scripts/verify-browser.mjs` — desktop, mobile, navigation, table, image, console, network, and demo verification.

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
npm run browser:check
```

## Entity and brand disambiguation

- Visible homepage copy and SoftwareApplication schema must identify CmdTab as a standalone macOS window-switcher application.
- CmdTab must be distinguished from Apple’s built-in Command-Tab shortcut.
- Page titles and descriptions should use `CmdTab macOS window switcher`, `CmdTab window switcher`, or another clear product phrase when ambiguity is likely.
- Entity clarification must remain visible in canonical HTML; structured data cannot carry a materially different or stronger claim.

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
- include one H1, visible breadcrumbs, WebPage schema, a maintained screenshot, and a named keyboard-scrollable behavior table;
- describe best fit plus tradeoffs and limits;
- link to evidence, privacy, permissions, or adjacent modes as appropriate;
- avoid duplicating another page merely to target a keyword variation.

## Public evidence rules

- `/evidence` must separate automated evidence from real-macOS manual acceptance.
- Public model counts must be labelled as synthetic state-space evidence, not observed field failure rates.
- Files under `public/evidence/` must remain byte-identical to their canonical `docs/qa/` sources.
- Evidence links must return HTTP 200, non-HTML content, and exact canonical bytes from the compiled server.
- A green CI badge must never be described as proof of permissions, Spaces, displays, focused `CGWindowID`, signing, or other real-desktop states that were not executed.

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

`/llms.txt` is a descriptive directory to canonical product, feature, evidence, comparison, compatibility, permission, privacy, and changelog sources.

`/llms-full.txt` is an optional consolidated Markdown context export with these constraints:

- it is explicitly described as a non-standard convenience export;
- canonical HTML remains authoritative;
- it returns `X-Robots-Tag: noindex, follow`;
- it is excluded from the canonical HTML route registry and XML sitemap;
- it must not contain unique product claims;
- it must state unsupported-spec and real-desktop validation boundaries.

Neither file may be described as an AI-search ranking requirement. Ordinary crawlability, indexability, useful canonical content, internal links, evidence, and external authority remain the operative discovery foundations.

## Unsupported technical claims

Do not publish or add to structured data without reproducible evidence:

- ScreenCaptureKit implementation;
- RAM or memory-footprint figures;
- sub-50 ms or other fixed reveal/render latency figures;
- Universal Binary status;
- Apple Silicon, Intel, or processor coverage;
- processor or memory requirements;
- benchmark-derived superiority.

Current source uses CoreGraphics, Accessibility APIs, and a WindowServer/SkyLight capture path. A different API or performance claim requires an implementation change plus measured validation before publication.

## Off-page distribution rules

`../docs/seo/software-directory-submission-pack.md` is the maintained preparation source for AlternativeTo, Product Hunt, MacUpdate, Softpedia, and StackShare.

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

The sitemap and IndexNow payload share the canonical public-route registry. `llms.txt` describes those pages but may also link noindex helper and evidence files. Do not submit private, API, preview, helper-file, or unchanged duplicate URLs.

## Measurement boundaries

The first-party pageview tracker classifies broad discovery sources such as ChatGPT, Perplexity, Copilot, Gemini, Claude, Google, and Bing. It does not collect prompt or search-query text. Referral classification is directional because browsers, privacy tools, redirectors, copied links, and in-app browsers can remove or alter referrer information.

Use Search Console, Bing Webmaster Tools, `/dashboard/discovery`, Vercel Analytics, trial starts, purchases, and support outcomes together. Citation screenshots alone are not a GEO KPI.

## Content rules

- Keep every public claim visible in canonical HTML.
- Keep structured data consistent with visible content.
- Link external platform and competitor claims to primary sources.
- Publish real version and compatibility facts; do not invent processor coverage, benchmarks, ratings, testimonials, or directory status.
- Keep product claims aligned with protected Swift regressions and explicit manual-test boundaries.
- Date factual comparisons and review them when either product changes.
- Keep the consolidated retrieval export subordinate to canonical HTML.
