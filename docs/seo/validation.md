# Final SEO and GEO specialist validation

**Validated:** 20 July 2026  
**Specialist branch:** `agent/seo-geo-competitive-hardening`  
**Review PR:** #12

## Dependency state

The tested and committed lockfile resolves:

- Next.js `16.2.10`
- React `19.2.7`
- React DOM `19.2.7`

The public dependency guard enforces a minimum secure semantic version rather than one exact patch, so later patched releases remain valid.

## Successful validation run

GitHub Actions run `29767609320` completed successfully on Ubuntu with Node 24. Every gate passed:

1. regenerated the dependency lock from the patched framework floors;
2. ran all SEO and GEO invariants;
3. ran the complete TypeScript check;
4. built the production Next.js site with Webpack;
5. ran `npm audit --omit=dev --audit-level=high`;
6. ran `git diff --check`;
7. committed the tested dependency lock and removed the one-time materialization workflow.

## Validated invariants

The specialist verifier now fails the build if:

- a maintained public canonical route disappears;
- sitemap dates revert to generation time;
- a public page loses complete metadata, one H1, visible breadcrumbs, breadcrumb schema, or WebPage schema;
- dashboard or API index protection is removed;
- the software entity loses version, requirements, features, sources, screenshots, offers, or release-note relationships;
- FAQ coverage becomes thin or diverges from its canonical page;
- privacy stops documenting the heartbeat, install identifier, website visitor identifier, or excluded window content;
- public version, build, or minimum macOS diverges from `Resources/Info.plist`;
- AI referral classification or its no-query boundary disappears;
- IndexNow or canonical-only `llms.txt` support disappears;
- Next.js, React, or React DOM fall below their configured secure minimums.

## Remaining production evidence

Repository validation cannot prove:

- deployed redirects and canonical host normalization;
- Search Console and Bing index state;
- CDN or firewall access for intended crawlers;
- structured-data interpretation after deployment;
- IndexNow key and submission behavior against production;
- actual AI referral, trial, and purchase performance;
- backlinks, reviews, press coverage, download proof, community discussion, or localization authority.

Those are deployment and distribution requirements, not reasons to manufacture stronger claims in code.
