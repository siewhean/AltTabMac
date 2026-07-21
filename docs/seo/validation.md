# Final SEO and GEO specialist validation

**Validated:** 20–21 July 2026  
**Implementation branch:** `agent/implement-seo-geo-audit`  
**Specialist review:** PR #12, merged into PR #11

## Dependency state

The tested and committed lockfile resolves:

- Next.js `16.2.10`
- React `19.2.7`
- React DOM `19.2.7`

The public dependency guard enforces a minimum secure semantic version rather than one exact patch, so later patched releases remain valid.

## Specialist validation run

GitHub Actions run `29767609320` completed successfully on Ubuntu with Node 24. Every gate passed:

1. regenerated the dependency lock from the patched framework floors;
2. ran all SEO and GEO invariants;
3. ran the complete TypeScript check;
4. built the production Next.js site with Webpack;
5. ran `npm audit --omit=dev --audit-level=high`;
6. ran `git diff --check`;
7. committed the tested dependency lock and removed the one-time materialization workflow.

## Release-candidate verification added on 21 July 2026

The PR now verifies the built production server rather than relying only on source assertions:

- crawls every maintained public route and internal link;
- validates HTTP status, content type, canonical URL, description, Open Graph, Twitter metadata, robots directives, H1 count, alt text, JSON-LD, and visible/schema breadcrumbs;
- validates `robots.txt`, `sitemap.xml`, `llms.txt`, the web manifest, IndexNow key behavior, private-route headers, API noindex behavior, 404 handling, and security headers;
- renders all public routes at desktop and mobile sizes in headless Chrome;
- checks browser exceptions, console errors, failed requests, broken images, unfinished images, document overflow, unnamed controls, mobile navigation, and accessible handling of wide tables;
- captures visual evidence for the homepage, feature page, guide, comparison, FAQ, buy, privacy, and an opened mobile menu;
- exercises the homepage switcher demo by changing to Command Palette and filtering to Spotify.

The verification pass found and repaired issues that source-only checks did not expose:

- public subpages had no usable mobile navigation;
- the Privacy route lacked the shared site header and footer;
- the comparison table needed a named, keyboard-focusable horizontal-scroll region on narrow screens;
- local Vercel analytics endpoints and lazy images needed explicit browser-harness handling without hiding real network failures;
- Chrome startup and profile cleanup needed deterministic CI behavior;
- structured trial and purchase offers were marked `InStock` even when no public download or checkout URL was configured.

Structured offers are now emitted only when the same deployment configuration exposes the corresponding visible commerce action.

## Validated invariants

The verifier fails the build if:

- a maintained public canonical route disappears;
- sitemap dates revert to generation time;
- a public page loses complete metadata, one H1, visible breadcrumbs, breadcrumb schema, or WebPage schema;
- dashboard or API index protection is removed;
- the software entity loses version, requirements, features, sources, screenshots, or release-note relationships;
- commerce schema overstates unavailable trial or checkout offers;
- FAQ coverage becomes thin or diverges from its canonical page;
- privacy stops documenting the heartbeat, install identifier, website visitor identifier, or excluded window content;
- public version, build, or minimum macOS diverges from `Resources/Info.plist`;
- AI referral classification or its no-query boundary disappears;
- IndexNow or canonical-only `llms.txt` support disappears;
- Next.js, React, or React DOM fall below their configured secure minimums;
- rendered desktop or mobile behavior violates the release-candidate browser contracts above.

## Remaining production evidence

Repository and preview validation cannot prove:

- production redirects and canonical host normalization after the PR is deployed;
- Search Console and Bing ownership, crawl, or index state;
- production CDN or firewall access for intended crawlers;
- IndexNow submission until a production key is configured;
- actual AI referral, trial, and purchase performance;
- backlinks, reviews, press coverage, download proof, community discussion, or localization authority.

Those are deployment, account, and distribution requirements—not reasons to manufacture stronger claims in code.
