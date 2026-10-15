# Data retention

Owner decision (15 October 2026): trial records, app telemetry, website
analytics events and license help requests are kept for **90 days**, then
removed automatically. Waitlist signups are out of scope: they are deleted when
the person unsubscribes.

## Schedule

Vercel Cron calls `GET /api/internal/retention-purge` daily at **20:30 UTC**
(04:30 Singapore), after the 19:17 UTC nightly backup
(`website/vercel.json`). Hobby crons fire somewhere within that hour.

The route accepts only `Authorization: Bearer $CRON_SECRET`, the header Vercel
Cron sends. A missing, short (under 32 characters) or placeholder
`CRON_SECRET`, or a wrong token, returns `401` and touches nothing. Responses
and logs contain only row counts.

Code: `website/src/lib/retention-purge.ts`. Each statement handles at most
5,000 rows, and the run stops starting new batches after 40 seconds
(`complete: false` in the response). The next day's run continues from there.

## What happens to each table

| Table | Rule | Action |
|---|---|---|
| `trial_claims` | Trial ended (`ends_at`) more than 90 days ago | **Anonymised, not deleted.** `email`, `app_version` and `os_version` are set to null and `anonymized_at` is set. |
| `app_usage_events` (app telemetry) | `occurred_at` or `created_at` older than 90 days | Deleted |
| `site_analytics_events` (website analytics) | `occurred_at` or `created_at` older than 90 days | Deleted |
| `license_requests` (license help form) | `created_at` older than 90 days | Deleted |
| `ingest_rate_limits`, `request_deduplication` | Already expired (windows last 24 hours at most) | Deleted. `rate-limit.ts` already clears these, but only when requests arrive, so the purge clears them too. |

Not changed: `waitlist_signups` (owner's choice above), and license, purchase,
activation and recovery records (`license_*`), which follow the license
retention terms in the privacy policy.

### Anonymised trial claims still block repeat trials

An anonymised row keeps `id`, `install_id` (a salted SHA-256 from the app),
`hardware_id` (a salted SHA-256 of the Mac's hardware UUID), `started_at`,
`ends_at`, `last_seen_at`, `reminder_sent_at`, `created_at`, `updated_at` and
`anonymized_at`. No raw hardware value is ever stored.

`/api/trial/start` (`createOrGetTrialClaim`) still finds the row:

- by `hardware_id`: the same Mac gets its old claim back, with the original
  expired dates, even with a new Keychain install or a different email;
- by `install_id`: a client that sends no hardware hash gets the same
  expired claim instead of a new trial.

The app requires `claim.email` to be a string, so the route returns the
anonymous-trial placeholder (`anonymous+…@trial.cmdtab.invalid`) for an
anonymised claim.

Limitation: once the email is gone, a request from a different Mac (different
install and hardware hash) with the same email can start a new trial. Only
hashed device identifiers are kept, as the owner decided.

## Schema change

`website/db/migrations/002_data_retention.sql` makes `trial_claims.email`
nullable and adds `anonymized_at`. The runtime schema step in
`website/src/lib/trial-claim-store.ts` applies the same DDL on the first trial
request or purge, so the file does not have to be applied by hand. Applying it
more than once is harmless.

## Backups

Nightly logical dumps (see [database-backups.md](database-backups.md)) are kept
for 35 days. Data removed by the purge therefore survives in backups for up to
**35 more days** before the S3 lifecycle rule expires those dumps. The Neon
point-in-time history adds 6 hours. Restoring an old dump brings back purged
rows; the next daily purge removes them again.

## Operations

- Required Vercel Production variable: `CRON_SECRET` (shared with the trial
  reminder and license outbox crons).
- Check a run: Vercel → Project → Logs, filter `retention purge`.
- Unauthenticated check (must return `401`):
  `curl -i https://cmdtab.net/api/internal/retention-purge`.
- Tests: `website/tests/retention-purge.pg.test.ts` (real Postgres; runs in the
  Release Readiness workflow and locally with `CMDTAB_TEST_DATABASE_URL`) and
  the route tests in `website/tests/licensing-routes.test.ts`.
