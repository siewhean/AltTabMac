# CmdTab Security Checklist Review

Last reviewed: 2026-07-15
Source checklist: `05_Security_Checklist.docx`

## Scope

- Website: public marketing, waitlist, trial, telemetry, cron, and Lemon Squeezy webhook APIs plus the protected owner dashboard
- Native app: macOS switcher, trial registration, signed offline licensing, and opt-in diagnostics

## Passes Now

- Strict server-side validation with `.strict()` payload parsing and capped field sizes
- Same-origin and bounded form enforcement for dashboard mutations
- Honeypot response and duplicate-submission suppression
- Bounded JSON parsing, content-type checks, and fail-closed Upstash throttling for public trial and telemetry routes
- Fail-closed cron authorization and bounded, signed Lemon Squeezy webhook ingestion
- HMAC-protected, two-hour dashboard sessions and shared 5-failure/15-minute login throttling with a 30-minute block
- No-store responses on the waitlist API
- Production HSTS plus CSP / frame protections / content-type protections
- No hard-coded API secrets found in the macOS app or repo source
- Dependency audit clean for current production website dependencies
- Private disclosure channel documented through `SECURITY.md`, `/security`, and `/.well-known/security.txt`
- Recurring dependency/security verification wired into repo automation through `.github/workflows/security.yml`, `npm run security:check`, and Dependabot
- Signed license tokens are cryptographically verified before cached state unlocks the app
- Developer licensing simulation is absent from release builds, and diagnostics is opt-in

## Not Implemented In Repo

- Multi-user admin identities, MFA, SSO, or role-based access control
- File uploads and object-storage scanning
- Multi-user operations alert routing and automated incident escalation

## Partially Covered, Requires Owner-Side Production Setup

- The Vercel WAF rule is validated in log mode; enforcement requires a plan that supports rate-limit actions
- Preview Upstash is configured; a separate Production store must be provisioned before the new public mutations deploy
- Database migrations, role bootstrap, backup/restore, health, and retention automation exist and pass locally; separate Neon branches, PITR, AWS/KMS, and Better Stack must be configured
- Resend sender-domain verification must be completed before launch
- Security mailbox monitoring and incident response ownership must be active
- Native app signing, notarization, and distribution validation must be completed before public release
- Privacy, telemetry consent, retention, and deletion requirements must be reviewed for launch jurisdictions

## Implemented Hardening In This Pass

- Request body size enforcement before public payload processing
- Explicit unsupported-method handling for public routes
- Cross-origin opener/resource policy headers and origin-agent clustering
- Release packaging fails closed on signing, hardened runtime, notarization, stapling, and Gatekeeper assessment
- Dependency tests, build gates, secret scanning, GitHub Actions, and Dependabot are configured
