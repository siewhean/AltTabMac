# CmdTab release configuration

`ReleaseConfig.json` is the canonical source for local bundle metadata.

The current bundle identifier is `net.cmdtab.CmdTab`, derived from the maintained `cmdtab.net` product domain. Confirm that this identifier is registered to the correct Apple Developer team before Phase 2 signing begins. Do not casually change it after licenses, permissions, update feeds, or public artifacts depend on it.

## Legacy beta migration

The earlier beta used `com.user.CmdTab`.

On first launch under the permanent identifier, CmdTab:

- copies only maintained preferences, search memory, trial state, install ID, activation metadata, cached license payload, and developer-test state when the new domain does not already contain the key;
- copies the legacy license Keychain item into the new account only when the new item is absent;
- leaves the legacy UserDefaults domain and Keychain item untouched for rollback;
- retries later if silent Keychain access is temporarily unavailable.

Accessibility and Screen Recording grants belong to macOS TCC and cannot be migrated by the app. Test and document the re-grant path before distributing the new identifier.

## Phase 1 commands

Verify repository-wide release identity without building:

```bash
python3 scripts/release/release_config.py verify-repository
```

Build an ad-hoc signed local QA app:

```bash
./scripts/release/package-app.sh
```

The default outputs are:

```text
dist/CmdTab.app
dist/CmdTab.manifest.json
dist/CmdTab.sha256
```

Build the legacy root-level local app:

```bash
./build.sh
```

Verify an existing local bundle:

```bash
./scripts/release/verify-bundle.sh dist/CmdTab.app ad-hoc
```

Run two clean unsigned builds and compare every packaged byte:

```bash
./scripts/release/reproducibility-check.sh
```

Run migration-focused and full Swift tests locally:

```bash
swift test --scratch-path /tmp/CmdTab-migration --filter BundleIdentityMigrationTests
swift test --scratch-path /tmp/CmdTab-phase1
```

## Boundaries

- Phase 1 uses the architecture of the current build Mac only.
- The manifest records the actual architecture; it must not be advertised as Universal Binary unless both `arm64` and `x86_64` are built and verified.
- Ad-hoc signing is for local QA only.
- Developer ID signing, secure timestamping, notarization, stapling, Gatekeeper assessment, and clean-machine distribution belong to Phase 2.
- `Resources/CmdTab.entitlements` is intentionally empty. Add an entitlement only when a verified runtime requirement proves it is necessary.
