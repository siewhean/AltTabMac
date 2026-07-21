# CmdTab SEO and GEO implementation

Implemented in five auditable phases:

1. `agent/implement-seo-geo-audit` — technical and semantic foundation.
2. `agent/seo-geo-competitive-hardening` — independent competitor critique, query architecture, privacy evidence, AI measurement, and stronger regression gates.
3. `agent/seo-geo-evidence-authority-phase` — product-claim alignment, public QA evidence, source-dated market comparison, webmaster hooks, and response-byte verification.
4. `agent/seo-geo-retrieval-and-feature-depth` — brand disambiguation, distinct mode/action references, focused AltTab comparison, Contexts coverage, retrieval exports, directory preparation, and unsupported-spec safeguards.
5. `agent/real-app-showcase-media` — authentic production-view images and short videos, a canonical watch page, VideoObject markup, accessible playback, fixture disclosure, and media-response regression gates.

## Completed foundation

- Every maintained public page is driven by one canonical route registry used by the sitemap, IndexNow, and verification.
- Dashboard and API surfaces use metadata plus `X-Robots-Tag` index protection.
- `robots.txt` explicitly allows `OAI-SearchBot` on public content while excluding APIs.
- Every public route has complete canonical, robots, Open Graph, and Twitter metadata; one H1; visible breadcrumbs; matching structured data; and reviewed modification context.
- The entity graph includes Person, Organization, WebSite, SoftwareApplication, Offer, WebPage, FAQPage, TechArticle, VideoObject, citation, permission, and Breadcrumb relationships that match visible content.
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

CmdTab is defined in visible homepage copy and SoftwareApplication structured data as a standalone macOS window-switcher application, separate from Apple’s built-in Command-Tab shortcut.

The structured entity includes:

- `alternateName` values for CmdTab for macOS and CmdTab window switcher;
- `disambiguatingDescription`;
- current permission explanations;
- real showcase posters as software screenshots;
- no invented memory or processor requirements.

Root title and description language reinforce the product entity where the brand could otherwise collide with generic native shortcut queries.

## Real product images and short videos

The source now includes a deterministic macOS showcase renderer:

```bash
swift run -c release CmdTab --render-showcase website/public/showcase
```

It generates:

```text
overview-poster.png
overview.mp4
classic-grid-poster.png
classic-grid.mp4
command-palette-poster.png
command-palette.mp4
radial-menu-poster.png
radial-menu.mp4
quick-actions-poster.png
quick-actions.mp4
contact-sheet.png
manifest.json
README.md
```

### What the media represents

- The switcher panels are production `ClassicGridView`, `CommandPaletteView`, and `RadialMenuView` renders.
- The renderer uses production `SwitcherViewModel`, `PaletteSearch`, item cards, rows, selection styling, and item mutation behavior.
- Window titles and previews are deterministic fixtures created with AppKit/SwiftUI so no private desktop data is recorded.
- System application icons are used where available.
- The surrounding desktop and fixture windows are capture context.
- The Quick Action key badge is an explanatory capture annotation.
- The assets are not AI-generated.

### What the media does not prove

The clips do not prove signed-app Accessibility or Screen Recording behavior, real focused `CGWindowID`, Spaces, displays, fullscreen activation, Stage Manager, secure input, signing, or notarization. Those remain in the manual acceptance matrix.

### Encoding and validation

- Posters are 1280×800 PNGs.
- Videos are short, silent, 20 fps H.264 MP4 loops encoded with AVFoundation.
- `manifest.json` records dimensions, duration, frame rate, codec, audio state, file bytes, source type, and fixture disclosure.
- `scripts/showcase/validate_showcase_media.swift` validates image/video metadata and samples the central product area so a decorative desktop cannot hide a blank lazy grid or list.
- `scripts/verify-showcase-media.mjs` protects committed file signatures, manifest alignment, disclosure, stable URLs, player behavior, and unsupported-claim exclusions.
- `scripts/verify-showcase-responses.mjs` fetches the compiled watch page, posters, MP4s, manifest, content types, byte counts, and range responses.

### Capture-only eager layout

SwiftUI lazy containers do not reliably instantiate offscreen children under `ImageRenderer`. The first generation attempt therefore produced blank Classic Grid and Command Palette panels and was rejected.

`ShowcaseRenderingMode` now switches only the capture path to eager row/column containers while reusing the same production item card and row views. Normal application rendering remains on the original lazy containers. A central-region variance check would reject the original blank output.

## Canonical showcase page

`/showcase` is the canonical watch page and the 22nd public HTML route. It contains:

- the overview video as the primary page content;
- four mode/action clips with stable poster and MP4 URLs;
- explicit play/pause controls;
- muted inline loops;
- reduced-motion default pause;
- visible descriptions and transcripts;
- production-view and controlled-fixture disclosures;
- a link to the evidence ledger;
- WebPage, BreadcrumbList, and VideoObject structured data.

The homepage and main switcher page embed the overview. The four deep feature pages embed their corresponding real production clip and use the real poster for social metadata.

## Deep feature references

The canonical HTML registry previously expanded with:

```text
/features/classic-grid
/features/command-palette
/features/radial-menu
/features/quick-actions
/compare/cmdtab-vs-alttab
```

The four feature pages share one factual template but have distinct user intent, metadata, H1s, definitions, real videos, behavior tables, best-fit guidance, tradeoffs, limits, and adjacent sources.

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

`/compare/mac-window-switchers` compares:

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

`/llms.txt` provides descriptive links to the real showcase, stable poster/MP4 URLs, manifest, product behavior, each mode/action page, evidence artifacts, comparisons, compatibility, permissions, privacy, and changelog sources.

`/llms-full.txt` is a generated consolidated Markdown context export with these controls:

- visibly described as a non-standard convenience export;
- canonical HTML declared authoritative;
- `X-Robots-Tag: noindex, follow`;
- excluded from the canonical HTML route registry and sitemap;
- real-media descriptions and transcripts;
- explicit production-view, fixture, ScreenCaptureKit, memory, processor, Universal Binary, latency, signed-app, and model-versus-field-data boundaries.

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

`docs/seo/software-directory-submission-pack.md` prepares maintained descriptions, categories, screenshots, links, privacy/permission/evidence facts, UTM conventions, and release gates for AlternativeTo, Product Hunt, MacUpdate, Softpedia, and StackShare.

The validated showcase contact sheet and stable posters can be used only after the public release and public media URLs are live. Every directory row remains `Not submitted`; the pack is not proof of listing, approval, review, indexing, or alternative relationships.

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

Use webmaster-platform reporting, first-party referrals, showcase engagement, trial starts, purchases, and support outcomes together. Do not treat citation screenshots or video-index eligibility as sufficient evidence of GEO performance.

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
npm run showcase:responses
npm run browser:check
```

The browser suite covers all 22 canonical routes at desktop and mobile sizes, mobile navigation, accessible wide tables, images, media requests, console and network failures, document overflow, unnamed controls, and the interactive switcher demo. CI captures desktop and mobile visual evidence for the showcase, evidence, comparisons, and feature pages.

## Production operations

1. Generate, validate, visually inspect, and commit the final showcase media.
2. Remove the one-time generation workflow and restore permanent Swift CI to read-only repository access.
3. Deploy the 22-route release and verify `/showcase`, every poster/MP4/manifest response, VideoObject markup, browser playback controls, and production runtime errors.
4. Configure real Google and Bing verification tokens in the production environment.
5. Verify `cmdtab.net` in Google Search Console and Bing Webmaster Tools.
6. Submit `https://cmdtab.net/sitemap.xml`, inspect the principal canonical URLs, and re-submit changed canonical URLs through IndexNow.
7. Confirm private routes remain excluded and crawler/CDN rules allow intended public bots and raw video fetching.
8. Compare webmaster data with `/dashboard/discovery`, Vercel Analytics, showcase engagement, trial starts, purchases, and support outcomes.
9. Provision monitored domain support, privacy, and security mailboxes before changing the current contact address.
10. Complete the signed/notarized release and direct trial/download flow before external software-directory submissions that require a downloadable product.
11. Earn external authority through original real-machine measurements, independent reviews, editorial links, authentic user discussion, and evidence-led localization.

## Honest boundary

CmdTab can be more transparent, source-verifiable, structured, visually demonstrable, and regression-resistant than reviewed competitor sites. That does not guarantee higher rankings, video indexing, or more AI citations. Established competitors retain external authority from downloads, backlinks, press, reviews, community discussion, and localization; those advantages must be earned through product quality and distribution.
