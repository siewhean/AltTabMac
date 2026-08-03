# Todo

## 2026-08-03 — PR #49 executed-CI remediation

- [x] Fix the macOS 14 Swift concurrency error in the menu-bar licence refresh timer.
- [x] Update only the rendered retrieval verifier for the canonical homepage and showcase wording.
- [x] Remove tracked Finder metadata and ignore Python-generated cache files.
- [x] Run native, website, and labelled repository-health checks locally.
- [ ] Push correction commits and require fresh hosted workflow evidence while PR #49 remains a draft.
- [ ] Complete independent QA/QC of the correction diff and CI logs.

### Review

- Local evidence is bound to the correction commits, not the superseded
  `c8c6fbf` candidate. Fresh hosted macOS 14/macOS 15, website, security, and
  release-readiness execution is required before PR #49 can leave draft.

## 2026-08-01 — Signed public beta release readiness

- [x] Gate 0: reconcile canonical release/security status, risk register, operational runbooks, and evidence index from `origin/main@dcd02fa`.
- [x] Gate 1: make the public beta arm64-only and prove clean native build, package, and distinct-directory reproducibility.
- [ ] Gate 2: record the candidate security/privacy/capability audit and permission acceptance boundary.
- [ ] Gate 3: validate signing/notarisation preparation; record missing Apple credentials as an external blocker.
- [ ] Gate 4: record the signed-artifact clean-machine and performance matrix as pending external evidence.
- [ ] Gate 5: add a fail-closed beta update manifest/appcast path and rollback contract while preserving unavailable stable release endpoints.
- [ ] Gate 6/7: keep commerce disabled; make beta pricing, support, download, legal, and release claims truthful.
- [ ] Gate 8: record the zero-step GitHub Actions/branch-protection blocker and required remediation.
- [ ] Gate 9/10: add immutable beta-candidate evidence and post-launch/rollback procedures; require explicit go-live approval.
- [ ] Run independent QA/QC after repository-owned changes and before any pass claim.

### Review criteria

- One logical commit and pushed evidence record per completed gate.
- `PASS` requires automated evidence plus the required manual/external proof; otherwise use `BLOCKED` or `NOT TESTED`.
- Never enable `CMDTAB_REQUIRE_COMMERCE_READY=1` for this beta.

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
