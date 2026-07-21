# SEO/GEO release-candidate verification complete

**Verified:** 21 July 2026  
**Branch:** `agent/implement-seo-geo-audit`  
**Verified head:** `ca9810632f5625c5a6a82ee1fddc88942ad5a516`  
**Pull request:** #11

## Final green checks

### Security workflow

GitHub Actions run `29808023008` passed:

- dependency installation;
- high-severity production dependency audit;
- TypeScript validation;
- production Next.js Webpack build.

### SEO, rendered-site, and browser workflow

GitHub Actions run `29808023024` passed:

- source-level SEO/GEO invariants;
- TypeScript validation;
- production Next.js Webpack build;
- production server startup;
- rendered metadata, schema, route, link, crawler, manifest, private-header, and security-header verification;
- all maintained public routes at desktop and mobile viewport sizes;
- mobile navigation on every public route;
- accessible wide-table behavior;
- browser console, runtime, request, image, overflow, H1, and control-name checks;
- the homepage interactive switcher demonstration.

## Coverage

- 14 maintained public routes;
- 14 maintained internal page paths;
- 28 desktop/mobile route renderings;
- exactly one H1 per public page;
- zero document-level horizontal overflow;
- 9 accessible mobile-navigation links per public route;
- valid canonical, Open Graph, Twitter, JSON-LD, sitemap, robots, `llms.txt`, and manifest output;
- dashboard and API index protection;
- conditional structured commerce offers that are emitted only when the matching public trial or checkout URL is configured.

## Evidence artifact

GitHub Actions artifact:

- name: `cmdtab-seo-browser-verification`
- artifact ID: `8486282494`
- size: `3,363,557` bytes
- SHA-256: `8bc51d17f1ca078795e8ad5046f1b9658f6e29155ed736624687d4a69e9d6f36`

The artifact contains verification logs, a complete browser report, and desktop/mobile screenshots for the key public routes and opened mobile navigation.

## Vercel preview

The release-candidate preview completed successfully with no build errors and no recent runtime errors. Preview deployment protection correctly adds `X-Robots-Tag: noindex`.

## Production boundary

The verified branch is not yet the production site. `cmdtab.net` must be reverified after PR #11 is merged and deployed. Search Console, Bing Webmaster Tools, IndexNow production configuration, actual provider transactions, and crawler/index state require production and account access.
