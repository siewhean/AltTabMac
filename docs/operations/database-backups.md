# Database backups

Production data lives in Neon project `neon-bistre-dog`
(`twilight-shadow-19787996`, `aws-ap-southeast-1`, Postgres 17), branch `main`,
database `neondb`. The project is managed through the Vercel integration
(organisation "Vercel: siewhean's projects").

## Two layers

| Layer | Window | How to restore |
|---|---|---|
| Neon point-in-time history | **6 hours** (current Neon plan) | Create a branch from a past timestamp (below) |
| Nightly logical dump to S3 | **35 days** | Download a dump and `pg_restore` it (below) |

### Nightly dump

`.github/workflows/db-backup.yml` runs daily at 19:17 UTC (03:17 Singapore) and
on demand (Actions → Database backup → Run workflow).

- Connects as `cmdtab_backup`: `pg_read_all_data`, login only,
  `default_transaction_read_only = on`; it cannot write. Its connection string
  is the repository secret `NEON_BACKUP_DATABASE_URL`.
- Runs `pg_dump --format=custom` with the `postgres:17` image, then checks with
  `pg_restore --list` that the dump is readable, has at least 50 tables of data,
  and includes `public.waitlist_signups`.
- Uploads `neondb/YYYY/MM/DD/neondb-<UTC timestamp>.dump` and a `.sha256`
  file to `s3://cmdtab-db-backups-880302055919` (`ap-southeast-1`).
- Authenticates with GitHub OIDC to `arn:aws:iam::880302055919:role/cmdtab-github-db-backup`.
  The role trusts only `repo:siewhean/AltTabMac:ref:refs/heads/main` and may
  only `s3:PutObject` under `neondb/`: it cannot read, list, or delete backups.
- The bucket blocks public access, uses SSE-S3 encryption, denies non-TLS
  requests, keeps versions, expires dumps after 35 days and old versions after
  7 days.

### Restore from a nightly dump

```bash
aws s3 ls s3://cmdtab-db-backups-880302055919/neondb/ --recursive | tail -5
aws s3 cp s3://cmdtab-db-backups-880302055919/neondb/<path>.dump ./neondb.dump
neon branches create --project-id twilight-shadow-19787996 --name restore-<date>
pg_restore --no-owner --clean --if-exists --dbname="<restore branch URL>" ./neondb.dump
```

Restore into a new branch or database first and check it, then point the app at
it or copy the needed rows. Never `--clean` the production branch directly.

### Point-in-time restore (last 6 hours)

```bash
neon branches create --project-id twilight-shadow-19787996 \
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

## Known risk: shared database

`neondb` also holds about 90 tables of another application (Matchday:
competitions, scoring, scheduling), and the same Neon project has three more
`matchday_*` databases. CmdTab and Matchday therefore share a database owner
credential, and any restore of `neondb` affects both. The nightly dump covers
both applications. Moving CmdTab to its own Neon project is recommended.
