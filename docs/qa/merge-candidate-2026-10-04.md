# October merge candidate qualification

This candidate assembles the reviewed native, release-tooling, documentation,
and showcase changes in a managed checkout based on
`main@dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`.
The original worktree and historical evidence remain intact.

Source and tree identities, raw browser reports, build/server logs, command
results, independent review, and GitHub run results belong in a separate
receipt after the commit is frozen. Any source change invalidates that receipt.
The PR remains unmerged until every required source gate passes.

## Configuration and local checks

Both website verification workflows use disposable PostgreSQL 16 services and
repository variables `GOOGLE_SITE_VERIFICATION` and `BING_SITE_VERIFICATION`.
The variables must contain genuine provider-issued ownership values. Missing
or known placeholder values fail before the build; the same inputs are supplied
through the rendered ownership check. Values are not committed or logged.

For local verification, start an isolated loopback database:

```sh
docker run --detach --name cmdtab-website-verification \
  -e POSTGRES_USER=cmdtab_check \
  -e POSTGRES_PASSWORD=cmdtab_disposable_local \
  -e POSTGRES_DB=cmdtab_merge_check \
  -p 127.0.0.1::5432 postgres:16
docker port cmdtab-website-verification 5432
```

Use the assigned loopback port in `DATABASE_URL`, and export genuine ownership
inputs from the approved configuration before building and starting the server.
Use a unique server port and keep `VERIFY_ARTIFACT_DIR` outside the checkout.
The application initializes its own analytics and rate-limit tables. Run
`browser:check`, then `node scripts/verify-analytics-storage.mjs` with the same
artifact directory and database. The latter compares accepted events against
rows with that browser run's unique marker and requires a 429 response.
Remove only this disposable container after verification. These credentials
are for an isolated local test database, never a shared or production database.

The browser harness explicitly tests `/help` through direct navigation, a
visible internal link, and a cache-bypassing reload. It retains failed chunk
requests and runtime exceptions. The earlier intermittent failure has not been
attributed to a source defect; a coherent clean production build and fresh
browser profile are required evidence rather than a speculative source patch.

## Outstanding source gates

At preparation time, genuine webmaster inputs are unavailable. Compatible
security fixes remove the critical Next.js advisory, but Tailwind 3 retains an
unpatched `braces` dependency chain. The existing audit threshold remains
unchanged; a Tailwind 4 migration requires separate scope confirmation and
rendered regression checks. Neither blocker is waived.

## Public beta boundary

This source PR does not qualify a public beta artifact. Developer ID signing,
notarization, Gatekeeper, physical macOS 14/15 acceptance, clean-user beta
entitlement, VoiceOver/IME, performance/soak, and a signed Sparkle N-to-N+1
update remain unproven on the intended signed artifact. Hosted macOS tests and
local browser checks do not replace these receipts.
