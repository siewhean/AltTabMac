# Website SEO and GEO operating contract

CmdTab treats search and generative discovery as a maintained product surface, not a one-time metadata task.

## Canonical sources

- `src/content/public-routes.json` — public canonical routes and reviewed modification dates.
- `src/content/product-facts.ts` — current version, system requirements, permissions, commercial facts, and telemetry contract.
- `src/content/faq.ts` — visible factual answers used by the canonical FAQ page and matching structured data.
- `src/content/evidence.ts` — automated evidence, public QA artifacts, model interpretation, and manual validation boundary.
- `src/content/market-landscape.ts` — source-dated first-party competitor facts and comparison methodology.
- `src/lib/structured-data.ts` — entity, software, webpage, article, citation, FAQ, offer, and breadcrumb markup.
- `scripts/verify-seo.mjs` — source and source-of-truth invariants.
- `scripts/verify-rendered-site.py` — compiled route, metadata, schema, link, crawler, and header verification.
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
npm run browser:check
```

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
- Recheck prices, feature tiers, compatibility, download counts, and telemetry claims before changing the review date.
- Explain who each option may suit instead of manufacturing a universal winner.
- Keep structured `citation` values aligned with visible source links.
- Do not publish fake reviews, ratings, benchmarks, testimonials, or unsupported platform claims.

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

The sitemap, IndexNow payload, and `llms.txt` directory share the same route registry. Do not submit private, API, preview, or unchanged duplicate URLs.

## Measurement boundaries

The first-party pageview tracker classifies broad discovery sources such as ChatGPT, Perplexity, Copilot, Gemini, Claude, Google, and Bing. It does not collect prompt or search-query text. Referral classification is directional because browsers, privacy tools, redirectors, copied links, and in-app browsers can remove or alter referrer information.

Use Search Console, Bing Webmaster Tools, `/dashboard/discovery`, Vercel Analytics, trial starts, purchases, and support outcomes together. Citation screenshots alone are not a GEO KPI.

## Content rules

- Keep every public claim visible in canonical HTML.
- Keep structured data consistent with visible content.
- Link external platform and competitor claims to primary sources.
- Publish real version and compatibility facts; do not invent processor coverage, benchmarks, ratings, or testimonials.
- Keep product claims aligned with protected Swift regressions and explicit manual-test boundaries.
- Date factual comparisons and review them when either product changes.
- Keep `llms.txt` canonical-only; it must not contain unique claims.
