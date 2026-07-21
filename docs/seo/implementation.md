# CmdTab SEO and GEO implementation

Implemented in three auditable phases:

1. `agent/implement-seo-geo-audit` — technical and semantic foundation.
2. `agent/seo-geo-competitive-hardening` — independent competitor critique, query architecture, privacy evidence, AI measurement, and stronger regression gates.
3. `agent/seo-geo-evidence-authority-phase` — product-claim alignment, public QA evidence, source-dated market comparison, webmaster hooks, and response-byte verification.

## Completed foundation

- Every maintained public page is driven by one canonical route registry used by the sitemap, IndexNow, `llms.txt`, and verification.
- Dashboard and API surfaces use metadata plus `X-Robots-Tag` index protection.
- `robots.txt` explicitly allows `OAI-SearchBot` on public content while excluding APIs.
- Every public route has complete canonical, robots, Open Graph, and Twitter metadata; one H1; visible breadcrumbs; matching structured data; and reviewed modification context.
- The entity graph includes Person, Organization, WebSite, SoftwareApplication, Offer, WebPage, FAQPage, TechArticle, citation, and Breadcrumb relationships that match visible content.
- Current public version, build, and minimum macOS are checked against `Resources/Info.plist`.
- Framework floors are kept on patched Next.js and React release families and the production dependency audit is required.

## Product-claim alignment

Before publishing broader authority content, the protected switcher implementation was aligned with the public exact-window contract:

- eligible windows remain represented when preview capture fails;
- multiple windows from one app remain separate in one global exact-window MRU sequence;
- forward and reverse selection do not skip an adjacent same-app window;
- ambiguous frontmost PIDs use exact visible history;
- focused-window changes inside the frontmost app are observed;
- provisional selections are promoted to permanent history only after activation confirmation;
- activation timeout is not recorded as success;
- the default per-app window cap is unlimited.

Permanent macOS 14 and macOS 15 CI reproduces the pre-fix model, runs focused strict-MRU/completeness regressions, runs the complete Swift package suite, and checks patch hygiene.

## Public evidence

`/evidence` publishes an explicit evidence ledger with:

- focused strict-MRU and preview-independent membership regressions;
- complete Swift package verification;
- the reproducible pre-fix state-space model;
- rendered production website verification;
- a real-macOS manual acceptance boundary.

Public downloads are served from:

```text
/evidence/switcher-model-results.json
/evidence/switcher-test-matrix.csv
/evidence/switcher-test-plan.md
```

The source verifier compares them byte-for-byte with `docs/qa/`, and the compiled-server verifier fetches the public responses and compares the served bytes again. Model counts are visibly labelled as synthetic state-space evidence rather than observed field failure rates.

## Source-dated market landscape

`/compare/mac-window-switchers` compares:

- built-in macOS switching;
- AltTab;
- BetterCmdTab;
- CmdTab;
- Scopo.

The page uses Apple Support and each product's first-party pages only. It displays the review date and methodology, treats missing information as unknown rather than absent, links every source visibly, provides an accessible wide table, explains intended fit instead of declaring a universal winner, and emits matching structured citations.

External prices, feature tiers, compatibility, download figures, and telemetry claims must be rechecked before the review date advances.

## Webmaster onboarding

The root layout supports environment-driven ownership metadata:

```text
GOOGLE_SITE_VERIFICATION
BING_SITE_VERIFICATION
```

The permanent SEO workflow supplies deterministic CI values and verifies the rendered `google-site-verification` and `msvalidate.01` tags after the production build.

This hook does not itself verify the domain. Owner-account verification, sitemap submission, URL inspection, and reporting remain Google Search Console and Bing Webmaster Tools operations.

## Search and AI discovery measurement

- Website pageviews are broadly classified as ChatGPT, Perplexity, Microsoft Copilot, Google Gemini, Claude, Google Search, Bing Search, direct, or referral.
- Classification uses a bounded campaign value or referrer hostname.
- Prompt and search-query text is not collected.
- `/dashboard/discovery` reports AI-assisted pageviews, visitors, sources, and landing pages.
- The dashboard states that missing referrers, privacy tools, redirects, copied links, and in-app browsers can undercount discovery.

Use webmaster-platform reporting, first-party referrals, trial starts, purchases, and support outcomes together. Do not treat citation screenshots as sufficient evidence of GEO performance.

## Verification

Run from `website/`:

```bash
npm ci
npm run seo:check
npm run typecheck
npx next build --webpack
npm audit --omit=dev --audit-level=high
```

The permanent workflow additionally starts the compiled server and runs:

```bash
npm run rendered:check
npm run webmaster:check
npm run evidence:check
npm run browser:check
```

The browser suite covers every canonical route at desktop and mobile sizes, mobile navigation, accessible wide tables, images, console and network failures, document overflow, unnamed controls, and the interactive switcher demo. CI also captures desktop and mobile visual evidence for the evidence ledger and market landscape.

## Production operations

1. Configure real Google and Bing verification tokens in the production environment.
2. Verify `cmdtab.net` in Google Search Console and Bing Webmaster Tools.
3. Submit `https://cmdtab.net/sitemap.xml` and inspect the principal canonical URLs.
4. Re-submit changed canonical URLs through IndexNow after deployment.
5. Confirm private routes remain excluded and crawler/CDN rules allow intended public bots.
6. Compare webmaster data with `/dashboard/discovery`, Vercel Analytics, trial starts, purchases, and support outcomes.
7. Provision monitored domain support, privacy, and security mailboxes before changing the current contact address.
8. Earn external authority through a validated signed release, original real-machine measurements, independent reviews, editorial links, authentic user discussion, and evidence-led localization.

## Honest boundary

CmdTab can be more transparent, source-verifiable, structured, and regression-resistant than reviewed competitor sites. That does not guarantee higher rankings or more AI citations. Established competitors retain external authority from downloads, backlinks, press, reviews, community discussion, and localization; those advantages must be earned through product quality and distribution.
