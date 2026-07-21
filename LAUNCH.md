# CmdTab Launch Checklist

This file separates what is already prepared in the repo from what still requires owner decisions, accounts, and operational setup.

## Done In Repo

- `website/` is a production-buildable Next.js marketing site.
- Waitlist capture exists at `POST /api/waitlist`.
- Trial registration, opt-in telemetry, reminder cron, Lemon Squeezy webhook fulfillment, license recovery, and protected dashboard routes are implemented.
- The site now includes Vercel Analytics page tracking and CTA event tracking.
- `.env.example` exists in `website/` for the waitlist email setup.
- The macOS app already builds into `CmdTab.app` via `./build.sh`.
- `./scripts/build_release_dmg.sh` packages a signed + notarized DMG once Apple credentials are configured.
- CI runs Swift tests/build checks, website test/typecheck/build/audit gates, and secret scanning.
- The universal app, diagnostics command, distributed rate limits, database migrations, health checks, retention, and backup/restore automation are implemented; their local tests pass, while live Neon/AWS/KMS/restore execution remains pending.

## You Need To Decide

- Final offer:
  - public 14-day trial
  - standard one-time license price: `$9.99`
- Commerce stack:
  - Lemon Squeezy
- Support inbox:
  - beta/support email
  - refund/contact email
- Download strategy:
  - direct app download only
  - or direct download + Setapp later

## Website Launch Steps

1. Create and verify your sending domain in Resend.
2. Configure only the website runtime values from `website/.env.example` in Vercel, using separate Preview and Production values:
   - `NEXT_PUBLIC_SITE_URL`
   - `SITE_URL`
   - `RESEND_API_KEY`
   - `WAITLIST_FROM_EMAIL`
   - `WAITLIST_TO_EMAIL`
   - `WAITLIST_REPLY_TO_EMAIL`
   - `DATABASE_URL`
   - `ADMIN_DASHBOARD_PASSWORD`
   - `ADMIN_DASHBOARD_SECRET`
   - `NEXT_PUBLIC_CHECKOUT_PROVIDER`
   - `NEXT_PUBLIC_CHECKOUT_URL`
   - `NEXT_PUBLIC_STANDARD_CHECKOUT_URL`
   - `NEXT_PUBLIC_TRIAL_URL`
   - `NEXT_PUBLIC_LICENSE_PORTAL_URL`
   - `NEXT_PUBLIC_SUPPORT_EMAIL`
   - `LEMONSQUEEZY_WEBHOOK_SECRET`
   - `LEMONSQUEEZY_ALLOWED_STORE_IDS`
   - `LEMONSQUEEZY_ALLOWED_PRODUCT_IDS`
   - `LEMONSQUEEZY_ALLOWED_VARIANT_IDS`
   - `CMDTAB_LICENSE_PRIVATE_KEY_PEM`
   - `LICENSE_DELIVERY_FROM_EMAIL`
   - `CRON_SECRET`
   - `HEALTHCHECK_SECRET`
   - `PUBLIC_RATE_LIMIT_KV_REST_API_URL`
   - `PUBLIC_RATE_LIMIT_KV_REST_API_TOKEN`
   - `ADMIN_RATE_LIMIT_KV_REST_API_URL`
   - `ADMIN_RATE_LIMIT_KV_REST_API_TOKEN`
   - Alternatively, set `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` per Vercel environment when public and admin throttles intentionally share one environment-isolated store.
   - Never add `DATABASE_ADMIN_URL`, `DATABASE_MIGRATOR_URL`, `DATABASE_MAINTENANCE_URL`, `DATABASE_BACKUP_URL`, or the four role-bootstrap passwords to Vercel. Keep admin/migrator credentials in the owner-controlled migration environment, maintenance credentials in the retention workflow, and backup credentials in the backup workflow.
3. Link the intended project, then run `npm --prefix website run ops:validate:production` with `VERCEL_TOKEN`, `CMDTAB_VERCEL_PROJECT_ID`, and `CMDTAB_VERCEL_ORG_ID`. The validator downloads both environment scopes into mode-`0600` temporary files, reports names rather than values, rejects shared databases/secrets/Redis, and deletes the files on exit. Add `--require-waf-enforcement` when the WAF must return `429` rather than log only.
4. Connect your real domain to the Vercel project.
5. Confirm the direct purchase flow opens the Lemon Squeezy checkout.
6. Configure the Lemon Squeezy webhook to `https://cmdtab.net/api/lemonsqueezy/webhook`.
7. Run a signed test delivery:
   - `node scripts/send_test_purchase_webhook.mjs --url https://cmdtab.net/api/lemonsqueezy/webhook --email tohsh17@gmail.com`
8. Provision and monitor:
   - `tohsh17@gmail.com`
9. Upgrade Vercel and enforce the already validated edge rule after reviewing log-mode evidence:
   - WAF / attack challenge mode where appropriate
   - request throttling / bot protection
   - deployment access controls
10. Split Neon Preview/Production and enable PITR. On each empty database run `npm run db:configure-roles`, migrate with `npm run db:migrate`, then run `npm run db:configure-roles` again to transfer ownership and apply table grants. Activate the AWS/KMS backup, restore, retention, health, and alerting jobs only after role-isolation checks pass.
   - Configure GitHub secrets `PRODUCTION_HEALTHCHECK_SECRET` and `BETTER_STACK_HEALTH_HEARTBEAT_URL`; scheduled monitoring always targets the fixed `https://cmdtab.net/api/health` origin.
   - Configure GitHub secrets `AWS_BACKUP_ROLE_ARN` (S3/KMS write), `AWS_BACKUP_RESTORE_ROLE_ARN` (read-only), `DATABASE_BACKUP_URL`, `BETTER_STACK_DB_BACKUP_HEARTBEAT_URL`, `BETTER_STACK_DB_RESTORE_HEARTBEAT_URL`, and `BETTER_STACK_RETENTION_HEARTBEAT_URL`.
   - Configure GitHub variables `AWS_REGION`, `DB_BACKUP_BUCKET`, and `DB_BACKUP_KMS_KEY_ID`. The backup workflow fails unless the bucket blocks all public access, defaults to the expected KMS key, and applies the checked-in lifecycle policy.
   - Configure `NEON_API_KEY`, `NEON_PROJECT_ID`, and `NEON_PRODUCTION_BRANCH_ID` only in the protected Production database environment. Apply Production migrations only through `CmdTab Production Database Migration`: before SQL runs it uses Neon’s authenticated API to create a protected recovery branch, waits for the provider operation, verifies its parent LSN and at least 604800 seconds of configured history retention, and emits a redacted response-hash receipt. The workflow accepts no free-form recovery marker or PITR-day claim.
11. Deploy only a clean canonical release tag. `CmdTab Production Website Stage` uses separate Preview and Production-staging GitHub environments, runs the privacy-safe live Preview smoke suite, then creates a protected `--skip-domain` Production deployment with zero aliases. It does not promote.
12. Privacy-safe PNG captures from the packaged app now replace the generated hero, style, and walkthrough SVG references. Record the remaining Classic Grid, Command Palette, Radial Menu, Quick Actions, and Hot Swap MP4 clips on a clean QA account, inspect every frame, then add `kind: "video"` plus `posterSrc` in `website/src/content/media.ts`. Do not use this desktop's command-line screen recording output: it resolves to the macOS lock screen instead of the active CmdTab panel.
13. Keep secrets production-only:
   - do not commit live env values
   - use separate preview and production keys
   - rotate `RESEND_API_KEY` immediately if exposure is suspected

Current live gate: Preview deployment `dpl_2fF1MXGBzoWS6inat9ZbF8C3oXJz` is READY with a hardened 11.1 KB / 161-file upload. A direct unauthenticated request is redirected (`302`) to Vercel SSO; through the Vercel protection bypass, the app returns `401` without its health secret and `503` with that secret because `schema: outdated`. Preview and Production still resolve to the same database target, so do not run the migration workflow until Neon environments are split and the protected workflow has valid Neon API credentials for provider-verified recovery evidence.

## Commerce Steps

1. Pick a merchant-of-record provider.
2. Create:
   - standard price
   - trial/download delivery flow
   - hosted checkout URL for the site launch section
   - webhook secret for `order_created`
3. Decide license model:
   - device count
   - trial duration
   - re-download policy
4. Confirm the automatic license email reaches the purchaser inbox from the webhook flow.
5. Add support/refund policy text to the website before public paid launch.

## macOS Distribution Steps

1. Export release credentials:
   - `export CMDTAB_DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)'`
   - `export CMDTAB_TEAM_ID='<authoritative certificate OU / TeamIdentifier>'`
   - `export CMDTAB_NOTARY_PROFILE='cmdtab-notary-profile'`
   - Resolve the current mismatch first: the release plan names `T6CDNA9H92`, but the installed development certificate and locally signed app currently report `94R58J6LA2` as the cryptographic team identifier.
2. Optionally set release metadata overrides:
   - `export CMDTAB_BUNDLE_ID='net.cmdtab.app'`
   - `export CMDTAB_VERSION='1.0.0'`
   - `export CMDTAB_BUILD_NUMBER='1'`
3. Run `./scripts/release_notarization_checklist.sh` for a human-readable preflight.
4. Build the signed, notarized DMG with `./scripts/build_release_dmg.sh`.
5. Collect every pre-publication receipt defined in `RELEASE_EVIDENCE.md`, including Preview smoke and protected unaliased Production staging. Stage them on the locked evidence runner, dispatch and approve `CmdTab Prepublication Evidence Intake` from the canonical tag, then pass that successful run ID to `CmdTab Final Release Evidence`. The aggregate workflow rejects artifacts from any other workflow, source SHA, event, or unsuccessful run.
6. Run `CmdTab Public Release` with that workflow run ID. It verifies workflow provenance and every receipt hash before making the DMG public or promoting Production, then verifies canonical health and automatically restores the durable rollback target on failure.
7. Retain the aggregate checksum, Blob receipt, and public-release receipt together. Set the verified immutable Blob URL as `NEXT_PUBLIC_TRIAL_URL` for the next release configuration.
8. Test on a clean Mac:
   - install
   - Accessibility permission
   - Screen Recording permission
   - first switch
   - hot swap
   - quick actions

## Beta Exit Criteria

- Switching is reliable across your core target apps.
- Preview capture is reliable enough that the app feels trustworthy.
- Permission onboarding is understandable.
- At least 20 to 50 beta users have exercised real workflows.
- You have a working support inbox and refund policy before enabling paid launch.

## Nice-To-Have Before Paid Launch

- Actual recorded walkthrough videos for:
  - Classic Grid
  - Command Palette
  - Radial Menu
  - Quick Actions
  - Hot Swap
- Short onboarding screen inside the app for permissions and first use.
- Recorded clean-Mac onboarding and purchase-to-license recovery walkthroughs.
- A nonce- or hash-based CSP that removes the remaining `unsafe-inline` allowance.
