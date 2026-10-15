# Database backups

Production data lives in Neon project `CmdTab` (`sparkling-surf-15506179`,
`aws-ap-southeast-1`, Postgres 17, Free plan), branch `production`, database
`cmdtab`, in a CmdTab-only Neon account (trycmdtab@gmail.com, organisation
"CmdTab"). Vercel reads it from a manually set `DATABASE_URL` (pooled endpoint);
the Vercel–Neon integration is no longer connected to the `website` project.

Until 11 October 2026 CmdTab shared database `neondb` in project
`neon-bistre-dog` (`twilight-shadow-19787996`) with Matchday; see
[Move to a CmdTab-only project](#move-to-a-cmdtab-only-project-11-october-2026).

## Two layers

| Layer | Window | How to restore |
|---|---|---|
| Neon point-in-time history | **6 hours** (current Neon plan) | Create a branch from a past timestamp (below) |
| Nightly logical dump to S3 | **35 days** | Download a dump and `pg_restore` it (below) |

Rows removed by the daily 90-day retention purge stay in these dumps for up to
35 more days; see [data-retention.md](data-retention.md).

### Nightly dump

`.github/workflows/db-backup.yml` runs daily at 19:17 UTC (03:17 Singapore) and
on demand (Actions → Database backup → Run workflow).

- Connects as `cmdtab_backup`: `pg_read_all_data`, login only,
  `default_transaction_read_only = on`; it cannot write. Its connection string
  is the repository secret `NEON_BACKUP_DATABASE_URL`.
- Runs `pg_dump --format=custom` with the `postgres:17` image, then checks with
  `pg_restore --list` that the dump is readable, has at least 10 tables of data,
  and includes `public.waitlist_signups`.
- Uploads `cmdtab/YYYY/MM/DD/cmdtab-<UTC timestamp>.dump` and a `.sha256`
  file to `s3://cmdtab-db-backups-880302055919` (`ap-southeast-1`).
- Authenticates with GitHub OIDC to `arn:aws:iam::880302055919:role/cmdtab-github-db-backup`.
  The role trusts only `repo:siewhean/AltTabMac:ref:refs/heads/main` and may
  only `s3:PutObject` under `cmdtab/` (and the earlier `neondb/`): it cannot
  read, list, or delete backups.
- The bucket blocks public access, uses SSE-S3 encryption, denies non-TLS
  requests, keeps versions, expires dumps after 35 days and old versions after
  7 days.

### Restore from a nightly dump

```bash
aws s3 ls s3://cmdtab-db-backups-880302055919/cmdtab/ --recursive | tail -5
aws s3 cp s3://cmdtab-db-backups-880302055919/cmdtab/<path>.dump ./cmdtab.dump
neon branches create --project-id sparkling-surf-15506179 --name restore-<date>
pg_restore --no-owner --clean --if-exists --dbname="<restore branch URL>" ./cmdtab.dump
```

Restore into a new branch or database first and check it, then point the app at
it or copy the needed rows. Never `--clean` the production branch directly.

### Point-in-time restore (last 6 hours)

```bash
neon branches create --project-id sparkling-surf-15506179 \
  --name restore-<date> --parent <UTC timestamp> --expires-at <UTC timestamp>
```

## Evidence: point-in-time restore test (11 October 2026)

- Requested 2026-10-11T01:54:36Z; Neon anchored the branch at the last write,
  `parent_timestamp 2026-10-11T01:28:06Z`, LSN `0/11A852A8`.
- All 102 tables in `neondb` had identical exact row counts on the restored
  branch and on live `main`, including `waitlist_signups` 7, `trial_claims` 2,
  `license_requests` 3, `site_analytics_events` 978 and `app_usage_events` 2011.
  No writes happened in the window (last signup 2026-10-10 13:53 UTC), so
  identical counts are expected.
- The temporary branch was deleted afterwards.

## Evidence: first nightly dump restored (11 October 2026)

- Manual run [38107506245](https://github.com/siewhean/AltTabMac/actions/runs/38107506245)
  on `main` at `64024acc` succeeded: OIDC role assumed, dump verified with
  `pg_restore --list`, uploaded.
- Object `neondb/2026/10/11/neondb-2026-10-11T031122Z.dump`: 1,016,777 bytes,
  SSE-S3 (`AES256`), versioned. Downloaded copy matched the stored SHA-256
  `41600e5b769c67404d1a873730539041068ca8986b4643100942dd0e4f568768`.
- Restored with `pg_restore --no-owner --no-privileges` into a new database
  `restore_check` on a temporary branch: exit 0, no errors. All 102 tables
  matched live `neondb` exactly (`waitlist_signups` 7, `trial_claims` 2,
  `license_requests` 3, `site_analytics_events` 978, `app_usage_events` 2011).
  The temporary branch and the local copy were deleted.

## Move to a CmdTab-only project (11 October 2026)

- Copied the 13 CmdTab tables (`admin_audit_log`, `admin_settings`,
  `app_usage_events`, `ingest_rate_limits`, `license_access_states`,
  `license_activations`, `license_delivery_outbox`, `license_recovery_requests`,
  `license_requests`, `request_deduplication`, `site_analytics_events`,
  `trial_claims`, `waitlist_signups`) with `pg_dump`/`pg_restore`
  (`--no-owner --no-privileges`): a rehearsal, then a final copy at
  05:15 UTC. Exact row counts matched on all 13 tables both times; 1 sequence,
  31 indexes and 20 constraints came across. `admin_settings` was confirmed as
  CmdTab's by matching its columns to `src/lib/admin-store.ts`.
- Disconnected the `neon-bistre-dog` integration from the `website` project
  (production and preview), set `DATABASE_URL` to the new project's pooled
  endpoint, and redeployed at 05:17 UTC.
- Verified: an API request wrote its rate-limit row to the new database and not
  the old one; no CmdTab rows were written to the old database after the final
  copy; `/`, `/waitlist` and `/dashboard/login` return 200.
- Preview deployments no longer have a database and fail closed.
- After a verified backup of the new project (below), the owner dropped the
  13 CmdTab tables from the old `neondb` in the Neon SQL editor on
  11 October 2026, without `CASCADE` (owner-reported; Matchday's tables were
  not in the statement). The old project's 6-hour history allowed recovery
  for that window.

## Evidence: first backup of the new project (11 October 2026)

- Run [38115640396](https://github.com/siewhean/AltTabMac/actions/runs/38115640396)
  on `main` succeeded as `cmdtab_backup` (recreated on the new project:
  read-only, `pg_read_all_data`, write probe refused) and uploaded
  `cmdtab/2026/10/11/cmdtab-2026-10-11T054245Z.dump`.
- The downloaded copy matched its stored SHA-256 and restored with
  `pg_restore --no-owner --no-privileges` into a fresh database on a temporary
  branch: exit 0, no errors, 13 tables. Every data table matched live
  `cmdtab` exactly (`waitlist_signups` 8, `trial_claims` 2,
  `site_analytics_events` 978, `app_usage_events` 2011, `admin_audit_log` 2);
  `ingest_rate_limits` and `request_deduplication` change per request and were
  not compared. The temporary branch and local copy were deleted.

## Previous risk: shared database (resolved)

Until 11 October 2026, `neondb` held CmdTab's tables alongside about 90 tables
of another application (Matchday: competitions, scoring, scheduling), and the
same Neon project had three more `matchday_*` databases. The two applications
shared a database owner credential, and any restore of `neondb` affected both.
CmdTab now has its own project and credentials; nightly dumps cover only CmdTab.
