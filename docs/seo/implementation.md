# CmdTab SEO and GEO implementation

Implemented on `agent/implement-seo-geo-audit` from the audit dated 20 July 2026.

## Completed

- Expanded `sitemap.xml` to every current public canonical route.
- Removed misleading generation-time `lastModified` values.
- Added dashboard-level `noindex` metadata.
- Added `X-Robots-Tag` protection for dashboard and API routes.
- Explicitly allowed `OAI-SearchBot` to access public pages while excluding APIs.
- Added a reusable route metadata builder with canonical, robots, Open Graph, and Twitter data.
- Added a root title template, publisher and creator signals, and descriptive social-image alternative text.
- Added JSON-LD for the organization, website, software application, trial, founder offer, and page breadcrumbs.
- Added page-level H1 support to `SectionShell` and applied it to every public subpage.
- Added public About, Compatibility, Permissions, and Changelog pages.
- Added a canonical typed product-facts source.
- Published a factual 12-question FAQ on the homepage.
- Added a direct product-category definition to the homepage hero.
- Added factual product information and supporting internal links to the homepage, header, and footer.
- Added a web manifest.
- Added deterministic source assertions through `npm run seo:check`.
- Added GitHub Actions verification for SEO assertions, TypeScript, and the production Next.js build.

## Deliberate limits

- No ratings, testimonials, reviews, version number, processor support, download size, or benchmark numbers were invented.
- The existing personal contact email remains in use because domain email provisioning cannot be proven from repository code.
- GPTBot training access was not blocked or allowed explicitly because that is a business-policy decision distinct from ChatGPT search discovery.
- `llms.txt` was not added. Canonical public HTML, structured facts, crawler access, and measurement are higher priority, and Google does not require an AI-specific file.
- Comparison pages and long-form search guides were not generated without Search Console query evidence and a maintained process for verifying competitor facts.

## Verification

Run from `website/`:

```bash
npm ci
npm run seo:check
npm run typecheck
npx next build --webpack
```

## Production follow-up

1. Verify the domain in Google Search Console and Bing Webmaster Tools.
2. Submit `https://cmdtab.net/sitemap.xml`.
3. Inspect every public URL and confirm dashboard URLs are excluded.
4. Validate JSON-LD with Google Rich Results Test and Schema.org Validator.
5. Test `robots.txt`, sitemap, canonical host redirects, Open Graph cards, and `X-Robots-Tag` headers on production.
6. Verify CDN and firewall rules allow `OAI-SearchBot` to fetch public HTML and required assets.
7. Track ChatGPT search referrals using `utm_source=chatgpt.com` and measure trial and purchase outcomes.
8. Replace the personal Gmail address only after `support@cmdtab.net`, `privacy@cmdtab.net`, and `security@cmdtab.net` are provisioned and monitored.
9. Use Search Console query and landing-page data to choose the first guide and comparison pages.
