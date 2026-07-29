# Todo

## 2026-07-29 — Trial Page Waitlist Integration

- [x] 1. Create `TrialWaitlistForm` component for `website/src/app/trial/page.tsx`
- [x] 2. Update `website/src/app/trial/page.tsx` with waitlist signup instructions, email collection form, and `/api/waitlist` API submission
- [x] 3. Verify SEO requirements (`createPageMetadata`, `headingAs="h1"`, `createBreadcrumbStructuredData`, `createWebPageStructuredData`)
- [x] 4. Test build and verification commands (`npm run prebuild` in `website/`)

---

## Completed Tasks (Round 3 Audit Remediation)

- [x] Gated Developer preferences pane behind `#if DEBUG`
- [x] Integrated trial email registration into OnboardingView
- [x] Added `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to Keychain items
- [x] Bypassed sending trial emails to `anonymous@local`
- [x] Added cross-device purchasing banner on thank-you page
- [x] Returned 400 Bad Request on Zod errors in telemetry API
- [x] Added notarization/stapling script logic
- [x] Added Swift format/lint CI step
- [x] Replaced unsafe force casts with safe CFTypeRef handling
- [x] Added VoiceOver accessibility labels across SwiftUI views
- [x] Replaced silent `try?` with logged `do/catch` in memory/telemetry stores
- [x] Verified 129/129 Swift tests + 38/38 Next.js routes
