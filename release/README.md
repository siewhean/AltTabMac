# CmdTab release configuration

`ReleaseConfig.json` is the canonical source for local bundle metadata.

The current bundle identifier is `net.cmdtab.CmdTab`, derived from the maintained `cmdtab.net` product domain. Confirm that this identifier is registered to the correct Apple Developer team before Phase 2 signing begins. Do not casually change it after licenses, permissions, update feeds, or public artifacts depend on it.

## Phase 1 commands

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

## Boundaries

- Phase 1 uses the architecture of the current build Mac only.
- The manifest records the actual architecture; it must not be advertised as Universal Binary unless both `arm64` and `x86_64` are built and verified.
- Ad-hoc signing is for local QA only.
- Developer ID signing, secure timestamping, notarization, stapling, Gatekeeper assessment, and clean-machine distribution belong to Phase 2.
- `Resources/CmdTab.entitlements` is intentionally empty. Add an entitlement only when a verified runtime requirement proves it is necessary.
