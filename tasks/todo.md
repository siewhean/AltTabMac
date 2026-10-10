## 2026-10-10 — One-step signup, faster signup, better welcome email

User report (screenshot): the welcome email landed in **Junk** (NUS Outlook) with the banner blocked; the confirm button worked; two-step signup was unwanted; signup felt slow.

- [x] **One step (owner decision, reverses D2/D4 of 2026-10-10):** entering an email is joining. No confirm gate, no 30-day purge of unverified signups. Verification stays as an **optional** signed link, needed only for the invite reward (inviter and friends must be verified) and for product-update consent. Copy updated in the form, success screen, welcome email, verify page, privacy policy, terms and FAQ. Trade-off accepted: unverified addresses (typos, someone else's address) now count as members; one welcome email is sent per signup and every email has an unsubscribe link.
- [x] **Speed.** Measured with 50 ms database round trips and a 500 ms mail API: warm signup **2.5 s → 0.55 s**. Causes: the response waited for two mail calls in series plus ~30 sequential database statements (each costs two round trips because the pooled connection cannot use prepared statements, and statements cannot overlap). Fixes: welcome and owner emails sent after the response with `after()`, both at once; rate-limit counters, duplicate lookups, duplicate marks and signup lookups each folded into one statement; one-query schema probe instead of ~15 DDL statements per cold start.
- [x] **Region (biggest real-world cause):** the database is in `ap-southeast-1` (Singapore) but functions ran in `iad1` (Washington). `vercel.json` now pins `regions: ["sin1"]`. Watch AWS KMS signing (us-east-1) after deploy: it now crosses the Pacific once per license operation while the many database queries get fast.
- [x] **Deliverability changes** (cannot prove the cause of Junk from here): decorative banner now has empty alt text (no ugly alt line when images are blocked), invite link shortened to `/?ref=code` (no tracking query string), "Get CmdTab free" heading softened to "Earn a CmdTab license", one primary button. Real fix needs sender reputation: ask the user for the Junk message's `Authentication-Results` header (SPF/DKIM/DMARC), consider sending from the older verified `updates.cmdtab.net`, and mark-not-junk at big providers.
- [x] **Security review findings (information disclosure, broken access control, user-enumeration oracle in the signup route), fixed in two steps.** The notifications gave only the categories, so this is based on my own reading of the route; re-check against the full findings when available. (1) Different outcomes returned different responses (an alias of a registered mailbox returned `notificationQueued: false` and no invite block; a repeat within 24 hours returned a bare `ok`; an address already on the list returned that member's reward progress and verified status), so anyone could probe who is on the list. (2) Making every outcome return the invite code was itself a leak: it gave anyone who typed your email your personal invite code (which also acted as a credential for the use-case write), and any scheme that shows a new member something on screen that an existing member does not see is an existence oracle. **Final design:** the web response carries nothing per address: same body for new, existing, alias and repeat submissions, with only an opaque signed `profileToken` that is valid for whatever address was typed and authorizes one optional write (the use-case answer; first answer wins; separate MAC purpose, 24 h life). The personal invite link goes **only to the mailbox**, by email. The success screen therefore says to open the welcome email; it no longer shows the link, share buttons or a progress bar. Residual risks, accepted: response-time differences between paths (rate limits of 6 per minute and 24 per hour per IP make timing probes impractical) and email-bombing of an existing address (limited by the same rate limits and the 24 h duplicate window).
- [x] Referral qualification, abuse checks and the cap of 100 are unchanged (20 database scenarios re-run, all pass).

Review: tsc, 83 unit tests, 20 real-PostgreSQL scenarios, 9 offline end-to-end checks (one-step reply time, both emails after the response, no "confirm" wording, short invite link, optional verify, verified-friend-only referrals, alias, mail outage keeps the signup and marks it `failed`). Not covered: a real send to Outlook/Gmail, production latency (measured only in a simulated harness).

## 2026-10-10 — Exact window selection raised every window of the app

- [x] Root cause: after the private SkyLight focus brought the selected window forward, `activateWindow` also activated the app (`NSRunningApplication.activate` plus `AXFrontmost` on the application), and `raiseWindow` set `AXFrontmost` again. App-level activation raises all of an app's windows, so selecting one of three Finder windows brought all three forward.
- [x] Fix: the first exact attempt focuses only the window (private focus, then AX main/focused/raise on that window). App activation stays only as the escalation when the window is not verified frontmost, and on the app-fallback paths.
- [x] `Activation path:` log lines (exact focus, app fallback with reason, escalation) at default level.

Review: 427 XCTest + 2 Swift Testing pass; five-feature source verifier passes. On the user's Mac (debug build): only the selected Finder window comes forward; three switches logged `Activation path: exact window focus`, no fallback or escalation.

## 2026-10-10 — Production KMS signing provisioned

- [x] OIDC fix: the signer reads the Vercel OIDC token per request with `@vercel/oidc` (#84); `VERCEL_OIDC_TOKEN` exists only in builds.
- [x] AWS (account `880302055919`, `us-east-1`): trial and license P-256 KMS keys, Vercel team OIDC provider, `cmdtab-vercel-production-signing` role limited to production of project `website` and to `kms:Sign`/`kms:GetPublicKey` on the two keys.
- [x] Keyrings `trial-2026-10` and `license-2026-10` pass the app build validator; KMS test signatures verify against them.
- [x] Vercel Production: 8 KMS variables added, `CMDTAB_LICENSE_PRIVATE_KEY_PEM` removed (also from Preview), `main` at `c2389cd1` redeployed.
- [ ] Build the signed app with the trial and license kid/keyring values embedded.
- [ ] Paid-license signing is untested until commerce is enabled.

Review: a live `POST /api/trial/start` returned a `CMDTAB2` trial token (kid `trial-2026-10`, 14 days) whose signature verifies against the published keyring. Details: `docs/release/token-v2-kms-migration.md`.

## 2026-10-10 — Welcome email redesign reworked onto the current email

Source: uncommitted redesign recovered from the deleted `codex/marketing-waitlist-readiness` worktree (backup in `~/Documents/CmdTab-branch-backups-2026-10-10/`), rebased by hand onto the current template.

- [x] Table-based, solid-colour layout (no flex/grid/positioning/gradients, which Gmail and Outlook strip), hidden preheader for the inbox preview, banner illustration, flatter card. Kept the confirm button, free-license block (cap of 100) and unsubscribe footer added since the redesign was drafted, restyled to match.
- [x] One primary button per email: "Confirm my email" when a confirm link exists, otherwise "Visit CmdTab"; the visit link becomes plain text next to the confirm button.
- [x] Banner `public/email/cmdtab-welcome-illustration.jpg` (68 KB, 1200x600) is decorative concept art, labelled as such in the alt text; it is not a product screenshot. `/email/*` is cached for a day like the other public images.
- [x] 8 new tests (`tests/waitlist-email.test.ts`): email-safe constructs only, absolute and normalized banner URL, alt text, file is a JPEG under 150 KB, preheader first, single-button rule, unsubscribe in both formats, HTML escaping, existing-member wording.

Review: tsc, 78 unit tests, `npm run security:check` (webpack build, as CI), banner served as image/jpeg with the cache header, and the rendered email checked at 700px and 375px (no horizontal overflow). Not covered: real mail clients (Gmail, Outlook, Apple Mail, dark-mode inversion), because nothing was sent. Send yourself a test before relying on it.

## 2026-10-10 — Waitlist: beta-first site, confirmed referral reward, #76 decisions made

User asked for one consistent waitlist with no conflicts, a free-license reward for 5 qualified referrals, and a cap of 100 for the beta. Decisions below were taken by the assistant on the user's instruction ("you can decide") and are recorded so they can be reversed.

- [x] `/waitlist` is the single canonical page (single goal, form first, shared honesty points, demo link; shows the download when a stable release exists). `/trial` and `/buy` are permanent redirects in `next.config.ts` that keep `utm_*` and `ref`. The native app still links to `/trial?utm_source=cmdtab-app`.
- [x] Reward: 5 qualified referrals earn one free license, reviewed by a person; capped at 100 earned+granted (`CMDTAB_REFERRAL_REWARD_CAP` overrides); overflow is `waitlisted` and promoted when a slot frees. One global advisory lock serialises decisions.
- [x] Abuse checks: confirmed email, Gmail/plus alias collapse, disposable-mail list, salted hashes of IP /24 (/64), browser device id and confirm-time network; same device/network as inviter or another invitee, or several signups per device, are flagged with a reason; missing signals fail closed.
- [x] D1 existing rows (owner decision): counted as confirmed. `ensureSchema` sets `confirmed_at = created_at` where both `confirmed_at` and `canonical_email` are null; every signup written by the new code sets `canonical_email`, so only pre-double-opt-in rows match. Idempotent. Production held only 5 test rows when checked.
- [x] D2 pending rows never count: dashboard aggregate reports `confirmed` and `unconfirmed`.
- [x] D3 unsubscribe (owner decision): deletes the row and keeps nothing, so no further email is sent. Signing up again later starts over as a new unconfirmed signup with a new confirmation email. No suppression table. Privacy policy updated.
- [x] D4 expiry: confirmation link 7 days; never-confirmed rows (link sent) purged after 30 days.
- [x] D5 marketing consent: optional unchecked box on the full form, version `2026-10-product-updates-v1`, effective on confirmation. No separate "updates only" unsubscribe yet.
- [ ] D6 bounces/complaints: **deferred**. Needs a signed Resend webhook endpoint and a new secret.
- [x] D7 fail closed: signup returns 503 unless the database, Resend and `WAITLIST_UNSUBSCRIBE_SECRET` are all configured. Production has `DATABASE_URL`, `RESEND_API_KEY`, `WAITLIST_FROM_EMAIL`, `WAITLIST_TO_EMAIL`, `WAITLIST_UNSUBSCRIBE_SECRET` and `REQUEST_FINGERPRINT_SECRET` (checked with `vercel env ls production`, names only).
- [x] D8 owner notification (owner decision): one per new signup, sent at submission and marked "awaiting email confirmation"; not sent for repeat submissions or alias spellings. A failed notice never changes the applicant response.
- [x] Terms: "Beta invite reward" section; FAQ entry; privacy policy rewritten for signals, consent, purge.
- [x] Client IP (security review finding): one shared `getClientIp` trusts `x-real-ip`/`x-forwarded-for` only when `VERCEL=1` (Vercel overwrites both headers; project exposes system env vars). Off Vercel every header is caller-controlled, including `x-vercel-id`, so the IP is "unknown". Replaces the copies in the waitlist, license-help and ingest paths.

Review: website tsc, 70 unit tests, 20 + 10 real-PostgreSQL scenarios (abuse rules, cap, race for the last slot, suppression, consent, purge), 13 offline end-to-end checks against the production build with a mock mail server (redirects, signup, confirm, owner notice, alias, flagged friend, unsubscribe + suppression, fail-closed), prebuild chain, production build, rendered-site, retrieval, evidence, showcase and Chrome browser checks (22 routes). Not covered: a real Resend send, `webmaster:check` (needs production `GOOGLE_SITE_VERIFICATION`), Vercel preview/production behaviour, bounce handling.

## 2026-10-10 — Flaky analytics rate-limit browser check

- [x] Root cause: the shared ingest limiter uses clock-aligned fixed windows; the browser check sent a fixed 130 requests, so a burst crossing a minute boundary split (e.g. 65 + 65) and never exceeded 120 in either window. Seen on run 37970231146.
- [x] Reproduced locally against Postgres: a boundary-straddling 130-request burst returned 130 × 204.
- [x] Fix (check only, limiter unchanged): send up to 2 × max + 1 requests, stopping at the first 429; read `max` from `src/lib/rate-limit.ts`; report an inconclusive burst if it takes ≥ 60 s.

Review: three boundary-straddling bursts now hit 429 (after 148, 123 and 195 requests). `browser:check` passed 3/3 against a local Postgres-backed server; `npm run prebuild` passes.

## 2026-10-10 — README status refresh and todo reconciliation

- [x] Read merged PRs #63–#69 (`gh pr view`) and replace README's stale 2026-09-25/27 header with a dated current-status paragraph, deploy prerequisites and open device checks.
- [x] Move superseded device history into README "Device acceptance history", keeping every evidence link.
- [x] Reconcile unchecked items below against files on `main` (7d0c9ef5). Checked only items with evidence in the repository; device-acceptance items stay open.

Review: docs-only change; no code, tests or deploys run. Items checked from evidence: 2026-09-23 tile identification and test/QA/package (both done in the 2026-09-25 work, `tasks/switcher-remediation-2026-09-25.md`); 2026-09-15 duplicate follow-up evidence, membership fix and regression (`tasks/duplicate-windows-2026-09-27.md`, `testLive500PointHelpersDoNotDuplicateVisibleAndMinimizedSiblings`). Left open with notes: AppKit geometry fix (not app-fixable so far), Phase H Developer ID packaging and release report, and every live/device check.

## 2026-10-09 — Licensing hardening (audit H1–H3, M3)

User chose a 30-day paid lease, CMDTAB1 exchange-only in release builds, and a salted hardware hash for trials. Commerce has never been enabled, so no customer migration is needed.

- [x] H1: paid CMDTAB2 tokens carry `exp = iat + 30d`; app renews via `/api/license/renew` (device-bound token is the credential; server checks active slot + not revoked); lapsed lease keeps token but grants nothing.
- [x] H1: deactivate/devices rate limited; deactivations capped at 3 per license per 30 days (`license_deactivation_events`).
- [x] H1: app tombstones keyed on signed claims (order|binding|iat), legacy byte keys still honoured.
- [x] H2: release builds never unlock from a stored CMDTAB1 key or offline activation; CMDTAB1 is only an online-activation input.
- [x] H3: trial start sends salted SHA-256 of IOPlatformUUID; server keeps one claim per hardware hash and rebinds a reset install to the original dates.
- [x] H3: missing `trialLastSeen` falls back to the claim's server-validated time for rollback detection.
- [x] M3: activation codes derived via HMAC(pepper, order, generation); plaintext scrubbed from fulfillments and delivered outbox rows; recovery rotates the code.
- [x] Privacy policy line for the hardware hash; README licensing notes.

Review: website tsc, unit 51+10, verify-api-security (new licensing assertions), verify-seo and production build pass. Swift: 421 XCTest pass (5 new hardening tests), release configuration builds. Not covered: routes/DB stores have no automated tests (existing gap); no live KMS/Postgres run of `/api/license/renew`.

## 2026-09-26 — Approved complete inventory and preview coverage

User approved implementation of this plan; preserve unrelated work and installation defaults.

- [x] Enable minimized windows in this installation’s global and two standard profiles; preserve custom profiles/exclusions.
- [ ] Stabilize installed launch path and verify permission persistence across identical-binary restarts; report certificate-backed update-signing constraint.
- [x] Reconcile complete exact-window inventory before publication and remove redundant process fallbacks.
- [x] Present accurate application-only, pending, permission-denied, unavailable and saved-preview states.
- [x] Retain verified live minimized thumbnails with original timestamps, AX/process identity validation, 128 MiB LRU and downscaled images.
- [x] Exercise 24-window asynchronous publication plus cold/minimized/partial-AX/identity/permission/profile regressions.
- [x] Run focused/full Swift tests and independent QA/QC.
- [ ] Package and launch exact verified binary; reconcile live inventory and permissions.
- [ ] Retest standalone AppKit geometry reproduction and prepare unsubmitted Apple feedback if persistent.
- [ ] Record evidence, remaining unavailable captures, and acceptance limits in README.

Review:343 XCTest +2 Swift Testing passed; independent scoped QA cleared all P0/P1/P2. Persistent universal local app installed and login registration moved. System authentication remains pending before replacement authorization, identical-binary restart and live inventory checks. No permission persistence or complete device acceptance claim yet.

## 2026-09-25 — Authorized permissions and AppKit geometry follow-up

User authorized enabling Accessibility/Screen Recording and resolving geometry faults.

- [x] Enable permissions for exact corrected artifact and verify in-app readiness.
- [x] Identify faulting AppKit window/geometry with runtime evidence and independent native reproduction.
- [ ] Resolve native sharing-indicator fault: reproduced without CmdTab; no supported app-side fix demonstrated.
- [x] Compile/lint independent fixture and rerun live permission/preview checks; production executable unchanged from319-test verified build.
- [x] Complete independent follow-up QA: exact artifact/hash and six-fault independent AppKit reproduction confirmed; geometry remains unresolved.
- [x] Record actual final runtime results and residual limitations.

## 2026-09-25 — Persistent duplicate entries and missing thumbnails

- [x] Reproduce on the authorized running bundle and bind helper/preview findings to exact window identities.
- [x] Correct shared membership and preview recovery defects with focused regression tests; preserve real sibling windows.
- [x] Run full Swift tests, independent QA/QC, and package the corrected local app.
- [ ] Validate live behavior and record remaining device limitations without overstating acceptance.

Sept25 review: 317 XCTest + 2 Swift Testing passed; universal ad-hoc packaging passed; independent code review has no unresolved scoped P0/P1/P2. Corrected build launched, but both macOS permissions require reauthorization (approval pending). AppKit sharing-indicator faults persist. Live acceptance is not complete.

## 2026-09-23 — Remaining device defects

- [x] Identify remaining icon-only and helper tiles using exact window evidence; preserve legitimate multiple windows and app-only fallbacks. (Done 2026-09-25: helper findings bound to exact window identities; see `tasks/switcher-remediation-2026-09-25.md`.)
- [ ] Trace and fix AppKit layout faults with targeted regression coverage. (Traced 2026-09-25 to the native sharing indicator and reproduced without CmdTab; no app-side fix. See `Tests/Fixtures/AppKitSharingGeometry/README.md`.)
- [x] Run focused/full tests, independent QA, and package a corrected local build. (Done 2026-09-25: 317 XCTest + 2 Swift Testing, independent QA, universal ad-hoc package.)
- [ ] Retest live membership/previews/settings; report permission or runtime blockers explicitly.

## 2026-09-17 — AltTab thumbnail audit and integration

2026-09-23 device delta: authorized permission entry removal/re-add plus restart succeeded (PID 25401, checksums4/4). Screen Recording/Accessibility Ready; 12 previews and 6 unavailable. Visual thumbnails confirmed. Remaining: icon-only windows, Chrome suggestion surface, extra Cisco icon-only entry, AppKit geometry faults. Cisco main/dialog are distinct valid captures. No app files or unrelated permission entries removed.

Permission retry: user-authorized off/on toggle and Quit & Reopen completed; new PID 73343 still reports Screen Recording Required and 0 previews / 24 unavailable despite the enabled OS toggle. No permission entry removed or database reset performed. Live acceptance remains blocked.

Device follow-up: final QA artifact identity confirmed; switcher reproduced icon-only tiles and repeated app labels. Diagnostics show zero previews and Screen Recording Required while System Settings toggle is on; current process logs capture authorization error -3801 and AppKit geometry faults. Live acceptance FAILS. Permission changes require user confirmation; duplicate exact-window identity remains unverified.

User confirmed work in this checkout while preserving existing changes.

- [x] Compare pinned upstream AltTab capture, refresh and fallback behavior with CmdTab; record source and license boundaries.
- [x] Fix demonstrated thumbnail recovery gaps without changing window membership, activation or MRU.
- [x] Verify focused regressions, build and full suite; independently review the changes.
- [x] Record actual runtime evidence and any permission-dependent acceptance limits in README.
- [ ] Verify live thumbnail freshness and fullscreen/other-Space windows in the rebuilt app with Screen Recording and Accessibility authorized.

Review (2026-09-20): final source passed 308 XCTest + 2 Swift Testing tests; six new focused regressions. Independent QA findings were corrected and rereviewed with zero unresolved P0/P1/P2 findings. Running app unchanged; see `tasks/alttab-thumbnail-audit-2026-09-17.md` for evidence and limits.

## 2026-09-15 — Duplicate icon-only windows follow-up

- [x] Capture live window identity evidence; distinguish fallback duplication from real/helper CG surfaces. (Done 2026-09-27: read-only CG/AX inventory in `tasks/duplicate-windows-2026-09-27.md`.)
- [x] Correct the shared membership cause without hiding legitimate windows or depending on preview success. (Done 2026-09-27: `AppSwitcher.swift` helper rejection uses AX sibling evidence, not names or capture success.)
- [x] Add end-to-end regression coverage for the reproduced case and adjacent merge paths. (Done: `UnknownCGSurfaceMembershipTests`, including the observed helper/real pairs.)
- [ ] Run focused/full tests, package, inspect live behavior, and independent QA; document remaining limits. (Tests, package and QA recorded 2026-09-27; live inspection is a user device check, left open.)

---

## 2026-09-15 — Comprehensive switcher discovery and previews

User authorized implementation of the reviewed audit. Preserve unrelated dirty work.

- [x] Repair final all-Spaces app coverage and stale AX suppression without bypassing explicit filters or changing MRU/activation semantics.
- [x] Refresh enrichment on stale metadata even when base identities are unchanged; add deterministic cold-membership coverage.
- [x] Normalize capture pixels for validation/cropping; regress byte order, opaque/no-alpha, transparent, black, and valid dark frames.
- [x] Make classic-grid overflow discoverable; retain existing card layout and centering.
- [x] Run focused tests, full SwiftPM suite, build/package verification; report environmental blockers accurately.
- [x] Independent QA/QC, resolve scoped code findings, update README with actual evidence.
- [ ] Complete live pre-activation inventory/thumbnail verification after macOS permission reauthorization.

### Review
36 focused tests and 292 full-suite tests passed. Universal package verification and launch passed. Independent scoped code QA found no actionable issues. Live switcher acceptance remains blocked: the rebuilt ad-hoc app requires Accessibility/Screen Recording reauthorization. Existing Settings geometry faults remain separately recorded. See `tasks/switcher-discovery-implementation-2026-09-15.md`.

---

# Todo

## 2026-09-11 — Minimized Window & Thumbnail Continuity Remediation

- [x] Remove "Preview unavailable" error text from `ClassicGridView.swift`; present application fallbacks cleanly and show minimized status badges.
- [x] Align synthetic preview cache keys in `ProductionAppSwitcher.swift` with `AppSwitcher.previewCacheKey` to restore continuity caching across window minimization.
- [x] Support `includeMinimized` in `AppSwitcher.shouldAllowAXWindow` and candidate inspection so minimized windows are not marked as `positivelyDisallowedIDs`.
- [x] Add regression tests for `shouldAllowAXWindow` with `includeMinimized: true`.
- [x] Verify build and test suite (`swift build` and `./build.sh` universal release packaging passed).

## 2026-09-09 — Truth, Reliability & Release Remediation (P-1)

- [x] Record repository identity and inspect the dirty implementation before additional source edits: `tasks/audit-repository-identity-2026-09-09.md`.
- [x] Reconcile all claimed fixes against current source using `CLAIMED / PRESENT / ABSENT / PARTIAL` states.
- [x] Replace the remaining frontmost-path AX allowlist with positive-only exclusion semantics and focused regression coverage.
- [x] Compile-time exclude all public-release developer/test entitlement controls; reconcile Cmd-Q regression expectation with product behavior.
- [x] Add a fail-closed candidate-evidence receipt binding requested SHA/branch, clean state, ReleaseConfig digest, full artifact digest, test commands/results, and host OS/architecture.
- [x] Audit independent beta entitlement readiness and preserve the explicit external blocker pending safe trial-only configuration/keyring work.
- [x] Run independent QA/QC and update this review with exact verification/blockers.

### Continued P0 work

- [x] Remove exact-window sibling fallback: an exact selection now raises only an AX window with the selected CGWindowID; stale/unmapped targets retry then record a non-exact outcome without MRU mutation.
- [x] Correct membership diagnostics so only exact AX exclusions count as such, and add the complete P0.5 matrices.

  - QA caught and the follow-up fixed AX-omitted layer-1/2 candidates being excluded despite the normal Core Graphics filter accepting layers 0...2. Regressions now cover both layers.

### Private capability boundary and OS canary (P0.13)

- [x] Replace direct private AX identity, SkyLight capture, and SkyLight focus symbol resolution in `AppSwitcher` with narrow status-bearing providers.
- [x] Keep Core Graphics membership fail-open when identity/capture capability is unavailable, and make exact-focus degradation non-exact/non-MRU-success.
- [x] Surface identity, capture, focus, and workspace capability reasons in sanitized diagnostics; add fake-provider regressions.
- [x] Add a candidate-bound physical macOS 14/15 private-capability canary schema, validator, and authorized-Mac procedure; do not represent CI/source checks as physical acceptance.
- [x] Run source-level QA/QC and record source evidence separately from the required physical receipts.

  - `PrivateWindowCapabilities.swift` is the sole private-symbol resolver for exact AX identity, SkyLight preview capture, and SkyLight exact focus. `AXWindowIdentityLookup` delegates to it, so catalog, focus history, and actions use the same identity bridge.
  - QA caught and the follow-up fixed a fail-closed evidence contradiction: a wrong-sibling or stale-preview failure is now retained as a candidate-bound `blocked` receipt, while an `observed` receipt rejects those counters. The duplicate CI canary-test call was removed; independent QA re-review found no remaining issue. `swift build --scratch-path /tmp/CmdTab-private-capability-build`, `swiftc -parse` of changed source/tests, private-canary tests (7/7), release pipeline tests (19/19), JSON-schema parsing, and `git diff --check` passed. Native XCTest execution remains host-blocked by Command Line Tools lacking `XCTest`.
  - A local universal `./build.sh` package attempt is unproven on this host: the execution environment terminates its whole-module release compiler before it emits a new bundle. The existing `CmdTab.app` therefore must not be treated as containing this P0.13 work.
  - Physical canary receipts for macOS 14 and 15 on the signed candidate remain **UNPROVEN**. The validator binds the retained archive and separately installed observed app bundle to the clean candidate; it does not grant acceptance merely by parsing a receipt.

### Beta trial readiness correction (P0.10)

- [x] Split trial KMS signer loading from paid-license KMS configuration.
- [x] Add a fail-closed beta-trial readiness verifier that has no checkout or paid-commerce prerequisites.
- [x] Validate and inject only the public trial keyring into a release Info.plist; never accept private material.
- [x] Add focused verifier/configuration regressions and run scoped checks.

  - Independent QA found that deterministic release CI did not invoke the new Node verifier tests. The release-configuration workflow now triggers for the beta-verifier paths and runs `node --test website/tests/beta-trial-readiness.test.mjs`.

  - Public beta declares `commerceEnabled: false`; the generated Info.plist hides Buy and paid activation presentation while preserving verification of existing paid entitlements.

### Review

- `AppSwitcher` no longer has legacy `allowedWindowIDsByPID` helpers: frontmost identity now uses positive mapped AX rejection and leaves AX omissions included.
- `DeveloperSettings` and runtime licensing overrides are DEBUG-only. The release initializer accepts no developer-state type; its inert compatibility argument is only cast under DEBUG. Cmd-Q's focused test now matches owning-app termination.
- `scripts/release/candidate-evidence.py` records/verifies a clean requested SHA and branch, config/artifact SHA-256s, build/test result hashes, and host OS/architecture. `prepare-release-publication.sh` now requires that verified receipt.
- Reconciled stale source-contract verifiers with the centralized private-capability provider and simplified menu. `verify-five-feature-source.py` now enforces the provider boundary (and rejects direct private loading in `AppSwitcher`); `verify-five-feature-audit-fixes.py` enforces the reduced menu. Both pass.
- `swift build --scratch-path /tmp/CmdTab-truth-remediation-build` completed after the release-control syntax correction; Python compilation and shell syntax checks for candidate evidence/publication passed; `git diff --check` passed.
- Independent QA/QC found and corrected one P1: the cached/provisional ghost suppression bypass (earlier task) and beta-verifier CI wiring in this P-1 task. Deterministic verification passed: release pipeline 19/19, beta readiness 4/4, release identity/control checks, Swift parsing, shell syntax, Python compilation, and `git diff --check`. `swift build --scratch-path /tmp/CmdTab-beta-trial-build` passed. XCTest compilation is host-blocked by Command Line Tools lacking the XCTest module, not by a reported source regression.
- Independent fresh-user beta entitlement remains **BLOCKED** pending deployed trial-only KMS/OIDC/keyring configuration and authorized clean-Mac evidence; paid-commerce configuration is not a beta-trial prerequisite.

## 2026-09-09 — Ghost Window Reconciliation

- [x] Capture live PDFgear evidence for duplicate tiles and identify the real AX-standard document versus AX-unknown off-space surfaces.
- [x] Make enrichment drop unmatched Core Graphics exact-window items only for processes whose AX enumeration is complete and has resolved windows.
- [x] Add focused policy regressions for complete AX catalogs, AX identity gaps, app fallbacks, and cached/provisional merge reinsertion.
- [x] Rebuild and restart the app; manual screen confirmation remains with the active desktop session.

### Review
- Live WindowProbe evidence: PDFgear's real document was AX-standard, focused, and onscreen; its off-space `Welcome` surface was an AX-unknown Core Graphics window. The old enrichment path retained that ghost because the profile permits all Spaces.
- The final policy suppresses only unmatched exact windows for AX-complete processes with no unresolved AX identities and at least one resolved AX window. AX-unavailable/incomplete processes and app fallbacks remain fail-open.
- `swift build --scratch-path /tmp/CmdTab-ghost-window-build-qa`, `./build.sh`, deep/strict codesign verification, and `git diff --check` passed. The fresh app executable is timestamped 2026-09-09 10:14:49 and restarted as PID 91598.
- Independent QA/QC initially caught a cached/provisional merge reinsertion bypass. The correction carries the suppression identity through both merge paths; re-review found no P1/P2 issues.
- XCTest execution remains unavailable on this Command Line Tools-only host (`no such module 'XCTest'`).

## 2026-09-09 — Per-window Preview Recovery

- [x] Trace why individual eligible windows render `Preview unavailable` despite successful previews elsewhere in the same switcher session.
- [x] Remove only the premature non-shareable-window capture rejection; retain blank/black-frame validation and the existing ScreenCaptureKit recovery path.
- [x] Compile and package the fix, then restart the local app.
- [ ] Manually verify preview recovery on the affected desktop; protected/DRM content and genuinely near-uniform black frames may still use the safe placeholder.

### Review
- The affected screen proves Screen Recording is not globally denied: previews from the same owners succeed. The immediate pipeline incorrectly skipped candidates with `kCGWindowSharingState == 0`, although deferred ScreenCaptureKit recovery already attempted them.
- `swift build --scratch-path /tmp/CmdTab-preview-fix-build`, `./build.sh`, deep/strict codesign verification, and `git diff --check` passed. The fresh executable is timestamped 2026-09-09 09:57:53 and the restarted process is PID 79288.
- Independent QA/QC found no P1/P2 source-level regression: the existing SkyLight-to-Core-Graphics fallback chain, cache fallback, deferred recovery, and protected/blank-frame rejection remain intact.
- XCTest remains unavailable in this Command Line Tools-only host (`no such module 'XCTest'`), so visual acceptance is explicitly still pending.

## 2026-09-09 — Local Startup Crash Remediation

- [x] Identify the `CmdTab.SearchMemoryStore` same-queue `dispatch_sync` launch crash from the macOS crash report.
- [x] Persist migrated legacy search-memory data directly during initialization; normalize before hashing and discard blank keys.
- [x] Add a regression for normalized legacy-key migration; rebuild the universal local app and verify a freshly restarted process remains running.

### Review
- `swift build --scratch-path /tmp/CmdTab-startup-fix-build` passed.
- `./build.sh` produced a new `CmdTab.app` executable timestamped 2026-09-09 09:44:25; a fresh launch remained running as PID 72590.
- Independent QA/QC found the stale-bundle evidence issue before repackaging; source review found no queue re-entry. `git diff --check` passed.
- Focused XCTest execution remains unproven on this host because Command Line Tools lacks the XCTest module.

## 2026-09-09 — Public-Beta Release Blocker Remediation

### Ordered implementation and evidence gates
- [x] 1. Replace palette CGEvent text reconstruction with a native focused NSSearchField; retain only explicit navigation/commit commands.
- [x] 2. Classify exact-window activation outcomes and prevent fallback activations from committing exact MRU success.
- [x] 3. Make `ReleaseConfig.json` channel-authoritative; configure the dedicated beta appcast and fail closed on channel drift.
- [x] 4. Harden Developer ID/notarization tooling, canonicalize entitlements, and retain signed-artifact evidence.
- [x] 5. Split deterministic CI validation from interactive release gates; expand physical performance/soak reason codes and thresholds.
- [x] 6. Publish authorized-Mac validation procedures and an evidence-bound release matrix; retain `BLOCKED` until external receipts exist.
- [x] 7. Run scoped regression tests, full SwiftPM verification, release pipeline checks, and an independent QA/QC review.

### Review
- `swift build --scratch-path /tmp/CmdTab-release-blocker-build-qa` passed.
- Release pipeline tests passed: 16/16; performance-evidence tests passed: 12/12; shell syntax, Python compilation, release identity validation, and `git diff --check` passed.
- `swift test --scratch-path /tmp/CmdTab-release-blocker-test --filter ActivationOutcomeTests` could not compile existing XCTest-based targets because the host Command Line Tools environment reports `no such module 'XCTest'`.
- Independent QA/QC closed three P1 gaps: terminal exact-activation accounting, performance activation-counter receipts/reconciliation, and mandatory notarization profile for release-labelled packaging. No P1/P2 findings remain in the reviewed scope.

## 2026-09-09 — Reliability, UX Simplification, and Beta-Readiness Mission

### Phase B — Membership and Activation (P0.1, P0.2, P0.3, P1.7)
- [x] 1. Core Graphics establishes candidate membership; AX only positively excludes or enriches (P0.1).
- [x] 2. Add privacy-safe snapshot diagnostic counters (candidates, rejections, fallbacks, AX matches) (P0.1).
- [x] 3. Precisely define and centralize Application Eligibility Policy (.regular foreground macOS applications) (P0.2).
- [x] 4. Audit exact-window (PID, CGWindowID) activation path and minimized window restoration (P0.3).
- [x] 5. Restore standard ⌘W (close window) and ⌘Q (quit owning application) semantics across exact and fallback items (P1.7).

### Phase C — Preview Pipeline & Deployment Target (P0.4)
- [x] 6. Raise platform deployment target to macOS 14.0+ in Package.swift (P0.4).
- [x] 7. Ensure strict fallback hierarchy: live -> cached exact -> app icon -> "Preview unavailable" text (P0.4).
- [x] 8. Verify stale-generation write protection during asynchronous preview capture (P0.4).

### Phase D — Lifecycle, Termination & Beta Access (P0.7, P0.8, P1.9)
- [x] 9. Fix applicationShouldTerminate so standard Quit/logout/reboot works cleanly without blocking (P0.7).
- [x] 10. Decouple TRIAL_READY from COMMERCE_READY for seamless offline public beta trial registration (P0.8).
- [x] 11. Update update channel copy to "Beta Updates" and "Check for Beta Updates" (P1.9).

### Phase E — Performance and Instrumentation (P0.6)
- [x] 12. Instrument Phase 1 vs Phase 2 timings and verify warm reveal p50 <= 80ms / p95 <= 150ms non-blocking behavior (P0.6).

### Phase F — Simplification (P1.1, P1.2, P1.3, P1.4, P1.5, P1.6, P1.8, P1.10)
- [x] 13. Gate Developer preferences pane behind #if DEBUG in PreferencesView and selection enum (P1.1).
- [x] 14. Restructure Settings into Appearance, Windows, Shortcuts, General, License (P1.2).
- [x] 15. Simplify profiles: ⌘Tab default experience with "Advanced Profiles…" button (P1.3).
- [x] 16. Streamline Menu Bar to: Status, Settings, Check for Beta Updates, Help/Diagnostics, Quit (P1.4).
- [x] 17. Remove alarming WorkspaceCapabilityBanner from switcher overlay and route to Diagnostics (P1.5).
- [x] 18. Remove permanent "Right-click for window actions" capsule badge from ProfileSwitcherView (P1.6).
- [x] 19. Clarify Screen Recording as optional and explain Secure Input pause in plain English (P1.8).
- [x] 20. Rewrite onboarding copy to eliminate internal engineering jargon (P1.10).

### Phase G — Input, Privacy and Accessibility (P2.1, P2.2, P2.3)
- [x] 21. Implement native text input for Command Palette supporting IME, dead keys, accents, and paste (P2.1).
- [x] 22. Protect search memory: SHA-256 hash queries in SearchMemoryStore, provide reset button, migrate plaintext (P2.2).
- [x] 23. Perform accessibility audit: attach proper semantic roles and VoiceOver labels (P2.3).

### Phase H — Release Verification
- [x] 24. Full compilation and verification: swift build (0 errors/warnings).
- [ ] 25. Package release app bundle via ./build.sh and verify manifest/signatures. (Local ad-hoc packaging verified repeatedly; Developer ID signing is still blocked, so left open.)
- [ ] 26. Final deliverable report with formal Release Recommendation.
- [x] 1. Protect `lastRefresh`, `isRefreshing`, and `pendingForcedRefresh` under `cacheLock` in `AppSwitcher.swift`.
- [x] 2. Implement process termination cleanup and validation for `launchTokensByPID` in `SwitcherItem.swift`.
- [x] 3. Tighten layer-0 fallback window bounds check in `AppSwitcher.isAllowedWindowID`.
- [x] 4. Build and verify via `swift build` and `./build.sh`.

## 2026-09-08 — Resolution of Core Switcher, Hot Swap, and MRU Ordering Defects

### Hot Swap Accidental Trigger
- [x] 1. Update `AlternateModifierTriggerState` in `HotkeyStateModels.swift` to record active chord press on modifier key-down and trigger only on key-up within 280ms if uninterrupted.
- [x] 2. Ensure intervening key-downs (`noteInterveningKeyDown`) mark the active chord press as interrupted to prevent accidental firing during `⌘⌥C`, `⌘⌥V`, etc.
- [x] 3. Add/update tests in `ProfileHotkeyTimingTests.swift` and `ProductionHotSwapPolicyTests.swift` covering chord release and intervening key interruption.

### MRU Recency Ordering Consistency
- [x] 4. Update `AppSwitcher.swift` candidate sort scoring to remove artificial area and visibility weight from unranked candidates.
- [x] 5. Update `SwitcherOrdering.orderedItems` in `SwitcherHistory.swift` to strictly preserve exact MRU order and append unranked items by system z-order (`orderIndex`) without app fallback rank inheritance.
- [x] 6. Add/update tests verifying pure MRU rank and unranked z-order determinism.

### Core Switcher & Thumbnail Reliability (Defects 1–8)
- [x] 7. Fix stale enriched cache in `ProductionAppSwitcher.swift:getItems()` (Defect 1, P0) to merge fresh items from `baseItems` immediately.
- [x] 8. Relax AX allowlist in `AppSwitcher.swift:isAllowedWindowID` (Defect 2, P0) so valid standard CG windows are not rejected if AX enumeration is partial.
- [x] 9. Add pending forced refresh replay in `AppSwitcher.swift:refreshCacheIfNeeded` (Defect 3, P1).
- [x] 10. Keep `kCGWindowSharingState == 0` windows in `AppSwitcher.swift:makeCandidate` (Defect 4, P1) with icon fallback rather than dropping them.
- [x] 11. Stabilize `launchDate` token in `SwitcherItem.swift:previewContinuityIdentityKey` (Defect 5, P1).
- [x] 12. Expand black-frame sampling grid in `AppSwitcher.swift:isImageEffectivelyBlack` (Defect 6, P1) and extend `maximumPhaseTwoFallbackAge` to 120s.
- [x] 13. Add bounded fast retries in `ReliableWindowPreviewRecovery.swift` (Defect 7, P1).
- [x] 14. Replace skeleton placeholder in `ClassicGridView.swift` with centered app icon on subtle translucent card (Defect 8, P2).

### Verification & Validation
- [x] 15. Run test suite: `swift build --scratch-path /tmp/CmdTab-build` passed with 0 errors / 0 warnings across all 76 targets.
- [x] 16. Build release bundle: `./build.sh` built universal `arm64 + x86_64` bundle at `CmdTab.app` with ad-hoc code signature and verified manifest.

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

---

## Step 1: Command-Tab interception fix (2026-10-09)

- [x] Remove the 160 ms / interrupted-chord gate; any matching key-down starts a session like native Command-Tab (user decision; contract doc revised)
- [x] Extra deliberate Tabs before the reveal advance the selection (quick switch and reveal); key repeat does not
- [x] Pass-through returns `passUnretained` (was leaking every event)
- [x] Licensing gate uses the last status verified in-process; pending Keychain reads and stale snapshots no longer turn Command-Tab off; shortcut sessions no longer re-run a synchronous Keychain refresh in `startSession`
- [x] Side-specific modifier state read from device flag bits instead of toggling
- [x] Key-ups of keys consumed by the visible switcher are swallowed
- [x] Event timestamps converted unit-agnostically (ns or mach ticks; 0 falls back to now)
- [x] A visible hold session whose release owner is cancelled closes instead of sticking
- [x] Process-wide 0.25 s Accessibility messaging timeout

Review: `swift test` (Xcode-beta) 404 XCTest + 2 Swift Testing; only the pre-existing, host-permission-dependent `testTwentyFourAsynchronousRecoveriesPublishBeyondFirstEight` fails (unchanged). Not yet verified on device.

Follow-up (not done): run the event tap on a dedicated thread with thread-safe switcher/licensing snapshots, and move activation/enumeration AX work off main. Needs packaged-app device testing.

## Step 1b: event tap on a dedicated thread (2026-10-09)

Goal: keystrokes system-wide never wait on CmdTab's main thread (AX, inventory, capture, UI).

- [x] Dedicated high-priority thread owns the tap's CFRunLoop; install/uninstall add/remove the source there
- [x] One recursive lock guards all router state; main-originated entry points (watchdog, click commit, reveal timer, post-show check, timing actions) take it; nothing waits on main while holding it
- [x] Thread-safe mirrors for main-only state: switcher visibility/pending/profile/style, licensing gate snapshot, CmdTab text-input focus, alternate trigger mode
- [x] Live modifier state from `CGEventSource.flagsState` instead of `NSEvent.modifierFlags`
- [x] Tests: licensing gate snapshot, input mirror; full suite; packaged-app check by user

Review (1b): 407 XCTest + 2 Swift Testing; only the known host-permission-dependent preview test fails. Installed at ~/Applications/CmdTab.app and launches without crashing; live tap behaviour awaits the user's permission re-grant.
