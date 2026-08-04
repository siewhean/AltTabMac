# Todo

## 2026-08-04 — Gate 3/5 credential-free release preparation

- [x] Add a no-mutation notarized-DMG preflight that validates the clean
  candidate, release configuration, tools, and names the required secure
  variables without reading or disclosing values.
- [x] Resolve Sparkle `generate_appcast` and `sign_update` from an explicit
  isolated SwiftPM scratch path, retaining paired executable overrides rather
  than relying on repository-local `.build` state.
- [x] Require a beta-labelled local DMG filename while retaining the numeric
  bundle short version, and reject mismatched publication inputs before
  metadata is written.
- [x] Obtain independent QA/QC of this combined source diff; do not sign,
  notarize, publish, tag, merge, or enable commerce.

### Review

- Independent QA/QC passed the source diff: 23 release-pipeline tests, Bash
  syntax, ReleaseConfig validation/repository verification, Sparkle-tool
  preflight, and whitespace hygiene. A dirty-worktree preflight correctly
  exited before creating `dist/release`; an isolated SwiftPM artifact
  resolution verified both Sparkle tools separately.
- A clean exact candidate is still required to run the no-mutation preflight
  to success. Developer ID identity, notarization, real artifact, update,
  clean-machine, and go-live evidence remain external gates.

## 2026-08-04 — Remaining operational-gap closure

- [x] Audit the remaining beta release, website, workflow, and commerce
  controls without changing the draft/publication boundary.
- [x] Fail-close every public trial, licensing, recovery, device, and
  license-help side-effect path before rate limits, parsing, database, KMS, or
  email work when commerce is disabled.
- [x] Make missing or malformed beta manifest and appcast inputs unpublished
  `503`/`no-store` responses without exposing parser detail.
- [x] Bind beta manifest/appcast generation to the mounted notarized DMG's
  numeric Apple bundle version and build, while retaining `x.y.z-beta.N` only
  as the prerelease/tag/manifest label.
- [x] Make Security and the preserved one-day Audit Source Export execute for
  every PR candidate, with least-privilege checkout and the archive bound to
  the submitted head SHA.
- [x] Align privacy, FAQ, terms, consent UI, and canonical release records
  with the unpublished, fail-closed beta state.
- [x] Run combined independent QA/QC, commit the replacement candidate, and
  obtain fresh executed hosted evidence while PR #49 remains a draft.
- [x] Reconcile G0/G2/G8 candidate records with exact SHA, P0/P1 disposition,
  independent QA/QC scope, executed run identifiers, and the remaining
  branch-protection/release-environment control gap.
- [ ] Reproduce the G1 unsigned-artifact/reproducibility record after the next
  source candidate is frozen; do not inherit `081ec041` evidence.
- [x] Commit the repository-owned operational controls as
  `5c6bf288baae9f20bc5b43e5ddfe351539b4a08d`: index-backed credential-content
  scanning, beta-DMG preflight/name binding, isolated Sparkle resolution, and
  unavailable purchase-confirmation copy.
- [ ] Obtain independent combined QA/QC and fresh executed hosted checks for
  `5c6bf288`; keep PR #49 draft until they pass.

### Review

- The application-source candidate `081ec04199885dffb5c7dddd30b6dcd23279bd55`
  received actual passes for macOS 14/15, Security, SEO/GEO/browser QA, Release
  Readiness, Workflow Health, Audit Source Export, and Vercel. No signing,
  notarization, tag, beta feed, beta manifest, production deployment, checkout,
  or commerce enablement is authorized by this task.
- External Gates 3, 4, 5, 6, 8, 9, and 10 remain `BLOCKED` or `NOT TESTED`
  until their required credentials, machines, mailbox, controls, or approval
  exist.

## 2026-08-04 — Gate 2 capability and privacy evidence

- [x] Route classic private AX window-ID lookup through observable capability
  status, preserving heuristic/app fallback and membership on lookup failure.
- [x] Add a privacy-manifest applicability decision grounded in the actual
  native telemetry payload, package it in the macOS bundle, and verify it.
- [x] Add telemetry serialization and local-diagnostics privacy contracts that
  reject titles, previews, screenshots, identifiers, tokens, and secrets.
- [x] Reconcile the canonical beta ledger, status, evidence index, security
  checklist, and update runbook with the current candidate and executed CI.
- [x] Run focused/full native, privacy-manifest, release-update, website, and
  browser checks without changing the draft/publication boundary.
- [ ] Obtain independent QA/QC and fresh hosted CI for the replacement SHA
  while PR #49 remains a draft.

### Review

- The combined source-built Swift suite passed 285/285. The beta-update
  pipeline passed 17/17; release identity, workflow-action, privacy-manifest,
  repository-hygiene, security, prebuild, production-build, rendered-page,
  retrieval, and Chrome browser checks passed locally. The Chrome-only
  verification artifacts were removed from the worktree after inspection.
- The beta configuration accepts only `/releases/beta/appcast.xml`; stable
  routes remain `503`/`no-store`. No DMG, appcast, manifest, signing,
  publication, deployment, or commerce action was performed.

### Boundary

- Developer-ID entitlements/notarization, real permission transitions,
  clean-machine acceptance, beta N-to-N+1/rollback execution, verified support
  mailbox, and go-live approval remain external `NOT TESTED` evidence.

## 2026-08-04 — Hosted SEO verifier reconciliation

- [x] Diagnose the exact-head SEO/GEO, website-security, and Vercel failure as
  a stale verifier that required the retired telemetry install identifier.
- [x] Update only the verifier and rerun the complete local website gate.
- [ ] Push the replacement draft candidate and require fresh executed hosted
  checks.

## 2026-08-04 — Dependency-audit remediation

- [x] Diagnose the exact-head Vercel preview and Security failures as the
  same newly disclosed moderate PostCSS advisory in the pinned Next.js tree.
- [x] Pin compatible Next.js `16.3.0` and PostCSS `8.5.23`, refresh only the
  npm lockfile, and update the version-pinning showcase verifier.
- [x] Under Node `24.18.0`, run `npm ci`, the mandatory dependency audit,
  security/prebuild/production-build gates, and rendered/retrieval checks
  against the local built server.
- [x] Obtain independent QA/QC of the dependency-audit remediation.
- [ ] Push the replacement draft candidate and require fresh hosted Vercel,
  Security, SEO/GEO, workflow, and macOS evidence.

### Review

- `npm audit --audit-level=moderate` returned zero vulnerabilities. The full
  `npm run security:check`, `npm run prebuild`, and `npm run build` commands
  passed with commerce still fail-closed; rendered-site and retrieval checks
  passed against `next start` on port 3001. Generated showcase outputs were
  restored after verification and are not part of this correction.
- Independent QA/QC verified the coherent lockfile, retained mandatory audit,
  fail-closed commerce checks, and absence of generated/release artifacts.

## 2026-08-04 — Preview-recovery cancellation ownership

- [x] Prevent a callback cancelled by a newer preview generation from clearing
  that newer request's in-flight marker for the same window identity.
- [x] Add a deterministic concurrency regression that holds the two capture
  requests at the ownership boundary and rejects duplicate capture.
- [x] Extract the shared preview-unavailable icon/text contract and cover both
  application-icon and system-symbol fallback states without a brittle SwiftUI
  hierarchy assertion.
- [x] Run the focused preview-continuity coverage and a source-built complete
  Swift suite before creating a new draft candidate.
- [x] Obtain independent QA/QC of the complete native correction.
- [ ] Push the exact candidate and collect fresh hosted CI evidence while PR
  #49 remains a draft.

### Review

- The recovery-focused test passed 9/9 and the fallback contract test passed
  2/2. The final source-built command,
  `swift test --scratch-path /tmp/CmdTab-native-reliability-final`, passed 276
  tests with 0 failures. The workflow-action verifier and repository-hygiene
  assertions also passed. Clean-machine, permission, signing, update, soak,
  and explicit go-live evidence remain `NOT TESTED`; this correction does not
  alter those release boundaries.
- Independent QA/QC passed the cancellation-generation ownership fencing,
  fallback wiring/coverage, workflow-action validation, and repository hygiene.

## 2026-08-04 — Sitemap freshness correction

- [x] Reconcile the canonical `/buy` and `/trial` sitemap dates with their
  2026-08-01 fail-closed public-beta content changes.
- [x] Add focused SEO-verifier coverage for both conversion-page modification
  dates.
- [x] Run the supported Node 24 SEO, production-build, rendered, and retrieval
  checks before the correction is committed and fresh hosted evidence is
  collected.

### Review

- Node 24.18.1 passed the source SEO verifier, full prebuild, production build,
  compiled-server retrieval check, and rendered-site check. Generated showcase
  media was restored after verification because it is outside this correction.
  This does not deploy or change the commerce boundary; fresh hosted evidence
  remains required after the logical commit.

## 2026-08-04 — Optional analytics measurement boundary

- [x] Preserve explicit analytics consent and add a pure production-start
  boundary for dashboard comparability.
- [x] Label dashboard pageview, visitor, and event counts as consented and
  suppress seven-day comparisons that overlap the transition.
- [x] Extend the analytics privacy verifier to reject collection in the
  measurement-boundary helper.
- [x] Run focused privacy and SEO verification, then the complete production
  build before committing the combined operational correction.

### Review

- Historical total traffic remains unavailable by design. Any anonymous
  all-visitor measurement requires a separate privacy/legal decision and cannot
  reconstruct the pre-consent period.
- Node 24.18.0 passed the privacy and SEO source checks, typecheck, full
  prebuild (including security/dependency and commerce-boundary checks), and
  production build. Generated showcase media was restored after verification.

## 2026-08-03 — PR #49 browser-gate remediation

- [x] Restore the homepage's verified one-shot inline autoplay contract without changing showcase-page behavior.
- [x] Correct the Help licence-recovery submit control's WCAG contrast failure.
- [x] Provide the browser QA server a deterministic, rate-limited analytics ingest backing while retaining production fail-closed behavior when no backing is configured.
- [x] Run the local source/security, production-build, repository-health, in-app-browser, and full Swift gates on `d7c3ffe`.
- [x] Push `d7c3ffe` and require fresh hosted macOS, SEO/GEO, Security, Workflow Health, Release Readiness, Audit Source Export, and Vercel evidence while PR #49 remains a draft.
- [x] Complete independent QA/QC of the remediation diff and fresh hosted logs.

### Review

- Candidate source commit: `d7c3ffe` (`fix: clear PR49 browser readiness failures`).
  The full Swift suite passed 273/273; the production build, API-security,
  workflow-action, media-integrity, and source checks passed. The in-app browser
  confirmed the homepage one-shot video and Help submit control without console
  warnings. The standalone local browser harness remains `NOT TESTED` because no
  Chrome/Chromium executable is installed; hosted browser execution is the
  authoritative matrix evidence. On `e1bc01d`, macOS 14/15, Security, Workflow
  Health, Repository Health, SEO/GEO (including the one-shot/autoplay, Axe, and
  analytics-rate-limit browser contract), Release Readiness, Audit Source Export,
  and Vercel all passed. The duplicate SEO/GEO context was rerun successfully so
  the draft PR reports `CLEAN`. The temporary one-day private audit-source export
  is retained unchanged.

## 2026-08-03 — Native membership and preview reliability audit

- [x] Preserve newly discovered base membership while enriched snapshots update.
- [x] Replay forced membership refreshes that arrive during capture.
- [x] Treat AX and sharing-state uncertainty as preview degradation, not membership exclusion.
- [x] Stabilize preview-continuity identity and improve dark-frame/recovery behavior.
- [x] Replace permanent preview skeletons with truthful icon fallback and add privacy-safe diagnostics.
- [x] Add focused regressions, run the full Swift suite, and complete independent QA/QC.
- [x] Preserve the approved temporary private audit-source export workflow.

### Review

- Combined Swift suite completed without an error exit; focused membership,
  AppSwitcher, preview-continuity, and runtime-diagnostics regressions passed.
- QA verified retry execution and known-launch PID reuse. An initially unknown
  launch token remains sticky by design; lifecycle eviction needs real-machine
  process-reuse evidence before any release acceptance claim.

## 2026-08-03 — PR #49 executed-CI remediation

- [x] Fix the macOS 14 Swift concurrency error in the menu-bar licence refresh timer.
- [x] Port updater configuration assertions to XCTest so macOS 14 executes their coverage.
- [x] Update only the rendered retrieval verifier for the canonical homepage and showcase wording.
- [x] Remove tracked Finder metadata and ignore Python-generated cache files.
- [x] Run native, website, and labelled repository-health checks locally.
- [x] Push correction commits and require fresh hosted workflow evidence while PR #49 remains a draft.
- [x] Complete independent QA/QC of the correction diff and CI logs.

### Review

- Local evidence is bound to the correction commits, not the superseded
  `c8c6fbf` candidate. Fresh hosted macOS 14/macOS 15, website, security, and
  release-readiness execution passed on `e1bc01d`; PR #49 remains a draft for
  the separate signing, clean-machine, update, support, soak, and approval gates.

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
