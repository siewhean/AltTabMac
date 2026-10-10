# Vercel Firewall

Project `website` (team `siewheans-projects`, Hobby plan). Configured in the
Vercel dashboard on 10 October 2026; the REST firewall-config API returned
`404 Seawall Config not found` for this project, so changes are made in the
dashboard and published there.

## Active configuration

| Layer | Setting | Purpose |
|---|---|---|
| System mitigations | Vercel DDoS protection (always on) | Automatic; can briefly challenge a single IP that sends bursts |
| Custom rule: **Block scanner paths** | Request path matches `^/(\.env\|\.git\|wp-admin\|wp-login\.php\|wp-content\|wp-includes\|xmlrpc\.php)\|\.php$` → **Deny** | The site serves no PHP, WordPress, `.env` or `.git` paths |
| Custom rule: **Rate limit public POST endpoints** | Method `POST` and path is any of `/api/waitlist`, `/api/license-help`, `/api/trial/start`, `/dashboard/login/submit`; fixed window 60 s, 30 requests, key IP address → **Deny** | Edge backstop above the app's own limits (6 public-form submissions per minute) |
| Managed: **Bot Protection** | Active, action **Log** | Observe only |

The Hobby plan does not offer the 429 "Too Many Requests" action, so the rate
limit answers `403` with `x-vercel-mitigated: deny`.

## Verification (10 October 2026)

| Request | Result |
|---|---|
| `GET /.env`, `/wp-login.php`, `/index.php` | `403`, `x-vercel-mitigated: deny` |
| `GET /`, `/faq`, `/waitlist`, `/.well-known/security.txt`, `/sitemap.xml` | `200` |
| `POST /api/trial/start {}`, `POST /api/app-telemetry {}` (invalid bodies) | `400` from the app, not mitigated |
| 31 × `POST /api/license-help {}` | 30 × `422` from the app, then `403` deny |
| `GET /`, `POST /api/app-telemetry {}` right after the burst | `200` / `400`: only the four protected endpoints were limited |

## Operating notes

- Testing from one network can trip the system DDoS mitigation; the dashboard
  then shows "Your IP Is Challenged" with a **System Rule** persistent action.
  Close it and let it expire. Do not create a System Bypass for a home IP.
- Before moving Bot Protection from Log to Challenge, review a week of
  Firewall → Traffic and add a bypass for `/api/*`: the Mac app and payment
  webhooks call the API without a browser and cannot answer a challenge.
- Not covered: allowlisting verified search crawlers was not tested from their
  real networks, and attack-challenge mode has not been exercised.
