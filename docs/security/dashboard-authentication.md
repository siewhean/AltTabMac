# Dashboard Authentication

The production dashboard uses Auth0 Universal Login through the OIDC
authorization-code flow with PKCE. The application does not provide a
production password form.

## Production contract

Configure `AUTH0_ISSUER_BASE_URL`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`,
`AUTH0_OWNER_SUBJECT`, `AUTH0_BASE_URL`, `ADMIN_DASHBOARD_SECRET`, and
`ADMIN_DASHBOARD_SESSION_GENERATION`. URLs must use HTTPS, the session secret
must contain at least 32 characters, and the owner subject must be the exact
Auth0 `sub` value. Missing or invalid configuration makes the dashboard
unavailable.

Register `https://cmdtab.net/dashboard/auth/callback` as the sole production
callback URL and `https://cmdtab.net/dashboard/login` as the sole production
logout return URL. Enable Universal Login and set the tenant MFA policy to
**Always**. The ID token must provide MFA evidence either through `amr: ["mfa"]`,
an exact `mfa` Authentication Methods Reference entry, or a namespaced boolean
`https://cmdtab.net/mfa: true` claim emitted by a reviewed Auth0 post-login
Action. The callback rejects tokens without MFA evidence, a matching nonce,
the exact issuer/client audience, an unexpired RS256 signature, and the exact
owner subject.

Application sessions are HTTP-only, Secure, SameSite Strict cookies scoped to
`/dashboard`. They expire after 15 minutes idle or two hours absolute. Change
`ADMIN_DASHBOARD_SESSION_GENERATION` to a new opaque value and deploy it to
invalidate every existing application session without changing the signing
secret.

Auth0 owns account recovery and MFA enrollment. Do not add local recovery,
email-domain authorization, or email-address fallback. Dashboard logout clears
the application cookie before redirecting through Auth0's tenant logout
endpoint, and every new authorization request uses `prompt=login`.

## Operational controls

Dashboard POST routes require an exact same-origin `Origin` and reject
cross-site or missing-origin requests. Successful login, logout, waitlist CSV
export, and development-password changes write non-secret actor/action records
to `admin_audit_log` when Postgres is configured.

For local development or hermetic tests only, set
`ADMIN_ENABLE_LEGACY_PASSWORD=true` together with
`ADMIN_DASHBOARD_PASSWORD`, `ADMIN_DASHBOARD_SECRET`, and
`ADMIN_DASHBOARD_SESSION_GENERATION`. `NODE_ENV=production` disables this mode
even when the password variables are present.
