# Todo

## 2026-07-28 — Round 3 Audit Phase 1: Critical Security & FTUX Fixes

- [x] 1.1 Gate Developer preferences pane behind `#if DEBUG` in `PreferencesPaneSelection.swift`, `PreferencesView.swift`, and ignore persisted overrides in release builds
- [x] 1.2 Fix onboarding trial activation: collect email in `OnboardingView.swift` and invoke `/api/trial/start` before completing onboarding
- [x] 1.3 Add `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to all Keychain operations in `LicensingStore.swift`

## 2026-07-28 — Round 3 Audit Phase 2: UX Pain Points & Trial Experience

- [x] 2.1 Soften trial expiry UX: keep menu bar active on trial expiration, disable hotkey interception without forcing hard-quit
- [x] 2.2 Skip sending trial email to `anonymous@local` in `website/src/app/api/trial/start/route.ts`
- [x] 2.3 Add cross-device purchasing guidance banner on `website/src/app/thank-you/page.tsx`
- [x] 2.4 Add DMG drag-to-Applications step-by-step guide card on `website/src/app/trial/page.tsx`
- [x] 2.5 Return HTTP 400 on `ZodError` validation failure in `website/src/app/api/app-telemetry/route.ts`

## 2026-07-28 — Round 3 Audit Phase 3: Build Pipeline & Distribution Security

- [x] 3.1 Implement notarization and stapling support in `build.sh`
- [x] 3.2 Add SwiftLint / format check step to `.github/workflows/swift.yml`
- [x] 3.3 Replace remaining force casts (`as!`) in `AppSwitcher.swift` with safe `as?` conditional unwrapping

## 2026-07-28 — Round 3 Audit Phase 4: Accessibility & Error Logging

- [x] 4.1 Add VoiceOver accessibility labels and hints to SwiftUI views (`ClassicGridView`, `RadialMenuView`, `CommandPaletteView`, `SwitcherView`, `OnboardingView`)
- [x] 4.2 Replace silent `try?` with logged `do/catch` in `SearchMemoryStore.swift`, `LicensingStore.swift`, `LicensingController.swift`, `AppTelemetryReporter.swift`
- [x] 4.3 Verify and enforce `prefers-reduced-motion` compliance across website components
- [x] 4.4 Extract named constants for magic numbers and keycodes (`0x100`, `0x200`, keycode 53)

## 2026-07-28 — Round 3 Audit Phase 5: Architecture & Test Coverage

- [x] 5.1 Decompose `AppSwitcher.swift` into modular helper components (`WindowEnumerator.swift`, `ThumbnailCapture.swift`)
- [x] 5.2 Extract `PreferencesView.swift` sub-panes into standalone view files
- [x] 5.3 Create `/license-recovery` self-serve page on website for user license lookup
- [x] 5.4 Ensure all main-thread blocking AX calls in `AppSwitcher.swift` are safely offloaded
- [x] 5.5 Expand unit test suite for core switcher and hotkey modules

---

## Completed Tasks (Re-Audit Phases 1-6)

- [x] Expired trial "Quit" button fix (`requestTermination()`)
- [x] Hardware-bound `installId` (`IOPlatformUUID`)
- [x] Rate-limiting `/api/trial/start`
- [x] Batching AX IPC calls in `isSwitcherDisplayWindow`
- [x] License key format validation in `LicensingController`
- [x] Global Next.js error/loading boundaries across all routes
- [x] "Skip for Now" button on onboarding steps
- [x] Toggleable `showQuickActionHints` in preferences
- [x] "What Happens Next" card on `/trial` page
- [x] `robots: { index: false }` metadata on `/thank-you` and `/dashboard/*`
- [x] Privacy policy link in Settings telemetry section
- [x] GitHub actions permissions and `npm audit` in security workflow
- [x] Extracted `WindowDeduplication.swift`
- [x] Safely unwrapped byte pointers and mailto URLs
- [x] Expanded unit tests to 129 passing Swift tests
- [x] Skip-to-content link in website layout
