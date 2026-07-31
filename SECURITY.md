# Security Policy

## Reporting a vulnerability

- Report vulnerabilities privately to `support@cmdtab.net` with **Security** in
  the subject line.
- Include the affected version or route, reproduction steps, impact, and safe
  supporting artifacts. Do not include customer licences, payment data, private
  window content, or credentials.
- The mailbox must be verified and monitored before any public beta download is
  enabled. Until then, CmdTab remains waitlist-only.

## Current scope

- The public Next.js website, waitlist, analytics, trial, licence, dashboard,
  release-manifest, and beta-update surfaces under `website/`.
- Lemon Squeezy webhook and licence-outbox endpoints, which remain fail-closed
  while `CMDTAB_REQUIRE_COMMERCE_READY` is not exactly `1`.
- CmdTab's direct-distribution macOS app, including Accessibility, Screen
  Recording, private capability fallback, Sparkle update, and licence-token
  boundaries.

## Security baseline

- Production CSP uses per-response nonces and `strict-dynamic`; HSTS, frame,
  content-type, and no-store controls are verified by website security checks.
- Public and internal write endpoints require validation, origin/authentication,
  and shared rate-limit storage as their individual contracts specify.
- Dashboard access uses Auth0 OIDC with an exact owner subject, MFA evidence,
  idle/absolute sessions, CSRF checks, and audit records when Postgres is
  configured.
- CmdTab never enables checkout, fulfilment, or licence-outbox processing
  unless the explicit commerce switch and complete production infrastructure
  are present.
- The signed beta remains blocked pending Developer ID signing/notarisation,
  clean-machine proof, actual CI execution, a monitored domain mailbox, and
  explicit go-live approval.

## Secret and incident handling

- Keep production values only in deployment or keychain-backed secret stores;
  never commit certificates, API keys, token private keys, database URLs, or
  customer credentials.
- Use distinct preview and production secrets; rotate an exposed secret before
  redeploying or resuming the affected worker.
- Contain incidents by disabling the affected public surface or update feed,
  preserving relevant logs, rotating affected credentials, and documenting the
  root cause and durable remediation in the release evidence ledger.

## Owner actions before public beta

- Verify and monitor `support@cmdtab.net`, including its sending/reply path.
- Enable and review Vercel WAF/bot protection and production request logs.
- Restore GitHub Actions capacity and protect `main` with the required executed
  checks before accepting CI evidence.
- Complete Developer ID signing, notarisation, stapling, Gatekeeper, and
  clean-machine acceptance on the exact candidate artifact.
