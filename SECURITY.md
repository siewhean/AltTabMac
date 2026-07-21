# Security Policy

## Reporting a Vulnerability

- Report vulnerabilities privately to `security@cmdtab.net`.
- Public release requires the `security@cmdtab.net` mailbox to be provisioned, monitored, and delivery-tested.
- Include the affected feature, reproduction steps, impact, and supporting artifacts.
- Do not publish exploit details until the CmdTab team confirms the issue is resolved.

## Current Public Scope

- `website/` public product site and protected owner dashboard
- Public waitlist, trial, telemetry, reminder-cron, and Lemon Squeezy webhook endpoints
- CmdTab macOS app bundle, settings, trial registration, signed licensing, and opt-in diagnostics

## Security Baseline

- Public endpoints enforce bounded request bodies, strict validation, and endpoint-specific authorization or throttling.
- Dashboard mutations enforce same-origin URL-encoded forms, bounded bodies, HMAC-protected short-lived sessions, and login throttling.
- Lemon Squeezy fulfillment verifies webhook signatures before issuing signed license tokens.
- Native cached license state is accepted only after P-256 signature verification; developer simulations are compiled out of release builds.
- App diagnostics is disabled by default and excludes window titles, thumbnails, and application contents.
- The website ships CSP, HSTS in production, clickjacking protection, and cross-origin isolation headers.
- Email delivery, database access, webhook verification, admin access, and license signing use environment-driven secrets that are not checked into source.
- The production CSP still allows inline scripts because of the current Next.js / analytics bootstrap path. Keep the site surface minimal and move to nonce- or hash-based CSP if the surface grows.
- In-process throttles are not a distributed production defense. Enable Vercel WAF/shared rate limiting, verified sending domains, database controls, and operational monitoring before launch.

## Secret Handling

- Keep production secrets only in Vercel environment variables. Do not commit live values to the repo, screenshots, or local dotfiles that are shared publicly.
- Use separate secrets for preview and production environments.
- Rotate any affected Resend, database, dashboard, cron, Lemon Squeezy, or signing credential immediately after suspected exposure, then redeploy and verify the affected flow.

## Incident Response

- If a public endpoint is abused or compromised, first disable or constrain traffic, rotate affected secrets, and preserve Vercel, database, Resend, and Lemon Squeezy evidence.
- If a vulnerability could have exposed user data, preserve logs, identify impacted submissions, and prepare a user-facing communication plan before re-enabling traffic.
- After containment, ship the fix, redeploy, re-run `npm run security:check`, and document the root cause plus the permanent prevention step.

## Owner Responsibilities Before Public Launch

- Keep `security@cmdtab.net` monitored with a named primary and backup responder.
- Enable Vercel Firewall / bot protection and review request logs for the waitlist endpoint.
- Provision Postgres with explicit migrations, least-privilege access, encrypted transport, backups, restore testing, retention, monitoring, and alerts.
- Verify the Resend sender domain and keep secrets only in deployment environment variables.
- Code-sign, notarize, and staple the macOS app before public distribution.
- Run a clean-machine install test and a browser-level verification pass before turning on paid traffic.
