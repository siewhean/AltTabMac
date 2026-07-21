# CmdTab SEO and GEO implementation

Implemented in four auditable phases:

1. `agent/implement-seo-geo-audit` — technical and semantic foundation.
2. `agent/seo-geo-competitive-hardening` — independent competitor critique, query architecture, privacy evidence, AI measurement, and stronger regression gates.
3. `agent/seo-geo-evidence-authority-phase` — product-claim alignment, public QA evidence, source-dated market comparison, webmaster hooks, and response-byte verification.
4. `agent/seo-geo-retrieval-and-feature-depth` — brand disambiguation, distinct mode/action references, focused AltTab comparison, Contexts coverage, retrieval exports, directory preparation, and unsupported-spec safeguards.

## Completed foundation

- Every maintained public page is driven by one canonical route registry used by the sitemap, IndexNow, and verification.
- Dashboard and API surfaces use metadata plus `X-Robots-Tag` index protection.
- `robots.txt` explicitly allows `OAI-SearchBot` on public content while excluding APIs.
- Every public route has complete canonical, robots, Open Graph, and Twitter metadata; one H1; visible breadcrumbs; matching structured data; and reviewed modification context.
- The entity graph includes Person, Organization, WebSite, SoftwareApplication, Offer, WebPage, FAQPage, TechArticle, citation, permission, and Breadcrumb relationships that match visible content.
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

## Entity disambiguation

CmdTab is now defined in visible homepage copy and SoftwareApplication structured data as a standalone macOS window-switcher application, separate from Apple’s built-in Command-Tab shortcut.

The structured entity adds:

- `alternateName` values for CmdTab for macOS and CmdTab window switcher;
- `disambiguatingDescription`;
- visible-current permission explanations;
- no invented memory or processor requirements.

Root title and description language reinforce the product entity where the brand could otherwise collide with generic native shortcut queries.

## Deep feature references

The canonical HTML registry expanded from 16 to 21 routes with:

```text
/features/classic-grid
/features/command-palette
/features/radial-menu
/features/quick-actions
/compare/cmdtab-vs-alttab
```

The four feature pages share one factual template but have distinct user intent, metadata, H1s, definitions, screenshots, behavior tables, best-fit guidance, tradeoffs, limits, and adjacent sources.

- Classic Grid covers visual exact-window scanning and preview fallback.
- Command Palette covers local app/window text matching, acronym signals, stable ties, remembered-choice behavior, and raw-query privacy.
- Radial Menu covers circular positional selection and the limits of positional recall.
- Quick Actions covers hide, minimize, close, quit, target scope, unavailable-control failure, and cross-app validation limits.

The main window-switcher page remains the behavior hub and links each deep reference rather than duplicating the same landing-page copy.

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

## Source-dated market and focused comparisons

`/compare/mac-window-switchers` now compares:

- built-in macOS switching;
- AltTab;
- BetterCmdTab;
- Contexts;
- CmdTab;
- Scopo.

The page uses Apple Support and each product's first-party pages only. It displays the review date and methodology, treats missing information as unknown rather than absent, links every source visibly, provides an accessible wide table, explains intended fit instead of declaring a universal winner, and emits matching structured citations.

`/compare/cmdtab-vs-alttab` provides a distinct decision page covering switching unit, search tier, presentation, window controls, shortcut breadth, commercial model, adoption signals, evidence, and product stage. It explicitly states that AltTab adoption figures are not controlled reliability benchmarks and that CmdTab remains an active beta with a smaller adoption base.

External prices, feature tiers, compatibility, download figures, adoption counts, and telemetry claims must be rechecked before their review date advances.

## Retrieval-oriented documentation

`/llms.txt` now provides descriptive links to product behavior, each mode/action page, evidence artifacts, comparisons, compatibility, permissions, privacy, and changelog sources.

`/llms-full.txt` is a generated consolidated Markdown context export with these controls:

- visibly described as a non-standard convenience export;
- canonical HTML declared authoritative;
- `X-Robots-Tag: noindex, follow`;
- excluded from the canonical HTML route registry and sitemap;
- direct Q&A and source rules;
- explicit ScreenCaptureKit, memory, processor, Universal Binary, latency, and model-versus-field-data boundaries.

The helper is not claimed as an AI-ranking requirement and must not contain unique product facts.

## Unsupported-spec boundary

The reviewed feedback proposed technical details not proved by the current product or release evidence. The implementation deliberately does not publish:

- ScreenCaptureKit;
- sub-50 ms thumbnail rendering or reveal latency;
- `<15 MB` or `<20 MB` RAM usage;
- Universal Binary status;
- Apple Silicon or Intel coverage;
- processor or memory requirements.

Current public source uses CoreGraphics, Accessibility APIs, and a WindowServer/SkyLight capture path. Any different architecture or quantitative claim requires implementation evidence and reproducible real-machine measurement first.

## Off-page distribution readiness

`docs/seo/software-directory-submission-pack.md` prepares maintained descriptions, categories, screenshots, links, privacy/permission/evidence facts, UTM conventions, and release gates for:

- AlternativeTo;
- Product Hunt;
- MacUpdate;
- Softpedia;
- StackShare.

Every row remains `Not submitted`. The pack is preparation, not proof of listing, approval, review, indexing, or alternative relationships. Owner-account submission follows a signed public release and destination-specific readiness.

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
npm run retrieval:check
npm run browser:check
```

The browser suite covers all 21 canonical routes at desktop and mobile sizes, mobile navigation, accessible wide tables, images, console and network failures, document overflow, unnamed controls, and the interactive switcher demo. CI captures desktop and mobile visual evidence for evidence, market comparison, focused AltTab comparison, and the four feature pages.

The retrieval verifier checks rendered brand disambiguation, SoftwareApplication permissions and entity text, new route purpose, `llms.txt`, noindex `llms-full.txt`, unsupported-spec boundaries, sitemap count, and helper-file sitemap exclusion.

## Production operations

1. Configure real Google and Bing verification tokens in the production environment.
2. Verify `cmdtab.net` in Google Search Console and Bing Webmaster Tools.
3. Submit `https://cmdtab.net/sitemap.xml` and inspect the principal canonical URLs.
4. Re-submit changed canonical URLs through IndexNow after deployment.
5. Confirm private routes remain excluded and crawler/CDN rules allow intended public bots.
6. Compare webmaster data with `/dashboard/discovery`, Vercel Analytics, trial starts, purchases, and support outcomes.
7. Provision monitored domain support, privacy, and security mailboxes before changing the current contact address.
8. Complete the signed/notarized release and direct trial/download flow before external software-directory submissions that require a downloadable product.
9. Earn external authority through original real-machine measurements, independent reviews, editorial links, authentic user discussion, and evidence-led localization.

## Honest boundary

CmdTab can be more transparent, source-verifiable, structured, and regression-resistant than reviewed competitor sites. That does not guarantee higher rankings or more AI citations. Established competitors retain external authority from downloads, backlinks, press, reviews, community discussion, and localization; those advantages must be earned through product quality and distribution.
