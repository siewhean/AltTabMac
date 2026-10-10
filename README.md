# CmdTab

Website update (2026-10-10, branch `feat/beta-first-referral-loop`, uncommitted): beta-first homepage (hero with inline email capture, restored in-browser demo, closing beta section) and a referral reward: **5 qualified referrals earn a free CmdTab license**, granted manually after review (no queue). A referral counts only after the friend confirms their email (signed link, `/api/waitlist/confirm`) and passes device/network checks (salted hashes of IP /24, a browser device id and the confirm-time network; Gmail alias, disposable-mail and shared-device/network detection; flagged cases keep a reason for review; hashes deleted after 90 days unless flagged). Campaign labels are still stored only with analytics consent. Verified: typecheck, 70 unit tests, 20 real-PostgreSQL referral/abuse scenarios, HTTP tests of the confirm endpoint, prebuild chain, production build, rendered-site, retrieval, evidence, showcase and Chrome browser checks. Not verified: a live signup through Resend, `webmaster:check` (needs production `GOOGLE_SITE_VERIFICATION`). Waitlist conflicts with PR #52, PR #76 and `codex/marketing-waitlist-readiness`: [`marketing/05-waitlist-conflicts.md`](marketing/05-waitlist-conflicts.md). Marketing kit: [`marketing/`](marketing/00-diagnosis-and-30-day-plan.md).

Current implementation (2026-09-27): complete inventory publication, minimized-window inclusion for this installation’s global/standard profiles, explicit preview states, identity-validated saved previews, and bounded thumbnail/recovery storage are implemented. **343 XCTest + 2 Swift Testing tests pass**; independent scoped QA reports zero unresolved P0/P1/P2 findings. The verified universal local build is installed at `/Users/Siew Hean/Applications/CmdTab.app` (executable SHA256 `53ac23c2c8b55ab14227daa7734f56803376f7746a3a9308d3e26d37056c3100`). Launch-at-login was disabled on the repository copy and enabled on this persistent copy. Final permission authorization currently awaits the user’s Touch ID/password; identical-binary restart and live all-window acceptance are **not yet verified**. This host now runs macOS27.2 (26B5091g), so prior26.6 geometry results are historical. Ad-hoc signatures change on rebuild; no certificate-backed signing identity is installed, so future-build permission continuity is not established. See [current evidence](tasks/window-coverage-2026-09-27.md).
**Current status (2026-10-10).** Covers `main` through `7d0c9ef5` (merge of PR #69); later merges are not summarized here. PRs #63–#69 merged on 2026-10-09; results below are each PR's own reported checks, not re-run for this note:

- #63 prerenders 33 marketing routes for CDN caching. Static pages use a static CSP (`'self'` plus `'unsafe-inline'` scripts); `/dashboard` keeps the per-request nonce policy.
- #64 adds a waitlist privacy notice and HMAC-signed one-click unsubscribe (RFC 8058 headers; GET never deletes).
- #65 hardens licensing (audit H1–H3, M3): paid `CMDTAB2` tokens are a 30-day lease renewed via `/api/license/renew`; release builds accept `CMDTAB1` only as online-activation input; one trial per Mac via a salted hardware hash; activation codes are stored only as hashes.
- #66 keys rate-limit fingerprints with HMAC, adds image `Cache-Control`, skips placeholder trial-reminder addresses, and discloses the Mac name sent on activation.
- #67 makes `cmdtab://activate` links prefill the code; nothing changes until the user clicks **Activate** (audit L2).
- #68 accepts admin mutations only from the configured origin in production (L1) and enforces trial/license KMS key separation plus a published-keyring match before signing (L3).
- #69 matches windows to displays in Core Graphics coordinates (`DisplayGeometry.swift`) for the current-display filter and selected-window backdrop.

Latest reported Swift result: 425 tests pass and `swift build -c release` passes (PR #69). Outstanding, not verified here:

- Deploy prerequisites named by the PRs: `WAITLIST_UNSUBSCRIBE_SECRET` (#64) and `REQUEST_FINGERPRINT_SECRET` (#66) in Vercel Production. Per #68, production has no KMS signing configuration and still holds `CMDTAB_LICENSE_PRIVATE_KEY_PEM`, which must be removed when KMS is configured.
- Paid licensing needs an app release that contains #65; older builds reject leased tokens. Commerce remains disabled (`commerceEnabled: false`).
- Device acceptance requires the user: #69 is not yet checked on real multi-display hardware, and the dedicated-thread event-tap build installed at `~/Applications/CmdTab.app` launches but its live tap behaviour awaits a permission re-grant ([tasks/todo.md](tasks/todo.md), Step 1b). Developer ID signing and notarization remain release gates (see [Production-readiness plan](#production-readiness-plan)).

Last updated: 2026-10-10
Active task: none in progress in the repository. Next steps are the user-run device checks and deploy configuration above. Earlier device results are condensed in [Device acceptance history](#device-acceptance-history).

P-1 audit (2026-09-09):
The source-of-truth audit is recorded in
[`tasks/audit-repository-identity-2026-09-09.md`](tasks/audit-repository-identity-2026-09-09.md).
Private AX identity, SkyLight capture, and exact-focus calls are centralized in
one status-bearing capability provider. Its unavailable exact-focus path is
recorded as application-only fallback rather than exact MRU success; the
macOS 14/15 canary procedure remains physical-only evidence.
It recorded that the then-active worktree was dirty and behind `origin/main`,
so it was not a release candidate. Candidate evidence now must bind a clean requested
SHA, branch, release-config hash, artifact hash, command results, and host
identity. Fresh-user beta entitlement remains blocked until trial-only signing,
OIDC deployment identity, and the beta trial public keyring are provisioned and
verified. Public beta explicitly disables commerce presentation; existing
verified paid entitlements remain honored. Deterministic release CI also runs
the beta-trial readiness regressions whenever their verifier or KMS source
changes. The regenerated public-beta matrix labels only repository evidence as
`PASS (source)`; the then-current dirty, behind-upstream worktree is explicitly a
failed release-candidate row. GitHub has no CmdTab workflow result for that
candidate SHA, so unrelated successful runs are not represented as CI evidence.
This host also has no Developer ID identity or CmdTab notary profile, so release
packaging rejects before build as designed.

Commerce stays fail-closed unless `CMDTAB_REQUIRE_COMMERCE_READY=1` is set
with the complete database, Lemon Squeezy, email, and KMS configuration; the
public website remains waitlist-first.

## Product

CmdTab is a native macOS window switcher built with Swift, AppKit, and SwiftUI. Eligible top-level windows are separate exact `(PID, CGWindowID)` targets in one global recent-use sequence. Multiple windows from one app remain separate, preview failure changes presentation rather than membership, and permanent history updates only after activation is confirmed.

The repository also contains the Next.js product, documentation, commerce, analytics, evidence, and discovery website under `website/`.

## Production-readiness plan

The canonical phased plan is [`docs/release/native-production-readiness-plan.md`](docs/release/native-production-readiness-plan.md). The active execution sequence and current phase status are recorded in [`docs/release/current-implementation-status.md`](docs/release/current-implementation-status.md).

Phase 1 is complete. PR #31 merged the deterministic local application bundle, permanent bundle identifier, rollback-safe beta migration, local ad-hoc QA package, strict bundle verification, checksums, and byte-for-byte unsigned reproducibility.

The public native release remains blocked until CmdTab has:

- Developer ID signing with Hardened Runtime and a secure timestamp;
- accepted notarization and a stapled ticket;
- Gatekeeper and clean-account installation evidence;
- real macOS proof of exact focused-window activation across the supported desktop matrix;
- private API capability boundaries with explicit degraded behavior;
- tested update, rollback, diagnostics, security, licensing, and support operations.

No public release claim may treat the accepted local ad-hoc artifact as a distributable build.

The licensing migration now includes an additive `CMDTAB2` P-256
token/keyring contract and separate trial/license AWS KMS signer abstraction.
Release builds accept a `CMDTAB1` key only as input to online activation,
which exchanges it for a device-bound `CMDTAB2` lease;
production KMS provisioning and embedding its public keyrings in the signed
app remain release gates.

The repository-owned commerce lifecycle now exchanges a high-entropy opaque
purchase activation code for an install-bound signed entitlement, and
transactionally limits each license to three named Macs. Paid entitlements are
a 30-day lease the app renews online (`/api/license/renew`), so refunds and
remote deactivation reach offline Macs within a month. Deactivation frees a
slot immediately but is capped at three per license per 30 days; activation
codes are derived, never stored in plaintext, and recovery rotates them; trials
are limited to one per Mac via a salted hardware hash; recovery is
enumeration-safe; fulfillment uses a retryable outbox; partial refunds preserve
access; and authoritative full-refund or revocation states persist as hashed
tombstones. The migration is idempotent and local real-PostgreSQL concurrency
evidence covers three successful devices, fourth-device rejection, immediate
deactivation, and subsequent activation. Automated licensing coverage
(2026-10-10, `npm run test:licensing`, part of `test:unit`): route handlers for
activate, renew, deactivate, devices, recovery, trial start, and the Lemon
Squeezy webhook run in-process with faked stores, signers, and rate limiters;
store SQL for the deactivation cap, renewal lookup, and trial hardware
rebinding runs against a disposable local Postgres only when
`CMDTAB_TEST_DATABASE_URL` is set (skipped otherwise). Recovery now answers
generically when credential rotation or outbox enqueue fails, which previously
returned 400 only for emails with a purchase. Live Lemon Squeezy, email-provider,
KMS, and production-database execution remain external release gates.

Commerce launch is one explicit boundary. Scheduled and manually invoked
license-outbox workers always require their bearer secret, but while
`CMDTAB_REQUIRE_COMMERCE_READY` is absent or not exactly `1` they return a
successful `commerce_disabled` no-op before opening the commerce database.
Once the switch is enabled, the production migration and all commerce secrets
must already be present and the worker resumes normal retry processing. This
keeps waitlist-mode deployments from querying tables that are intentionally not
yet provisioned.

The signed Lemon Squeezy webhook uses the same boundary. While commerce is
disabled it returns `503 commerce_disabled` before loading commerce
configuration, reading the webhook body, or touching lifecycle tables. The
non-success response preserves the event for provider retry after the launch
switch and infrastructure are ready instead of acknowledging and losing it.

The public checkout surface follows the same switch. A staged checkout provider
or URL is not exposed to purchase buttons or structured offers until the launch
switch is exactly `1`, preventing a customer from being charged while webhook
fulfillment is disabled. Existing license-portal and support links remain
available because they serve already-issued customers and do not create a new
purchase.

## PR #35 five-feature QA

The feature branch is being tested through `scripts/release/run-five-feature-qa.sh`. Its source, tests, package, and reproducibility phases are bound to one clean Git commit with hash-sealed evidence. The focused feature gate must execute exactly **61 tests** with no failures or unexpected results.

The focused inventory includes deterministic profile hotkey timing regressions that preserve the accepted 100 ms hold-to-show and silent quick-switch contract. It also covers fail-closed provisional profile scope, enrichment coalescing, durable-history write isolation, and truthful Stage Manager inference. The source, package, reproducibility, and packaged-app matrices must all be rerun after any source change.

The deterministic fixtures deliberately include a same-title, no-document-identity window pair for durable-MRU ambiguity testing. Fixture windows disable AppKit restoration and reapply their intended full-size frames after content-controller installation so one scenario cannot leak minimized state or geometry into another. WindowProbe reports minimized and fullscreen Accessibility state as objective values when available and `null` when unavailable.

Automated acceptance does not substitute for the packaged-app manual matrix. Unsupported hardware or desktop configurations must remain `NOT TESTED`, including Intel and any multi-display topology not physically exercised.

## Phase 1 accepted evidence

Accepted source commit:

```text
516a9476c01f4d59981f35dc44b6eb09dcd6d790
```

Merged through PR #31 with merge commit:

```text
f37e47029344e191682bd02ade8d7daf4ea241bd
```

The accepted local macOS gate recorded:

- repository identity verification passed;
- bundle migration tests: 6/6 passed;
- capture fallback regression tests: 3/3 passed;
- complete Swift package suite: 132/132 passed;
- release compilation and app assembly passed;
- bundle layout, metadata, architecture, signature, and checksum verification passed;
- two clean unsigned bundles from the canonical build path were byte-for-byte reproducible;
- packaged menu-bar launch, Dock/native-switcher exclusion, permissions, Command-Tab interception, deliberate quit/reopen, Arc preview capture, and Arc activation were manually confirmed.

The complete record is [`docs/release/evidence/phase-1/README.md`](docs/release/evidence/phase-1/README.md).

## Protected behavior

Changes to hotkey routing, exact-window MRU, frontmost resolution, activation confirmation, focused-window observation, preview-independent membership, quick actions, and suppression animation require focused regressions plus the complete Swift package suite. The event-tap callback must remain non-blocking.

Like native Command-Tab, every matching key-down starts a session regardless of
how long the modifier was held; extra Tabs before the reveal advance the
selection. Shortcut interception uses the last licensing status verified in this
process; a slow or pending Keychain read never revokes it, and Keychain access and
token verification run outside the event callback. Accessibility calls use a
0.25 s process-wide timeout so a hung app cannot stall the main-thread tap. A watchdog
checks for disabled or invalid event taps once per second and reinstalls them
after Accessibility is restored. Command-Tab stays global while editing CmdTab
text fields. Secure Input and shortcut recording still pass new shortcuts through
to macOS. Trial-clock persistence runs on a serial background queue and retains
the session's highest observed date while writes are pending. Event routing and
recovery run on the main run loop, so a prolonged main-thread stall
can still delay interception and recovery.

Switcher shortcuts hide Settings and Shortcut Profiles without discarding their
contents. Settings open through explicit menu actions; shortcut access denial and
app reopen events do not open Settings automatically.

Permission setup opens a floating helper above System Settings with a draggable
icon for the exact running CmdTab app. It is available from the setup guide,
General settings, and diagnostics for Accessibility and Screen Recording.
The helper also offers Show This CmdTab in Finder as an alternative to dragging.

Classic Grid labels include the owning app when the window has a distinct title
(for example, `Finder · Claude`). Accessibility-only windows use the same validated capture
path as other windows; a failed preview does not remove a legitimate window.

## Automated app evidence

Phase 1 local evidence proves the current deterministic host-architecture package on the tested Mac. GitHub-hosted macOS 14 and macOS 15 execution remains deferred under issue #30 and must pass before Phase 2 can be accepted.

Automated SwiftPM evidence does not replace packaged-app testing for permissions, focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, Secure Input, signing, notarization, installation, updates, or rollback.

The repository now includes a real-machine, hash-bound performance harness for
10/25/50-window scenarios and a 1,000-session soak. Readiness mode validates the
harness only; acceptance requires a clean packaged candidate and every
threshold to pass. The available older package produced a truthful blocked
smoke result, and the current `dist/CmdTab.app` is unsigned/non-launchable, so
no performance acceptance claim has been made. See
[`docs/qa/performance-evidence.md`](docs/qa/performance-evidence.md).

Private-capability canaries use a separate candidate-bound receipt for the AX
window-ID bridge, SkyLight exact focus, and SkyLight capture on physical macOS
14 and 15 hosts. Hosted CI validates only the receipt schema and fail-closed
validator; no private-capability acceptance evidence has yet been retained.

The current public-beta release matrix is
[`docs/release/public-beta-release-matrix.md`](docs/release/public-beta-release-matrix.md).

## Showcase media

The canonical website showcase is `/showcase`.

- Overview, Radial Menu, and Quick Actions use deterministic HD product-composite posters and MP4s.
- Classic Grid and Command Palette use deterministic HD product-composite posters.
- All media uses controlled fixture windows, is not AI-generated, and is not a private desktop capture.
- Poster-only entries render an image fallback; no missing MP4 may produce a black panel.
- VideoObject data is emitted only for actual MP4 assets.
- The homepage Overview clip loops only while visible; showcase-page autoplay clips run once for no more than five seconds. All media remains static when Reduce Motion is enabled.
- The homepage hero hides its asset-title overlay, and generated Quick Actions frames contain no central Command-W annotation.

The showcase demonstrates presentation. It does not prove signed-app permissions, exact focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, signing, notarization, performance, memory use, processor support, or architecture coverage.

## Website and discovery

The website uses one canonical route registry for metadata, sitemap, IndexNow, and verification. The 23 public routes cover product behavior, four feature modes/actions, evidence, guides, comparisons, compatibility, permissions, privacy, terms, commerce, support, and the showcase.

The private dashboard is production-fail-closed behind Auth0 Universal Login,
exact owner-subject authorization, required MFA evidence, 15-minute idle and
two-hour absolute application sessions, session-generation invalidation, and
audited administrative actions. Shared-password access is an explicit
non-production fallback only; see
[`docs/security/dashboard-authentication.md`](docs/security/dashboard-authentication.md).

Public claims must be visible in canonical HTML and supported by source, code, tests, or clearly labelled media. Do not publish ScreenCaptureKit, latency, RAM, Universal Binary, Apple Silicon, Intel, processor, fake rating, testimonial, or directory-status claims without evidence.

`/llms.txt` is a descriptive directory. `/llms-full.txt` is a non-standard noindex convenience export; canonical HTML remains authoritative.

## Verification

From `website/`:

```bash
npm ci
npm run prebuild
npm run build
```

The permanent SEO workflow also starts the compiled server and runs rendered, webmaster, evidence, retrieval, showcase-response, and desktop/mobile browser checks.

Hosted GitHub Actions capacity has been restored: on 2026-10-09 the Swift, Release Readiness, Security, and SEO and GEO workflows ran to completion (for example Swift and Release Readiness on `main`, runs 37967350531 and 37967350577). Treat a job as a CI pass only when its run shows executed steps and a success conclusion for the reviewed commit; a job rejected before its first step is not a pass.

A Vercel deployment is accepted only when its metadata identifies the reviewed `main` commit and the public domain serves `/showcase`, every referenced media file, the 23-route sitemap, and no unsupported claims.

## Device acceptance history

Superseded status notes, newest first. They describe earlier local builds, not current `main`; full detail is in the linked evidence.

- 2026-09-30 to 2026-10-04: local dirty-tree fixes with retained logs, not release certification: [Finder ghost windows and floating permission setup](docs/qa/evidence/window-permissions-2026-09-30/README.md), [interception fix](docs/qa/evidence/interception-fix-2026-09-30/README.md), [Settings appearing during shortcuts](docs/qa/evidence/settings-shortcut-2026-10-04/README.md).
- 2026-09-27: complete inventory publication, minimized-window inclusion for this installation's global/standard profiles, explicit preview states and bounded thumbnail storage; 343 XCTest + 2 Swift Testing passed and scoped QA reported no P0/P1/P2. A universal local build was installed at `/Users/Siew Hean/Applications/CmdTab.app` (executable SHA256 `53ac23c2c8b55ab14227daa7734f56803376f7746a3a9308d3e26d37056c3100`); permission authorization was pending and identical-binary restart and live all-window acceptance were **not verified**. The host moved to macOS 27.2 (26B5091g), so 26.6 geometry results are historical. Ad-hoc signatures change on rebuild, so permission continuity across builds is not established. [Evidence](tasks/window-coverage-2026-09-27.md). Observed duplicate-helper and hidden-window cases passed on a later local build: [duplicate windows](tasks/duplicate-windows-2026-09-27.md).
- 2026-09-25 follow-up: after user-authorized permission changes, `/tmp/CmdTab-switcher-QA-20260925.app` (PID 17971) reported both permissions Ready: 8 exact windows, 10 app fallbacks, 8 previews, 0 unavailable; the extra Calendar and Chrome helper cards were absent. The AppKit geometry fault is **not resolved**: the native screen-sharing indicator returns `(-1,-1)` as a frame size, and the same six faults reproduce in a plain AppKit window without CmdTab on macOS 26.6. No production workaround was added. [Minimal reproduction](Tests/Fixtures/AppKitSharingGeometry/README.md).
- 2026-09-25 correction: unified minimized-dialog AX eligibility, stale-AX refresh per process group, and two bounded thumbnail recovery retries; 317 XCTest + 2 Swift Testing; universal ad-hoc package verified. [Verification](tasks/switcher-remediation-2026-09-25.md).
- 2026-09-22 to 09-23: toggling Screen Recording off/on did not restore capture (PID 73343, 0 previews / 24 unavailable); removing and re-adding the entry did (PID 25401, 4/4 checksums, 12 previews / 6 unavailable). Remaining then: icon-only tiles, a Chrome address-bar surface, an extra Cisco entry and AppKit geometry faults. An earlier final-QA check (PID 61492) **failed** live acceptance with Screen Recording Required and ScreenCaptureKit error -3801.
- 2026-09-17 to 09-20: AltTab-informed thumbnail recovery, independently implemented rather than copied from GPL source; 308 XCTest + 2 Swift Testing on macOS 26.6. `/tmp/CmdTab-thumbnail-final-QA-20260920.app` was a local ad-hoc test artifact, not a signed or notarized release. [Audit](tasks/alttab-thumbnail-audit-2026-09-17.md); [2026-09-15 evidence](tasks/switcher-discovery-implementation-2026-09-15.md).

## Remaining signed-app acceptance boundary

Interactive macOS testing is still required for permission denial and revocation, exact focused-window proof, mouse and keyboard commits, minimized/fullscreen windows, Spaces, displays, Stage Manager, rapid input, Secure Input, sleep/wake, stable signing identity, notarization, updates, rollback, and clean-account installation.
