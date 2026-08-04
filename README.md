# CmdTab

Last updated: 2026-08-04
Active task: prepare the repository-owned portion of an Apple-silicon signed
public beta from `origin/main@dcd02fa`. The public website remains waitlist-first
and commerce stays fail-closed unless `CMDTAB_REQUIRE_COMMERCE_READY=1` is set
with the complete database, Lemon Squeezy, email, and KMS configuration. This
branch may not publish a download, enable checkout, or claim a completed public
release without the required signing, clean-machine, CI, support, and explicit
go-live evidence.

The current draft candidate also hardens membership and preview reliability:
fresh base windows cannot be hidden by enrichment, capture uncertainty degrades
to an icon fallback, stale cancellation callbacks cannot clear a newer capture
request, and diagnostics are local aggregate counters only. These source
changes still require fresh hosted and real-machine evidence.

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

## Automated app evidence

Phase 1 local evidence proves the current deterministic host-architecture package on the tested Mac. GitHub-hosted macOS 14 and macOS 15 execution is restored and both lanes must pass before Phase 2 can be accepted.

Automated SwiftPM evidence does not replace packaged-app testing for permissions, focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, Secure Input, signing, notarization, installation, updates, or rollback.

The repository now includes a real-machine, hash-bound performance harness for
10/25/50-window scenarios and a 1,000-session soak. Readiness mode validates the
harness only; acceptance requires a clean packaged candidate and every
threshold to pass. The available older package produced a truthful blocked
smoke result, and the current `dist/CmdTab.app` is unsigned/non-launchable, so
no performance acceptance claim has been made. See
[`docs/qa/performance-evidence.md`](docs/qa/performance-evidence.md).

## Showcase media

The canonical website showcase is `/showcase`.

- Overview, Radial Menu, and Quick Actions use deterministic HD product-composite posters and MP4s.
- Classic Grid and Command Palette use deterministic HD product-composite posters.
- All media uses controlled fixture windows, is not AI-generated, and is not a private desktop capture.
- Poster-only entries render an image fallback; no missing MP4 may produce a black panel.
- VideoObject data is emitted only for actual MP4 assets.
- Homepage and showcase autoplay clips run once for no more than five seconds. All media remains static when Reduce Motion is enabled.
- The homepage hero hides its asset-title overlay, and generated Quick Actions frames contain no central Command-W annotation.

The showcase demonstrates presentation. It does not prove signed-app permissions, exact focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, signing, notarization, performance, memory use, processor support, or architecture coverage.

## Website and discovery

The website uses one canonical route registry for metadata, sitemap, IndexNow, and verification. The 23 public routes cover product behavior, four feature modes/actions, evidence, guides, comparisons, compatibility, permissions, privacy, terms, commerce, support, and the showcase.

The `/buy` and `/trial` sitemap entries record their 2026-08-01 fail-closed
public-beta content update; the SEO verifier protects those dates from becoming
stale again.

Website activity is optional and consent-gated. The internal dashboard labels
these metrics as consented and suppresses seven-day comparisons that overlap the
2026-07-28 production measurement start; it never records a consent decision or
an unconsented visitor merely to estimate traffic.

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

Hosted GitHub Actions capacity is restored for PR #49. The first executed candidate
runs exposed a macOS 14 concurrency compile failure, updater-test framework
incompatibility, stale rendered-retrieval assertions, and tracked Finder metadata.
The repository corrections need fresh hosted evidence. The homepage autoplay,
Help-page contrast, and analytics-response defects are corrected in
`d7c3ffe`, which passed local Swift, source-security, production-build, and
in-app-browser checks. The subsequent `e1bc01d` candidate passed executed
macOS 14/15, Security, Workflow Health, Repository Health, SEO/GEO, Release
Readiness browser QA, Audit Source Export, and Vercel checks; PR #49 remains a
clean draft. No failed check is waived.

A Vercel deployment is accepted only when its metadata identifies the reviewed `main` commit and the public domain serves `/showcase`, every referenced media file, the 23-route sitemap, and no unsupported claims.

## Remaining signed-app acceptance boundary

Interactive macOS testing is still required for permission denial and revocation, exact focused-window proof, mouse and keyboard commits, minimized/fullscreen windows, Spaces, displays, Stage Manager, rapid input, Secure Input, sleep/wake, stable signing identity, notarization, updates, rollback, and clean-account installation.
