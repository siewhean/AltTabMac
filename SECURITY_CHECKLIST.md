# CmdTab Security Checklist Review

Last reviewed: 2026-03-28
Source checklist: `05_Security_Checklist.docx`

## Scope

- Website: Next.js marketing site and `POST /api/waitlist`
- Native app: private beta macOS switcher app

## Passes Now

- Strict server-side validation with `.strict()` payload parsing and capped field sizes
- Same-origin enforcement for waitlist submissions
- Honeypot response and duplicate-submission suppression
- Per-email / IP / user-agent throttling for the waitlist route
- No-store responses on the waitlist API
- Production HSTS plus CSP / frame protections / content-type protections
- No hard-coded API secrets found in the macOS app or repo source
- Dependency audit clean for current production website dependencies
- Private disclosure channel documented through `SECURITY.md`, `/security`, and `/.well-known/security.txt`
- Recurring dependency/security verification wired into repo automation through `.github/workflows/security.yml`, `npm run security:check`, and Dependabot

## Explicitly Out Of Scope / Not Yet Applicable

- User authentication, password storage, MFA, sessions, JWT rotation
- File uploads and object-storage scanning
- Database encryption at rest and row-level access control
- OAuth / SSO / API keys issued to end users
- Webhooks beyond outbound email delivery

## Partially Covered, Requires Owner-Side Production Setup

- Vercel WAF / bot defense / IP throttling must be enabled in production
- Resend sender-domain verification must be completed before launch
- Security mailbox monitoring and incident response ownership must be active
- Native app signing, notarization, and distribution validation must be completed before public release
- Analytics/privacy requirements should be reviewed for the final launch jurisdiction and cookie/consent stance

## Implemented Hardening In This Pass

- Request body size enforcement before waitlist payload processing
- Explicit `HEAD` / `OPTIONS` / unsupported-method handling for the waitlist route
- Cross-origin opener/resource policy headers and origin-agent clustering
- Documented security disclosure and checklist coverage
- Added repeatable security CI commands plus recurring workflow automation via GitHub Actions and Dependabot
