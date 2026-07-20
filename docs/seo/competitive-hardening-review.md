# Independent SEO and GEO specialist review

**Reviewed:** 20 July 2026  
**Base implementation:** PR #11, `agent/implement-seo-geo-audit`  
**Specialist branch:** `agent/seo-geo-competitive-hardening`

## Executive critique

PR #11 repaired important foundations: canonical metadata, sitemap coverage, `noindex` protection, page-level H1s, structured data, public compatibility and permission pages, a factual FAQ, and automated checks.

That implementation was technically credible but still not competitively complete. It remained closer to a well-described product homepage than an authoritative information system. The main gaps were:

1. no dedicated page targeting the core category, “Mac window switcher”;
2. no answer-first guide for the broader “switch between windows on Mac” problem;
3. no sourced comparison with the built-in macOS switcher;
4. FAQ content visible only as a long homepage section rather than a canonical reference page;
5. structured data carrying facts that were not consistently visible in the page body;
6. vague privacy language that omitted the actual native app telemetry payload and cadence;
7. no maintained release version in public facts or schema;
8. no visible breadcrumbs or review dates;
9. no first-party classification of AI-assisted discovery;
10. no IndexNow publishing path for Bing and participating engines;
11. no build invariant tying public version and minimum macOS claims to `Info.plist`;
12. no explicit framework security floor despite a failing dependency audit.

## Competitor baseline

### AltTab

Observed strengths:

- longstanding category authority;
- millions of downloads and substantial GitHub social proof;
- press references and external corroboration;
- deep feature pages, pricing, changelog, localization, and public source history;
- broad backlink and branded-search moat.

Sources:

- https://alt-tab.app/
- https://alt-tab.app/pricing
- https://alt-tab.app/changelog

### Scopo

Observed strengths:

- dedicated window-switcher feature page;
- explicit “windows rather than apps” explanation;
- numbered workflow explanation;
- project and use-case segmentation;
- FAQ, pricing, privacy, and developer content.

Sources:

- https://scopo.app/
- https://scopo.app/features/window-switcher
- https://scopo.app/faq
- https://scopo.app/pricing

### BetterCmdTab

Observed strengths:

- unusually broad feature taxonomy;
- compatibility and processor claims;
- direct comparison with macOS and alternatives;
- visible FAQ and telemetry claims;
- GitHub and release links.

Source:

- https://bettercmdtab.app/

### Contexts

Observed strengths:

- clear application-versus-window positioning;
- search-led switching explanation;
- visible version, macOS compatibility, and price;
- established product history.

Source:

- https://contexts.co/

## What CmdTab can credibly outperform

This branch does not claim guaranteed rankings. Technical SEO quality is only one input. Competitors retain authority advantages that code cannot manufacture.

CmdTab can, however, outperform the reviewed sites in the combination of:

- exact-window ordering documentation;
- explicit behavior when preview capture fails;
- visible alignment between app metadata and public product facts;
- source-linked native macOS comparisons;
- precise website and native-app telemetry disclosure;
- explicit fields that are not transmitted;
- truthful compatibility limits instead of unverified processor claims;
- visible review dates;
- FAQ, WebPage, TechArticle, Organization, Person, Website, SoftwareApplication, Offer, and Breadcrumb structured data that matches visible content;
- first-party ChatGPT, Perplexity, Copilot, Gemini, and Claude referral classification without storing prompts or search queries;
- a private AI-discovery landing-page dashboard;
- a canonical route registry shared by sitemap, verification, and IndexNow;
- build failure when public routes, facts, privacy disclosures, version alignment, or discovery instrumentation regress.

## Implemented hardening

### Query architecture

Added canonical pages for:

- `/features/window-switcher`
- `/guides/switch-between-windows-on-mac`
- `/compare/cmdtab-vs-macos-command-tab`
- `/faq`

These pages answer distinct intents instead of repeating one generic landing page.

### Visible evidence

Added:

- visible breadcrumb navigation;
- visible last-reviewed dates;
- current app version and build from project metadata;
- source-repository and developer links;
- behavior and decision tables;
- Apple-source links for native macOS claims;
- explicit release-validation boundaries.

### Entity and structured data

Expanded the graph with:

- founder/developer `Person`;
- `Organization` relationships and official source profiles;
- richer `SoftwareApplication` facts;
- version, requirements, screenshots, features, offers, and release notes;
- `WebPage`, `FAQPage`, `TechArticle`, and `BreadcrumbList` markup.

### Privacy and trust

Published the actual current native telemetry contract:

- activation event at app start;
- hourly heartbeat while running;
- trial-start and license-activation events;
- pseudonymous install identifier;
- license state and identifier when present;
- app and macOS versions;
- timestamp.

Also states that the current payload does not contain window titles, previews, screenshots, keystrokes, file names, clipboard contents, or search queries.

### Measurement and indexing

Added:

- broad AI and search discovery classification;
- no collection of prompt or search-query text;
- a private discovery dashboard;
- canonical route registry;
- IndexNow key endpoint and submission script;
- maintained sitemap modification dates;
- deterministic verification across all public routes.

### Security floor

Raised the declared dependency floors to patched releases:

- Next.js `^16.2.6`
- React `^19.2.6`
- React DOM `^19.2.6`

The lockfile must be regenerated and the existing security audit must pass before the specialist branch is merged.

## Remaining advantages competitors still hold

The following cannot be solved by adding more code or copy:

1. independent reviews;
2. editorial coverage;
3. backlinks from relevant Mac publications and communities;
4. user-generated discussion and recommendations;
5. years of branded-search demand;
6. download and active-install proof;
7. verified testimonials or case studies;
8. localization into high-opportunity languages;
9. public release cadence and signed-download history;
10. sustained Search Console and Bing Webmaster performance data.

Trying to imitate these with invented numbers, fake testimonials, thin translated pages, or unsupported comparison claims would reduce trust rather than create authority.

## Recommended post-merge authority plan

1. Complete live product QA and publish a signed public build.
2. Publish measured launch, memory, and exact-window activation results with methodology.
3. Submit the sitemap to Google Search Console and Bing Webmaster Tools.
4. Enable Google Search Generative AI reporting and Bing AI Performance reporting when available to the verified property.
5. Configure IndexNow and submit only changed canonical URLs.
6. Seek independent reviews from Mac utility publications and experienced users.
7. Publish a real public roadmap and versioned release notes.
8. Localize only after query and conversion evidence identifies worthwhile markets.
9. Review every competitor comparison at least quarterly and date the review.
10. Track discovery through referral, landing page, trial start, and purchase—not citation screenshots alone.

## Definition of “better”

For this project, “better than competitors” should mean:

- more accurate;
- more transparent;
- easier to verify;
- better structured for users and retrieval systems;
- more measurable;
- less dependent on unsupported claims;
- harder for future code changes to make stale.

It cannot honestly mean guaranteed higher rankings or more AI citations before CmdTab earns equivalent external authority and usage.
