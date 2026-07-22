# CmdTab release configuration and distribution

`ReleaseConfig.json` is the canonical source for bundle metadata.

The current bundle identifier is `net.cmdtab.CmdTab`, derived from the maintained `cmdtab.net` product domain. Confirm that this identifier is registered to the intended Apple Developer team before accepting any signed artifact. Do not casually change it after licenses, permissions, update feeds, or public artifacts depend on it.

## Legacy beta migration

The earlier beta used `com.user.CmdTab`.

On first launch under the permanent identifier, CmdTab:

- copies only maintained preferences, search memory, trial state, install ID, activation metadata, cached license payload, and developer-test state when the new domain does not already contain the key;
- copies the legacy license Keychain item into the new account only when the new item is absent;
- leaves the legacy UserDefaults domain and Keychain item untouched for rollback;
- retries later if silent Keychain access is temporarily unavailable.

Accessibility and Screen Recording grants belong to macOS TCC and cannot be migrated by the app. The ad-hoc Phase 1 bundle required an exact-bundle reset/re-grant during QA. Phase 2 must prove that consecutive builds signed by the same Developer ID identity retain one stable code identity.

## Phase 1 — deterministic local QA bundle

Verify repository-wide release identity without building:

```bash
python3 scripts/release/release_config.py verify-repository
```

Build an ad-hoc signed local QA app:

```bash
chmod +x scripts/release/*.sh
./scripts/release/package-app.sh
```

The default outputs are:

```text
dist/CmdTab.app
dist/CmdTab.manifest.json
dist/CmdTab.sha256
```

Verify an existing local bundle:

```bash
./scripts/release/verify-bundle.sh dist/CmdTab.app ad-hoc
```

Run two clean unsigned builds and compare every packaged byte:

```bash
./scripts/release/reproducibility-check.sh
```

Run the complete accepted local gate:

```bash
./scripts/release/run-phase1-qa.sh
```

Phase 1 evidence is recorded in `docs/release/evidence/phase-1/README.md`.

## Phase 2 — Developer ID direct distribution

Phase 2 creates a signed, notarized, stapled ZIP while preserving the deterministic unsigned input as separate evidence.

### Required signing identity

Set the exact certificate common name shown by:

```bash
security find-identity -v -p codesigning
```

Example environment shape:

```bash
export CMDTAB_DEVELOPER_IDENTITY='Developer ID Application: Example Name (TEAMID1234)'
export CMDTAB_TEAM_ID='TEAMID1234'
```

The scripts reject ad-hoc identity `-`, require exactly one matching certificate in the active keychain search list, enable Hardened Runtime, request an Apple secure timestamp, and verify the resulting authority and TeamIdentifier.

Do not run the signing scripts with `sudo`. Code signing depends on the signing user’s keychain context.

### Notarization authentication

Choose exactly one mode.

#### Named notarytool keychain profile

Create the profile interactively once:

```bash
xcrun notarytool store-credentials 'CmdTab-Notary' \
  --apple-id 'YOUR_APPLE_ID' \
  --team-id "$CMDTAB_TEAM_ID"
```

Then set:

```bash
export CMDTAB_NOTARY_PROFILE='CmdTab-Notary'
```

The app-specific password is entered into `notarytool` interactively when the profile is created. It is not stored in the repository or passed to the Phase 2 scripts.

#### App Store Connect API key

Every API-key setup requires:

```bash
export CMDTAB_NOTARY_KEY_ID='KEYID12345'
export CMDTAB_NOTARY_KEY_PATH="$HOME/.private/AuthKey_KEYID12345.p8"
chmod 600 "$CMDTAB_NOTARY_KEY_PATH"
```

A team API key additionally requires its issuer ID:

```bash
export CMDTAB_NOTARY_ISSUER='00000000-0000-0000-0000-000000000000'
```

Omit `CMDTAB_NOTARY_ISSUER` for an individual API key. Apple rejects an issuer supplied for an individual key.

The `.p8` file must remain outside the repository and must never be copied into evidence or artifacts. Plaintext Apple ID password authentication is intentionally unsupported by this pipeline.

### Non-destructive preflight

Run this before an expensive build or Apple submission:

```bash
chmod +x scripts/release/*.sh
./scripts/release/phase2-preflight.sh
```

It verifies the source contract, exact certificate match, Team ID, API-key file permissions when applicable, and `notarytool` authentication through `history`. It does not build, sign, submit, staple, or publish an artifact.

### Full Phase 2 automated run

```bash
./scripts/release/run-phase2-qa.sh
```

The runner performs:

1. cross-platform Phase 2 source-contract and fixture verification;
2. repository identity verification;
3. credential and signing preflight;
4. the complete Phase 1 regression gate;
5. deterministic unsigned app assembly and manifest capture;
6. Developer ID signing with Hardened Runtime and secure timestamp;
7. notarization ZIP creation;
8. `notarytool submit --wait` and mandatory issue-free log capture;
9. ticket stapling and validation;
10. final ZIP creation and SHA-256 generation;
11. strict codesign, entitlement, Gatekeeper, and ZIP-extraction verification;
12. machine-readable distribution-record generation.

Default outputs:

```text
dist/phase2/CmdTab.app
dist/phase2/CmdTab-<version>-<architecture>.zip
dist/phase2/CmdTab-<version>-<architecture>.zip.sha256
dist/phase2-evidence/
```

A successful automated run writes:

```text
AUTOMATED_PASS
```

This is not final Phase 2 acceptance. Complete and review:

```text
dist/phase2-evidence/manual-checks.md
```

The clean-account test, second consecutively signed build, Launch at Login behavior, real legacy-profile migration, and rollback test remain mandatory manual gates.

## Individual Phase 2 commands

Create an unsigned deterministic input:

```bash
CMDTAB_SKIP_ADHOC_SIGN=1 \
CMDTAB_OUTPUT_APP=/tmp/cmdtab-unsigned/CmdTab.app \
  ./scripts/release/package-app.sh
```

Sign a copied output bundle:

```bash
CMDTAB_INPUT_SIGNING=unsigned \
  ./scripts/release/sign-app.sh \
  /tmp/cmdtab-unsigned/CmdTab.app \
  /tmp/cmdtab-signed/CmdTab.app
```

Create a notarization-safe ZIP:

```bash
./scripts/release/create-zip.sh \
  /tmp/cmdtab-signed/CmdTab.app \
  /tmp/CmdTab-notarization.zip
```

Submit and preserve Apple’s result and log:

```bash
./scripts/release/notarize-app.sh \
  /tmp/CmdTab-notarization.zip \
  /tmp/cmdtab-notary-evidence
```

Staple and validate:

```bash
./scripts/release/staple-app.sh /tmp/cmdtab-signed/CmdTab.app
```

Verify the final app and ZIP:

```bash
./scripts/release/verify-distribution.sh \
  /tmp/cmdtab-signed/CmdTab.app \
  /tmp/CmdTab-final.zip
```

## Entitlement policy

`Resources/CmdTab.entitlements` and `release/CmdTab.entitlements` must remain equal.

They currently contain an empty dictionary. Add an entitlement only when a reproducible signed-runtime failure proves it is required. Do not add broad Hardened Runtime exceptions pre-emptively.

## Architecture and release boundaries

- The current packaging pipeline builds the architecture of the signing Mac only.
- The manifest records the actual architecture.
- Do not advertise Universal Binary, Intel, or cross-architecture support unless both `arm64` and `x86_64` are built, packaged, signed, notarized, installed, and tested.
- The recommended first release-candidate policy is arm64-only unless Intel support is an explicit product requirement.
- A minimum macOS version does not imply support for every processor capable of running that macOS version.
- Ad-hoc signing is local QA only.
- Developer ID script implementation is not evidence that notarization or Gatekeeper passed.
- `release/native-rc1` must not be created until Phase 2, private API capability hardening, the full desktop matrix, and release recovery infrastructure pass.
