# Task: CmdTab website SEO + GEO rollout

- [x] Add public SEO landing expansion (`/faq`, `/how-it-works`) with crawl-safe metadata and intent-focused copy.
- [x] Expand `sitemap.ts` for full public surface and tighten `robots.ts` for dashboard/API route protection.
- [x] Add machine-readable schema layers for website/app (`WebSite`, `SoftwareApplication`, `Product/Offer`, `FAQ`, `BreadcrumbList`) plus llms summary surface.
- [x] Strengthen `/buy`, `/help`, and `/` product/platform discovery copy with trial/license/recovery/permissions anchors.
- [x] Add dedicated FAQ and informational route metadata checks and complete website verification.
- [x] Reconcile `README` changelog notes for this rollout.
- [x] Validate `npm` website checks and route protection behavior.
- [x] Run Swift `build` smoke check.

## Review

- Added new public `/faq` and `/how-it-works` routes with structured JSON-LD and crawl-visible summaries.
- Added global and route-specific JSON-LD, expanded sitemap to include all public pages, and enforced dashboard noindex behavior for both metadata and robots.
- Added `/website/public/llms.txt` and explicit platform metadata sections for app discoverability.
- Website validation: `npm run test`, `npm run typecheck`, and `npm run build` all passed (`87` tests).
- Swift validation: `swift build --disable-sandbox --scratch-path /tmp/CmdTab-test` passed.

# Task: Provider-verified Neon recovery evidence

- [x] Generate a redacted recovery receipt from authenticated Neon project, branch, operation, and checkpoint responses.
- [x] Require that receipt before Production migration and bind it into migration and backup/restore evidence.
- [x] Verify recovery receipt hashes and cross-receipt bindings in final QA and evidence aggregation.
- [x] Add fail-closed operational regression coverage and update release documentation.
- [x] Run production-operation/release-automation gates and independent QA/QC.

## Review

- The protected migration workflow now creates a real protected Neon recovery branch before SQL, polls the exact `create_branch` operation, and verifies the provider-assigned parent LSN plus at least seven days of project history retention.
- Migration, backup/restore, final-QA, and aggregate receipts bind the same redacted Neon response hashes, resource IDs, source SHA, and release tag; operator-entered recovery markers and PITR-day claims were removed.
- Mocked authenticated API coverage rejects missing/unauthorized credentials, insufficient retention, mismatched operation IDs/actions, and forged downstream evidence.
- `./scripts/test_production_operations.sh`, `./scripts/test_release_automation.sh`, Node/shell syntax, workflow YAML parsing, and `git diff --check` passed. Independent follow-up QA returned no findings.

# Task: Replace generated website product media with real CmdTab captures

- [x] Snapshot CmdTab preferences, process state, and frontmost application.
- [x] Arrange privacy-safe neutral windows and capture each shipped switcher style from the rebuilt app.
- [x] Add reduced-motion-aware video plumbing and document the clean-account recording blocker.
- [x] Remove obsolete generated product SVGs and update launch/project documentation.
- [x] Run website tests, typecheck, production build, media integrity checks, and browser visual review.
- [x] Restore preferences/running state and complete independent visual QA/QC.

## Review

- Published seven metadata-stripped PNGs captured directly from the packaged app: Classic Grid, scan/commit states, Command Palette, filtered search, Radial Menu, and selected-preview close-up.
- Replaced every active hero, style, feature, and walkthrough product illustration with real panel media; deleted the obsolete generated product SVG files. The separate permissions illustration remains documented pending clean-Mac onboarding capture.
- Added poster-first optional MP4 rendering that pauses under `prefers-reduced-motion`, plus tests that reject product SVG regressions, missing files/posters, and incorrect declared PNG dimensions.
- Full website security gate passed: 87 tests, TypeScript, production build, and dependency audit with zero vulnerabilities. Desktop and true-390 responsive browser review passed.
- The complete CmdTab defaults domain was restored exactly, temporary fixture and capture processes were terminated, and the original single packaged-app process was relaunched with healthy diagnostics.
- Independent visual QA returned no findings. Clean-account MP4 recordings for Classic Grid, Command Palette, Radial Menu, Quick Actions, and Hot Swap remain a launch blocker because command-line recording in this session captured the macOS lock screen rather than the active overlay.

# Task: Dismiss switcher when clicking outside

- [x] Trace the switcher window event/lifecycle path.
- [x] Implement outside-click dismissal with minimal scope.
- [x] Add or update focused regression coverage.
- [x] Run Swift verification and review the diff.
- [x] QA/QC check and record results.

## Review

- Added a global left/right mouse-down monitor to dismiss visible switcher sessions when the click is outside all primary/mirrored switcher panels.
- Regression coverage remains manual because the AppKit event-monitor path has no existing injectable test seam.
- `swift build --disable-sandbox --scratch-path /tmp/CmdTab-test` passed.
- `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test --skip-build` passed: 153 tests, 0 failures.
- `git diff --check` passed.

# Task: Production database backup and integration automation

- [x] Expose reusable `db:backup` and `db:restore:verify` commands.
- [x] Re-download and checksum-verify the uploaded S3 backup artifact.
- [x] Add optional Better Stack success/failure heartbeats to backup and restore drills.
- [x] Add PostgreSQL 17 clean-install, idempotency, drift, and role-isolation CI coverage.
- [x] Add focused tests and run website verification.

## Review

- Backup creation validates the custom-format archive before writing its portable SHA-256 checksum; database credentials are passed through libpq environment variables instead of process arguments.
- Restore verification checks the checksum and archive, requires `DB_RESTORE_VERIFY_CONFIRM=isolated-empty-target`, rejects non-empty targets, then runs the canonical database schema check.
- Focused database tests passed: 14 tests, 0 failures; the complete website suite passed: 81 tests, 0 failures; TypeScript passed.
- Workflow YAML parsed locally. Live PostgreSQL execution remains delegated to the new PostgreSQL 17 GitHub Actions service because Docker/PostgreSQL is not available in this desktop session.
- AWS OIDC, the KMS S3 bucket, Better Stack heartbeat URLs, and live Neon role URLs remain external configuration gates.

# Task: Production website and database release gates

- [x] Add fail-closed Preview/Production environment and secret-isolation validation.
- [x] Add exact enforced WAF validation and immutable tagged Preview/Production deployment receipts.
- [x] Add verified Vercel Blob publishing and final release evidence aggregation.
- [x] Add an environment-protected, snapshot/PITR-gated Production migration workflow.
- [x] Exclude local secrets and heavyweight native build artifacts from Vercel uploads.
- [x] Split live Preview smoke and protected unaliased Production staging from checksum-authorized public publication and canonical promotion.

## Review

- Mocked operational regression coverage passes for missing/shared databases, partial/shared Redis, log-only WAF, tagged deployment metadata, Preview/Production health receipts, Blob re-download checksums, and upload ignore rules.
- Live Preview deployment `dpl_2fF1MXGBzoWS6inat9ZbF8C3oXJz` is READY after an 11.1 KB / 161-file hardened upload. A direct unauthenticated request redirects (`302`) to Vercel SSO; through the protection bypass, the app returns `401` without its health secret and authenticated health returns `503` with `connectivity: ok`, `schema: outdated`, and no stale fulfillment.
- Preview and Production currently share one database target. No migration was run; Neon separation, PITR/snapshot evidence, and separate role credentials remain mandatory external gates.
- Public release now fails closed before Blob exposure or canonical promotion unless the pre-publication aggregate checksum is valid; successful promotion records canonical health and the previous deployment rollback ID/URL.

# Task: Production-readiness implementation audit

- [x] Re-run native, website, database-library, security, typecheck, and production-build gates.
- [x] Restore deterministic 100 ms `Cmd+Tab` hold-to-show behavior.
- [x] Remove PID-level same-app selection skipping and semantic distinct-window collapsing.
- [x] Move cold thumbnail capture off launch/hotkey installation and preserve stale previews.
- [x] Include minimized standard windows only in the configured all-spaces scope.
- [x] Continue one-shot onboarding from Accessibility to Screen Recording without prompt loops.
- [x] Bound modern thumbnail capture to ScreenCaptureKit and prevent legacy fallback stalls.
- [x] Rebuild and verify the universal signed local app.

Review:

- Swift suite passed: 166 tests, 0 failures.
- Website security gate passed: 81 tests, TypeScript, production build, and dependency audit.
- `./build.sh` produced a valid `arm64 + x86_64` app targeting macOS 13; diagnostics report both permissions granted and a healthy event tap.
- In a display-unavailable session, ScreenCaptureKit times out after two seconds and the refresh completes with `captured=0` instead of wedging the cache queue.
- Public release remains blocked by missing Developer ID/notary credentials, a dirty untagged worktree, unresolved `T6CDNA9H92` versus `94R58J6LA2` team identity, undeployed production website/database/Redis/WAF/backup monitoring setup, and clean Apple Silicon/Intel performance QA.
- Independent QA completed with no source or runtime findings after the checklist fallback-label expectation was aligned with the implemented UI. Terminal build/test verification is clean.
- Follow-up fix: added left/right mouse-down types to the CGEvent tap mask so the dismissal path is active.
- Final verification after the follow-up fix: clean build, 153 tests passed, and `git diff --check` passed.
- Touchpad follow-up: normalized CGEvent hit-testing through `NSEvent.mouseLocation` and added `.otherMouseDown` coverage; clean build and 153 tests passed again.
- Cmd-Tab dismissal follow-up: clear pending trigger state from the shared hide path so releasing Command after dismissal is inert.
- Live Aqua-session verification captured three distinct real window previews through ScreenCaptureKit (`requested=3 captured=3`); the Classic Grid showed the ChatGPT, Finder, and Docker Desktop thumbnails with their app icons and names and no skeleton tiles or duplicates.
- A 100-invocation warm first-frame run sampled the switcher after 50 ms and passed 100/100 thumbnail-presence checks. A 400-step forward/reverse selection cycle returned to the first tile with previews intact and diagnostics still healthy.
- Physical-keyboard `Cmd+Tab` suppression/timing, exact same-app multi-window MRU, Instruments latency percentiles, and clean Apple Silicon/Intel permission QA remain external/manual release gates; synthetic HID events from the shell were not accepted as evidence for the physical shortcut path.
- Added an opt-in `CMDTAB_RUNTIME_QA_OUTPUT` JSONL recorder and fail-closed validator for reproducible warm/cold timing, every event-tap callback, tap disablements, capture success, exact-window activation, duplicate counts, and selection-step integrity. Evidence intentionally excludes application/window identities and content; final input must still be supplied by a human on the physical keyboard.
- Rebuilt the packaged universal app after the runtime-evidence integration. Final local gates passed: 166 Swift tests, 81 website tests, release-automation regressions, production-operations regressions, artifact signature/architecture/minimum-OS verification, diagnostics, and `git diff --check`.

## Follow-up: dismissal cancellation and cold-start app list

- [x] Make outside dismissal cancel the active Cmd-Tab trigger like Escape.
- [x] Preserve all enumerated active apps/windows when synchronous thumbnails are incomplete.
- [x] Run focused tests, full Swift verification, package the app, and complete QA/QC.

Review:

- Outside dismissal now uses the shared `hidePanel()` path, which clears the pending Cmd-Tab trigger before modifier release.
- Cold-start priming now merges ready thumbnails into the complete provisional item list, so uncaptured apps remain visible.
- Focused tests passed, full Swift suite passed: 155 tests, 0 failures.
- `./build.sh` passed and produced a signed universal `CmdTab.app`.
- `git diff --check` passed.
# Task: Provider-verified Neon recovery evidence

- [ ] Generate a redacted recovery receipt from authenticated Neon project, branch, operation, and checkpoint responses.
- [ ] Require that receipt before Production migration and bind it into migration and backup/restore evidence.
- [ ] Verify recovery receipt hashes and cross-receipt bindings in final QA and evidence aggregation.
- [ ] Add fail-closed operational regression coverage and update release documentation.
- [ ] Run production-operation/release-automation gates and independent QA/QC.
# Task: Provider-verified Neon recovery evidence

- [ ] Generate a redacted recovery receipt from authenticated Neon project, branch, operation, and checkpoint responses.
- [ ] Require that receipt before Production migration and bind it into migration and backup/restore evidence.
- [ ] Verify recovery receipt hashes and cross-receipt bindings in final QA and evidence aggregation.
- [ ] Add fail-closed operational regression coverage and update release documentation.
- [ ] Run production-operation/release-automation gates and independent QA/QC.
