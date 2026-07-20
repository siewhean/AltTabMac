# Website SEO and GEO operating contract

CmdTab treats search and generative discovery as a maintained product surface, not a one-time metadata task.

## Canonical sources

- `src/content/public-routes.json` — public canonical routes and reviewed modification dates.
- `src/content/product-facts.ts` — current version, system requirement, permissions, commercial facts, and telemetry contract.
- `src/content/faq.ts` — visible factual answers used by the canonical FAQ page and matching structured data.
- `src/lib/structured-data.ts` — entity, software, webpage, article, FAQ, offer, and breadcrumb markup.
- `scripts/verify-seo.mjs` — build-breaking invariants.

## Required release checks

Run from `website/`:

```bash
npm ci
npm run seo:check
npm run typecheck
npx next build --webpack
npm audit --omit=dev --audit-level=high
```

## Publishing changed URLs

After deploying changed canonical pages and configuring `INDEXNOW_KEY`:

```bash
npm run indexnow:submit
```

The sitemap, IndexNow payload, and `llms.txt` directory share the same route registry.

## Measurement boundaries

The first-party pageview tracker classifies broad discovery sources such as ChatGPT, Perplexity, Copilot, Gemini, Claude, Google, and Bing. It does not collect prompt or search-query text. Referral classification is directional because browsers, privacy tools, redirectors, and copied links can remove referrer information.

## Content rules

- Keep every public claim visible in canonical HTML.
- Keep structured data consistent with visible content.
- Link external platform claims to primary sources.
- Publish real version and compatibility facts; do not invent processor coverage, benchmarks, ratings, or testimonials.
- Date comparisons and review them when either product changes.
- Treat Search Console, Bing Webmaster Tools, first-party referrals, trial starts, and purchases as complementary evidence.
