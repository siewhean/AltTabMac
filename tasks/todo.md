# Todo

## 2026-10-09 — Waitlist-only website qualification

- [x] Inspect main, production identity, existing candidate, and configuration without changing production.
- [x] Isolate website work; preserve the dirty native checkout and prior candidate.
- [x] Close public purchases, trials, and downloads; require consent and durable unique signup storage.
- [x] Improve canonical discovery, visible FAQ/source evidence, SEO/GEO, and organic campaign drafts.
- [x] Migrate Tailwind 4 and patched dependencies; dependency audit reports zero vulnerabilities.
- [x] Pass local production-build rehearsal: 12 browser profiles, real PostgreSQL 16 signup/analytics, and all three `/help` navigation modes.
- [x] Resolve independent source-review findings and regressions found by the rehearsal.
- [ ] Qualify the frozen SHA across all 88 browser route/profile checks and exact-SHA CI.
- [ ] Commit the scoped candidate, obtain exact-SHA CI, and complete independent QA.
- [ ] Supply genuine Google/Bing ownership values; missing configuration remains a blocker.

### Review

Initial browser verification exposed anchor-reset layering contrast errors and a Next.js
internal-host mismatch rejecting valid waitlist submissions. Both were fixed and passed fresh
local rehearsal checks. Full frozen-SHA qualification remains required. Production remains unchanged. Campaign target is 1,000 net-new unique
stored addresses, with submissions, notification delivery, and human verification distinct.


## 2026-08-01 — Fail-closed commerce worker stabilization

- [x] Reproduce the production `/api/internal/license-outbox` database error from Vercel runtime evidence.
- [x] Add one canonical launch-switch helper for `CMDTAB_REQUIRE_COMMERCE_READY=1`.
- [x] Keep worker authentication mandatory and return `commerce_disabled` before commerce database access while launch is disabled.
- [x] Gate the Lemon Squeezy webhook before configuration, body processing, fulfillment, refund handling, or lifecycle database access; return a retryable 503 while commerce is disabled.
- [x] Hide staged checkout providers, URLs, purchase buttons, and structured offers while fulfillment is disabled; retain support and existing-customer portal links.
- [x] Add unit coverage for exact launch-switch values and staged-checkout suppression.
- [x] Add source contracts proving disabled branches contain their returns before commerce sinks and that public checkout is launch-gated.
- [x] Run the Vercel website, security, commerce, SEO/GEO, dependency, TypeScript, and Next.js production gates.
- [x] Trigger and rerun GitHub Security, SEO/GEO, and Release Readiness workflows; record that the account rejected them before any runner step.
- [x] Preserve the existing frontend UI, copy, media, layout, native Swift, and packaging source.

### Review

- The exact final head and preview deployment are recorded in PR #40 after all review corrections.
- Vercel preview gates require the complete website unit and commerce-readiness inventories with no failures, zero dependency vulnerabilities, API-security and SEO/GEO verification, TypeScript, and the production Next.js build.
- GitHub Actions were rerun but every job returned `steps: null` and no log because hosted Actions capacity was unavailable. This is recorded as an infrastructure waiver, not as a CI pass.
- Production runtime revalidation remains required after the merge deployment.

---

## 2026-07-29 — Buy Page Waitlist Integration & 404 Prevention

- [x] 1. Update `CommerceOfferGrid` fallback CTA to point directly to `/trial` (or waitlist signup) with "Join the waitlist" text when checkout URL is not configured
- [x] 2. Update `website/src/app/buy/page.tsx` to embed `TrialWaitlistForm` section directly on `/buy`
- [x] 3. Audit all site navigation links and CTAs to ensure zero 404/broken links
- [x] 4. Test build and verification commands (`npm run prebuild` in `website/`)

---

## Completed Tasks (Trial Page & Round 3 Audit)

- [x] Create `TrialWaitlistForm` component for `website/src/app/trial/page.tsx`
- [x] Update `website/src/app/trial/page.tsx` with waitlist signup instructions, email collection form, and `/api/waitlist` API submission
- [x] Verify SEO requirements (`createPageMetadata`, `headingAs="h1"`, `createBreadcrumbStructuredData`, `createWebPageStructuredData`)
- [x] Test build and verification commands (`npm run prebuild` in `website/`)
- [x] Gated Developer preferences pane behind `#if DEBUG`
- [x] Integrated trial email registration into OnboardingView
- [x] Added `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to Keychain items
- [x] Bypassed sending trial emails to `anonymous@local`
- [x] Added cross-device purchasing banner on thank-you page
- [x] Returned 400 Bad Request on Zod errors in telemetry API
