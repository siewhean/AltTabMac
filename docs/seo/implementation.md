# CmdTab SEO and GEO implementation

Implemented in two auditable passes on 20 July 2026:

1. `agent/implement-seo-geo-audit` — technical and semantic foundation.
2. `agent/seo-geo-competitive-hardening` — independent competitor critique, query architecture, privacy evidence, AI measurement, and stronger regression gates.

## Completed foundation

- Expanded `sitemap.xml` to every maintained public canonical route.
- Added real maintained modification dates through one canonical route registry.
- Added dashboard-level `noindex` metadata and `X-Robots-Tag` protection for dashboard and API routes.
- Explicitly allowed `OAI-SearchBot` to access public pages while excluding APIs.
- Added a reusable route metadata builder with canonical, robots, Open Graph, and Twitter data.
- Added a root title template, publisher and creator signals, and descriptive social-image alternative text.
- Added visible page-level H1s, breadcrumbs, and last-reviewed dates.
- Added Organization, Person, WebSite, SoftwareApplication, Offer, WebPage, FAQPage, TechArticle, and Breadcrumb structured data.
- Added a web manifest and generated `llms.txt` directory that points only to canonical HTML.

## Authoritative public content

- `/features/window-switcher` — exact-window membership, ordering, preview fallback, Spaces, displays, and activation flow.
- `/guides/switch-between-windows-on-mac` — Command-Tab, Command-`, Mission Control, and CmdTab decision guide with Apple sources.
- `/compare/cmdtab-vs-macos-command-tab` — fair native comparison with cases where the built-in switcher remains the better choice.
- `/faq` — canonical factual FAQ with matching visible content and FAQ schema.
- `/compatibility` — current app version, build, minimum macOS, declared support, and explicit validation limits.
- `/permissions` — macOS permission purpose, graceful preview fallback, telemetry fields, and excluded local data.
- `/privacy` — exact website analytics and native app telemetry contract.
- `/about`, `/security`, `/changelog`, `/buy`, `/trial`, and `/help` — reviewed entity, trust, release, commerce, and support references.

## Source-of-truth safeguards

- Current public version/build and minimum macOS are checked against `Resources/Info.plist`.
- Sitemap, IndexNow, and `llms.txt` share `website/src/content/public-routes.json`.
- Public route verification requires metadata, one H1, breadcrumb schema, visible breadcrumbs, and WebPage schema.
- The privacy disclosure must keep exact app-heartbeat, install-ID, website-visitor-ID, and excluded-window-content language.
- FAQ coverage must remain substantive rather than collapsing to a single marketing answer.
- Framework floors are pinned to patched families: Next.js `^16.2.6`, React `^19.2.6`, and React DOM `^19.2.6`.

## Search and AI discovery measurement

- Website pageviews are broadly classified as ChatGPT, Perplexity, Microsoft Copilot, Google Gemini, Claude, Google Search, Bing Search, direct, or referral.
- Classification uses a bounded `utm_source` or referrer hostname.
- Prompt and search-query text is not collected.
- `/dashboard/discovery` reports AI-assisted pageviews, visitors, sources, and landing pages.
- The dashboard explicitly warns that missing referrers, privacy tools, redirects, and copied links can undercount discovery.

## IndexNow

Set `INDEXNOW_KEY` in the production environment. Confirm that:

```text
https://cmdtab.net/indexnow-key.txt
```

returns the exact key, then run from `website/` after publishing changed canonical pages:

```bash
npm run indexnow:submit
```

Do not submit private, API, preview-deployment, or unchanged duplicate URLs.

## Verification

Run from `website/`:

```bash
npm ci
npm run seo:check
npm run typecheck
npx next build --webpack
npm audit --omit=dev --audit-level=high
```

## Production follow-up

1. Verify the domain in Google Search Console and Bing Webmaster Tools.
2. Submit `https://cmdtab.net/sitemap.xml` and inspect every canonical public URL.
3. Confirm dashboard, API, preview-deployment, and administrative URLs remain excluded.
4. Validate JSON-LD with Google Rich Results Test and Schema.org Validator.
5. Test canonical host redirects, metadata cards, `robots.txt`, `llms.txt`, sitemap, IndexNow key, and `X-Robots-Tag` headers in production.
6. Confirm CDN, bot protection, and firewall rules allow `OAI-SearchBot` to fetch public HTML and required assets.
7. Enable and review Google Search Console generative-AI reporting and Bing Webmaster Tools AI Performance reporting where available.
8. Compare webmaster-platform data with `/dashboard/discovery`, Vercel Analytics, trial starts, and purchases rather than treating citations alone as success.
9. Provision and monitor `support@cmdtab.net`, `privacy@cmdtab.net`, and `security@cmdtab.net` before replacing the current personal contact address.
10. Earn external authority through a validated signed release, independent reviews, editorial coverage, real user discussion, measured performance evidence, and selective localization.

## Honest competitive boundary

The implementation can be more accurate, transparent, structured, measurable, and regression-resistant than competitor sites. It cannot guarantee higher rankings or more AI citations while established competitors retain stronger backlink, download, press, community, and localization authority.

See `docs/seo/competitive-hardening-review.md` for the detailed independent critique.
