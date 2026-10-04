# CmdTab

Last updated: 2026-08-01
Active task: preserve the accepted native switcher and current frontend while
closing production-runtime blockers. The public website remains waitlist-first
and commerce stays fail-closed unless `CMDTAB_REQUIRE_COMMERCE_READY=1` is set
with the complete database, Lemon Squeezy, email, and KMS configuration.

Current implementation (2026-09-27): complete inventory publication, minimized-window inclusion for this installation’s global/standard profiles, explicit preview states, identity-validated saved previews, and bounded thumbnail/recovery storage are implemented. **343 XCTest + 2 Swift Testing tests pass**; independent scoped QA reports zero unresolved P0/P1/P2 findings. The verified universal local build is installed at `/Users/Siew Hean/Applications/CmdTab.app` (executable SHA256 `53ac23c2c8b55ab14227daa7734f56803376f7746a3a9308d3e26d37056c3100`). Launch-at-login was disabled on the repository copy and enabled on this persistent copy. Final permission authorization currently awaits the user’s Touch ID/password; identical-binary restart and live all-window acceptance are **not yet verified**. This host now runs macOS27.2 (26B5091g), so prior26.6 geometry results are historical. Ad-hoc signatures change on rebuild; no certificate-backed signing identity is installed, so future-build permission continuity is not established. See [current evidence](tasks/window-coverage-2026-09-27.md).

Historical device results follow; they do not describe the newly installed build.

Latest device follow-up (2026-09-25): user-authorized Accessibility grant and removal/re-add of the stale CmdTab Screen Recording entry succeeded. Exact running bundle `/tmp/CmdTab-switcher-QA-20260925.app`, PID17971, reports both permissions **Ready**. Diagnostics: **8 exact windows, 10 app fallbacks, 8 previews, 0 unavailable exact-window previews**. Live practice showed 18 entries; the prior extra Calendar and Chrome helper cards were absent. Minimized-window inclusion remains off; app-only fallbacks intentionally have icons. macOS Quit & Reopen briefly opened another same-identifier checkout; it was stopped and the verified bundle explicitly relaunched.

The AppKit geometry fault is **not resolved**: runtime debugging found the native screen-sharing indicator returning `(-1,-1)`, which AppKit applies as a frame size. The same six faults reproduced in a plain AppKit window with no CmdTab/SwiftUI code on macOS26.6 (25G70). Native toolbar and resizable-window probes did not fix it and were discarded. No production workaround or log suppression was added. See [minimal reproduction](Tests/Fixtures/AppKitSharingGeometry/README.md). Overall error-free runtime acceptance remains unmet despite restored permissions and successful current-window previews.

Latest correction (2026-09-25): unified base/catalog AX eligibility for minimized dialog windows; refresh stale AX inspections immediately before each process’s contiguous CG candidate group while preserving original window order; schedule two bounded thumbnail recovery retries, excluding permission denial and stale process generations. Final source passed **317 XCTest + 2 Swift Testing tests**; independent scoped QA found no unresolved P0/P1/P2 issues. Universal ad-hoc package verification passed. Running corrected local build: `/tmp/CmdTab-switcher-QA-20260925.app` (PID 2386 at launch). At initial launch both permissions were Required; the later authorized follow-up above supersedes that blocker. AppKit screen-sharing-indicator geometry faults also persist. Before replacement, live inspection confirmed minimized-window inclusion was off; Telegram, Reminders and Antigravity had minimized main windows, so their app-only icon entries were expected under that setting. See [current verification](tasks/switcher-remediation-2026-09-25.md). Earlier device results below refer to older builds.

Latest device result (2026-09-23): removing the QA Screen Recording permission entry, re-adding `/tmp/CmdTab-thumbnail-final-QA-20260920.app`, and using Quit & Reopen restored authorization. User authenticated the removal. PID 25401 matches the final artifact (4/4 checksums); both permissions report Ready, with 12 previews / 6 unavailable, 18 exact windows / 2 fallbacks. Real thumbnails were visually confirmed for Finder, Arc, Calendar, GitHub Desktop, VS Code and ChatGPT. Remaining icon-only tiles, a Chrome address-bar-suggestion surface, and an extra icon-only Cisco entry still require investigation. Cisco's captured main window and connection dialog are distinct windows, not identical duplicates. Current-process capture-denial logs are absent, but AppKit negative-geometry faults persist. Full device acceptance remains incomplete. Older failed permission attempts below are historical.

Permission retry (2026-09-22): with user authorization, toggled the final QA app's Screen Recording switch off/on and used macOS Quit & Reopen. New PID 73343 runs the same final QA bundle, but refreshed in-app diagnostics still report Screen Recording Required and 0 previewed / 24 unavailable (24 exact, 4 fallbacks); System Settings confirms its toggle is on. This retry did not resolve live acceptance. Removing/re-adding the permission entry has not been performed; repeated-app exact-window validation remains outstanding.

Latest device check: the user-opened final QA bundle (PID 61492) matches all four artifact checksums, but live acceptance **FAILS**. In-app diagnostics report Accessibility Ready, Screen Recording Required, 23 exact windows / 4 fallbacks and 0 previews / 23 unavailable. ScreenCaptureKit logs error -3801 (authorization declined), despite the QA app's System Settings recording toggle showing on. The switcher was reproduced through setup practice: all visible cards were icon-only, with repeated app labels including WhatsApp, Messages, Arc and Cisco. Whether each repeated label represents a legitimate separate window or a spurious surface is not yet established. Current-process AppKit negative-geometry faults were also observed. No permissions were changed; permission reconciliation/relaunch and exact-window duplicate investigation remain required.

Last updated: 2026-09-25
Active task: AltTab-informed thumbnail recovery integration. Cached frames no longer suppress fresh recovery or renew their capture timestamps. Recovery validates the owning process, preserves image proportions, and uses macOS 26 screenshot capture for ordinary windows and sample buffers for fullscreen windows. Initial AX fullscreen metadata and explicit phase-one recovery suppression avoid wrong-route and unnecessary capture requests. Earlier macOS versions retain the existing recovery API. Upstream behavior was independently implemented, not copied from GPL source. See [audit and verification](tasks/alttab-thumbnail-audit-2026-09-17.md).

Historical verification (2026-09-20): The then-final source passed 308 XCTest tests plus 2 Swift Testing tests, including six new preview-recovery regressions, using Xcode-beta on macOS 26.6. Independent review reports zero unresolved P0/P1/P2 issues in the scoped changes. Existing compiler deprecation warnings remain. Live thumbnail freshness, permissions and cross-Space/fullscreen capture have not been verified for this patch; the running app has not been replaced or relaunched. Previous September 15 permission and Settings negative-geometry findings remain historical evidence, not current runtime results: [previous implementation evidence](tasks/switcher-discovery-implementation-2026-09-15.md).

Historical package (2026-09-20): The thumbnail QA package passed universal arm64/x86_64 bundle and ad-hoc signature verification: `/tmp/CmdTab-thumbnail-final-QA-20260920.app`. This separate local test artifact has not replaced the running app and is not a signed/notarized release.

The P-1 source-of-truth audit is recorded in
[`tasks/audit-repository-identity-2026-09-09.md`](tasks/audit-repository-identity-2026-09-09.md).
Private AX identity, SkyLight capture, and exact-focus calls are centralized in
one status-bearing capability provider. Its unavailable exact-focus path is
recorded as application-only fallback rather than exact MRU success; the
macOS 14/15 canary procedure remains physical-only evidence.
That historical audit found the original worktree dirty and behind `origin/main`;
those results do not qualify the isolated merge-blocker candidate. Candidate evidence now must bind a clean requested
SHA, branch, release-config hash, artifact hash, command results, and host
identity. Fresh-user beta entitlement remains blocked until trial-only signing,
OIDC deployment identity, and the beta trial public keyring are provisioned and
verified. Public beta explicitly disables commerce presentation; existing
verified paid entitlements remain honored. Deterministic release CI also runs
the beta-trial readiness regressions whenever their verifier or KMS source
changes. The regenerated public-beta matrix labels only repository evidence as
`PASS (source)`; its historical dirty-worktree result is retained as evidence.
The isolated candidate requires its own clean SHA and GitHub workflow results;
unrelated successful runs are not represented as CI evidence.
This host also has no Developer ID identity or CmdTab notary profile, so release
packaging rejects before build as designed.

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
Existing `CMDTAB1` paid licenses remain supported for offline compatibility;
production KMS provisioning and embedding its public keyrings in the signed
app remain release gates.

The repository-owned commerce lifecycle now exchanges a high-entropy opaque
purchase activation code for an install-bound signed entitlement, keeps paid
access offline after activation, and transactionally limits each license to
three named Macs. Deactivation frees a slot immediately; recovery is
enumeration-safe; fulfillment uses a retryable outbox; partial refunds preserve
access; and authoritative full-refund or revocation states persist as hashed
tombstones. The migration is idempotent and local real-PostgreSQL concurrency
evidence covers three successful devices, fourth-device rejection, immediate
deactivation, and subsequent activation. Live Lemon Squeezy, email-provider,
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

Shortcut interception uses a bounded, previously verified licensing snapshot;
Keychain access and token verification run outside the event callback. A watchdog
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

The permanent SEO workflow also starts the compiled server and runs rendered, webmaster, evidence, retrieval, showcase-response, and desktop/mobile browser checks when hosted Actions capacity is available.

Hosted GitHub Actions currently may be rejected before a runner executes because the account has no available Actions capacity. A rejected job has no steps or logs and is not a source failure, but it is also not a CI pass. Any temporary waiver must identify that limitation explicitly and retain executable Vercel or local evidence for the affected commands.

A Vercel deployment is accepted only when its metadata identifies the reviewed `main` commit and the public domain serves `/showcase`, every referenced media file, the 23-route sitemap, and no unsupported claims.

## Remaining signed-app acceptance boundary

Interactive macOS testing is still required for permission denial and revocation, exact focused-window proof, mouse and keyboard commits, minimized/fullscreen windows, Spaces, displays, Stage Manager, rapid input, Secure Input, sleep/wake, stable signing identity, notarization, updates, rollback, and clean-account installation.
