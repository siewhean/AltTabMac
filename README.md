# CmdTab

Last Updated: 2026-07-21  
Active Task: Deploy factual feature-depth and retrieval changes, then complete real-macOS acceptance, webmaster onboarding, signed release evidence, and external authority growth.

## Project Summary

CmdTab is a native macOS window switcher built with Swift, AppKit, and SwiftUI. It replaces an app-only switcher with individual eligible window targets, exact-window recent-use ordering, live previews with visual fallback, search, quick actions, and configurable Space and display scope.

The repository also contains a standalone Next.js product, commerce, documentation, analytics, and discovery site under `website/`.

## Current App Contract

- `⌘Tab` and `⌥Tab` open the same window-aware switcher.
- Every eligible top-level window is represented by its exact `(PID, CGWindowID)` identity.
- Multiple windows from one app remain separate and can be interleaved with other apps in one global MRU sequence.
- The current exact frontmost window remains visible at the end of the cycling order.
- Forward and reverse selection follow adjacent tiles; they do not scan for a different PID.
- Preview capture affects presentation only. An eligible window remains present with its icon or a placeholder when capture fails.
- A regular app without an eligible window receives a fallback target.
- Same-app focus changes are observed through Accessibility focused-window notifications.
- A committed selection is provisional until activation is confirmed. Permanent history changes only after verified activation.
- The default per-app window cap is unlimited; explicit user exclusions, title filters, visibility scope, and configured limits remain respected.
- Command Palette supports deterministic matching, acronym and token scoring, and remembered repeated selections.
- Quick actions can hide an app, minimize or close a window, or quit an app from the current selection.
- Settings expose Accessibility, Screen Recording, and Secure Input diagnostics plus preview preloading.
- Licensing supports a 14-day local trial and signed offline license activation.

## Protected App Paths

Treat these paths as protected:

- hotkey event routing and modifier-release quick switching;
- exact-window MRU/history ordering;
- frontmost resolution and provisional overrides;
- activation confirmation and failure handling;
- focused-window observation;
- preview-independent membership and fallback generation;
- quick-action dispatch;
- visible-item removal and suppression animations.

When touching protected paths:

1. Prefer the smallest patch that satisfies a reproduced failure.
2. Preserve current behavior by default.
3. Add a focused regression before or with the fix.
4. Run the complete Swift package suite.
5. Rebuild and manually exercise the relevant desktop flow.

The event-tap callback must remain non-blocking and return in under 20 ms. UI work belongs off the callback path.

## Automated App Evidence

Permanent `.github/workflows/swift.yml` jobs run on macOS 14 and macOS 15. Each job:

1. reproduces the pre-fix state-space evidence;
2. runs the strict-MRU and completeness acceptance tests;
3. runs the complete Swift package test suite;
4. runs patch-hygiene checks.

The reproducible model covers:

- 19,500 meaningful activation sequences with 3,900 pre-fix PID-skip mismatches;
- 126 preview-success configurations with 120 pre-fix completeness failures.

Those are synthetic state-space counts, not observed field failure rates.

Canonical QA sources live in `docs/qa/`. The public website publishes byte-matched copies from `/evidence`.

## Manual App Acceptance Boundary

Automation does not replace an interactive signed-app pass for:

- Accessibility and Screen Recording grant, denial, revocation, and recovery;
- selected identity versus actual focused `CGWindowID` for keyboard and mouse commits;
- same-app switching through mouse focus, `Cmd-\``, Mission Control, and Stage Manager;
- minimized and native-fullscreen windows;
- current Space, visible Spaces, all Spaces, and off-Space activation;
- single-display, multi-display, mixed-scaling, mirrored, disconnect, and reconnect behavior;
- rapid repeated switching, Secure Input, event-tap recovery, sleep and wake;
- signing, notarization, first-run permissions, and clean-account installation.

Do not convert a green CI result into a claim that these real-desktop scenarios passed.

## Website and Discovery Status

The production site uses one canonical public-HTML route registry for sitemap generation, IndexNow submissions, and build-breaking SEO verification.

The maintained discovery architecture contains 21 canonical HTML routes covering:

- exact-window switcher behavior;
- distinct Classic Grid, Command Palette, Radial Menu, and Quick Actions references;
- a native macOS window-switching guide;
- CmdTab versus the built-in macOS switcher;
- CmdTab versus AltTab;
- a source-dated landscape covering built-in macOS switching, AltTab, BetterCmdTab, Contexts, CmdTab, and Scopo;
- public testing evidence and downloadable QA artifacts;
- compatibility, permissions, privacy, FAQ, About, changelog, trial, purchase, help, and security.

The homepage and SoftwareApplication entity explicitly identify CmdTab as a standalone macOS window-switcher application, separate from Apple’s built-in Command-Tab shortcut.

Every maintained public page must provide:

- complete canonical, robots, Open Graph, and Twitter metadata;
- exactly one page-level H1;
- visible breadcrumbs and matching breadcrumb schema;
- visible review or modification context where facts can change;
- WebPage structured data, plus matching FAQ or TechArticle data where relevant;
- factual visible content consistent with structured data.

The website explicitly documents the native-app and website analytics fields it records and the local window content it does not send.

`/llms.txt` is a descriptive source directory. `/llms-full.txt` is a non-standard, noindex convenience export that defers to canonical HTML and is excluded from the XML sitemap.

## Website Verification

Run from `website/`:

```bash
npm ci
npm run seo:check
npm run typecheck
npx next build --webpack
npm audit --omit=dev --audit-level=high
```

The permanent SEO/GEO workflow additionally starts the compiled production server and verifies:

- every canonical route and internal link;
- metadata, JSON-LD, H1s, breadcrumbs, images, crawler files, private-route headers, and security headers;
- rendered Google and Bing ownership meta tags using deterministic CI tokens;
- byte-matched public evidence downloads;
- rendered entity disambiguation, deep-page purpose, `llms.txt`, noindex `llms-full.txt`, unsupported-spec boundaries, and sitemap-helper exclusion;
- desktop and mobile rendering across all 21 public routes, navigation, wide-table accessibility, and the interactive demo;
- visual evidence captures for evidence, market comparison, CmdTab-versus-AltTab, and the four deep feature pages.

## Search and AI Discovery Measurement

- Pageviews are broadly classified as ChatGPT, Perplexity, Microsoft Copilot, Google Gemini, Claude, Google Search, Bing Search, direct, or referral.
- Classification uses bounded campaign values or referrer hostnames.
- Prompt and search-query text is not collected.
- `/dashboard/discovery` reports AI-assisted pageviews, visitors, platforms, and landing pages.
- Missing referrers, redirects, privacy tools, copied links, and in-app browsers can undercount or misclassify discovery.
- Search Console, Bing Webmaster Tools, first-party analytics, trial starts, purchases, and support outcomes are complementary evidence. Citation screenshots are not a sufficient KPI.

## Decisions Already Made

- Canonical shared context file: `README.md`.
- Repo instruction entrypoints: `AGENTS.md`, `CLAUDE.md`, and `CODEX.md`.
- The product is a window-switching utility, not a browser-tab automation tool or broad launcher.
- Browser-tab Apple Events behavior and permissions should remain removed.
- `⌘Tab` remains the headline trigger; right-command and right-option tap modes are optional secondary triggers.
- Commercial direction: 14-day trial followed by a one-time license.
- Public claims must be visible in canonical HTML and supported by source, code, test, or clearly labelled product intent.
- Competitor comparisons must use first-party sources, show a review date, distinguish adoption from reliability, and treat missing claims as unknown rather than absent.
- Keep comparisons under `/compare/`; do not add near-duplicate `/vs/` doorway pages merely for keyword variants.
- Do not publish fake ratings, testimonials, directory status, download counts, processor coverage, benchmarks, or compatibility claims.
- Do not publish ScreenCaptureKit, RAM, latency, Universal Binary, Apple Silicon, Intel, processor, or memory claims without reproducible product/release evidence.
- `llms.txt` is a directory to canonical sources, not an AI-ranking mechanism and not a place for unique claims.
- `llms-full.txt` is an optional noindex convenience export; canonical HTML remains authoritative.
- External prices, feature tiers, compatibility, download figures, and adoption signals must be rechecked before advancing a comparison review date.
- `docs/seo/software-directory-submission-pack.md` is preparation only; external listings remain `Not submitted` until an owner action and listing URL are recorded.

## Open Issues and Next Steps

1. Deploy the 21-route feature-depth and retrieval phase, verify production, and submit the changed canonical set through IndexNow.
2. Execute the real-macOS acceptance matrix for permissions, exact focused-window proof, Spaces, displays, fullscreen, Stage Manager, rapid input, Secure Input, signing, notarization, and clean-account installation.
3. Publish a signed and notarized release only after the relevant acceptance rows pass.
4. Configure `GOOGLE_SITE_VERIFICATION` and `BING_SITE_VERIFICATION` with owner-account tokens, verify `cmdtab.net`, submit the sitemap, and inspect the principal canonical URLs.
5. Review Google Search Console and Bing Webmaster Tools alongside `/dashboard/discovery`, Vercel Analytics, trial starts, purchases, and support outcomes.
6. Provision monitored `support@cmdtab.net`, `privacy@cmdtab.net`, and `security@cmdtab.net` addresses before replacing the current contact email.
7. Configure and test the real trial download, checkout, webhook, license delivery, recovery, and support environment before paid traffic.
8. Complete the signed release and direct download flow before owner-operated AlternativeTo, Product Hunt, MacUpdate, Softpedia, or similar listings that require a downloadable product.
9. Publish original performance and exact-window activation methodology only after collecting reproducible real-machine measurements.
10. Earn authority through independent reviews, editorial links, authentic user discussion, and evidence-led localization rather than synthetic pages.
11. Keep this README, `website/SEO-GEO.md`, and `docs/seo/implementation.md` synchronized when the product or discovery contract changes.

## Recent Changes

### 2026-07-21

- Aligned the shipped switcher with the public exact-window MRU and preview-independent membership contract.
- Added permanent macOS 14 and macOS 15 regression CI and preserved the reproducible state-space model and 136-case test matrix.
- Added `/evidence` with public byte-matched QA artifacts and explicit automated-versus-manual boundaries.
- Added `/compare/mac-window-switchers` using source-dated first-party facts and visible comparison limitations.
- Added environment-driven Google Search Console and Bing Webmaster Tools verification hooks with rendered CI validation.
- Added entity disambiguation, four distinct mode/action references, a focused CmdTab-versus-AltTab comparison, and Contexts to the wider landscape.
- Expanded `llms.txt`, added a non-standard noindex `llms-full.txt`, and protected the helper/canonical boundary with rendered verification.
- Prepared an owner-operated software-directory pack while explicitly rejecting unsupported ScreenCaptureKit, memory, processor, Universal Binary, and latency claims.
- Expanded the canonical public HTML registry from 16 to 21 routes and verified all routes at desktop and mobile sizes.

### 2026-07-20

- Implemented the technical SEO/GEO foundation, canonical-route registry, crawler controls, structured data, factual content architecture, discovery-source measurement, private discovery dashboard, and IndexNow ownership/submission flow.
- Updated Next.js and React to patched release families and passed the production dependency audit.

## Agent Update Protocol

1. Read `AGENTS.md`.
2. Read this file before planning or coding.
3. Treat this file as the current shared context unless the latest user prompt overrides it.
4. Update Current Status, Decisions, Open Issues, and Recent Changes whenever work changes them.
5. Prefer correcting existing statements over appending contradictory notes.
