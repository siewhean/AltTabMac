# Phase 2 QA/QC Record

**Phase:** Developer ID signing, Hardened Runtime, notarization, stapling, Gatekeeper, and clean-account installation  
**Branch:** `agent/phase-2-developer-id-distribution`  
**Status:** SOURCE IMPLEMENTED / SIGNED MACOS GATE PENDING  
**Started:** 2026-07-23

## Decision boundary

Phase 2 is not passed by the presence of signing scripts. Acceptance requires one exact artifact to be:

- built from the accepted deterministic unsigned input;
- signed by the intended `Developer ID Application` certificate;
- associated with the intended Apple Developer Team ID;
- signed with Hardened Runtime and a secure timestamp;
- accepted by Apple notarization with an issue-free log;
- stapled and validated;
- accepted by Gatekeeper;
- extracted and launched on a clean, non-development macOS account;
- tested across a second consecutively signed build to confirm stable privacy-permission identity;
- backed by passing hosted checks from issue #30.

## Implemented source contract

The Phase 2 branch introduces:

```text
scripts/release/phase2-preflight.sh
scripts/release/sign-app.sh
scripts/release/create-zip.sh
scripts/release/notarize-app.sh
scripts/release/staple-app.sh
scripts/release/verify-distribution.sh
scripts/release/run-phase2-qa.sh
scripts/release/verify-phase2-source.py
scripts/release/write-distribution-record.py
```

The pipeline preserves separate evidence boundaries:

```text
deterministic unsigned CmdTab.app
        ↓
Developer ID signed CmdTab.app
        ↓
notarized and stapled CmdTab.app
        ↓
final checked distribution ZIP
        ↓
machine-readable distribution record
```

Signed output is not expected to be byte-for-byte reproducible because secure timestamps and notarization metadata are external inputs. The signed artifact must instead remain traceable to the unsigned manifest, source commit, signing identity, Team ID, notarization submission ID, signed manifest, and final SHA-256 checksum.

## Credential contract

No Apple credential is committed or copied into evidence.

Required signing environment:

```text
CMDTAB_DEVELOPER_IDENTITY
CMDTAB_TEAM_ID
```

Choose exactly one notarization authentication mode.

### Named notarytool keychain profile

```text
CMDTAB_NOTARY_PROFILE
```

### App Store Connect API key

Required for every API key:

```text
CMDTAB_NOTARY_KEY_ID
CMDTAB_NOTARY_KEY_PATH
```

For team API keys also set:

```text
CMDTAB_NOTARY_ISSUER
```

Omit `CMDTAB_NOTARY_ISSUER` for an individual API key. The pipeline does not pass a synthetic or empty issuer value.

Plaintext Apple ID password authentication is intentionally unsupported.

## Non-destructive preflight

Before any build or submission, run:

```bash
chmod +x scripts/release/*.sh
./scripts/release/phase2-preflight.sh
```

The preflight:

- parses every Phase 2 shell and Python source contract;
- validates the exact Developer ID identity and Team ID shape;
- rejects missing or ambiguous certificate matches;
- checks API-key file permissions when API-key authentication is used;
- authenticates with `notarytool history`;
- does not build, sign, submit, staple, or publish an artifact.

## Automated command

Run on a macOS signing machine with protected credentials:

```bash
chmod +x scripts/release/*.sh
./scripts/release/run-phase2-qa.sh
```

The runner must write:

```text
dist/phase2-evidence/result.txt
dist/phase2-evidence/commit.txt
dist/phase2-evidence/commands.log
dist/phase2-evidence/unsigned-bundle-manifest.json
dist/phase2-evidence/unsigned-bundle-checksums.txt
dist/phase2-evidence/signed-bundle-manifest.json
dist/phase2-evidence/distribution-record.json
dist/phase2-evidence/codesign-report.txt
dist/phase2-evidence/embedded-entitlements.plist
dist/phase2-evidence/gatekeeper-assessment.txt
dist/phase2-evidence/stapler-validation.txt
dist/phase2-evidence/final-artifact.sha256
dist/phase2-evidence/notarization/notary-result.json
dist/phase2-evidence/notarization/notary-log.json
dist/phase2-evidence/notarization/submission-id.txt
dist/phase2-evidence/manual-checks.md
```

A successful automated run records:

```text
AUTOMATED_PASS
```

That is not the final Phase 2 pass. The clean-account checklist must also be completed and reviewed.

## QA/QC checklist

### Source and credential safety

- [ ] `verify-phase2-source.py` passes on the exact branch head.
- [ ] Every Phase 2 shell script passes `bash -n`.
- [ ] The distribution-record acceptance and rejection fixtures pass.
- [ ] No certificate, private key, API key, password, keychain, or credential profile is tracked.
- [ ] The requested Developer ID identity is present exactly once in the active keychain search list.
- [ ] `CMDTAB_TEAM_ID` matches the certificate name and signed bundle's `TeamIdentifier`.
- [ ] `notarytool history` authenticates without submitting an artifact.
- [ ] API-key file mode does not expose the key to group or other users.
- [ ] Release and resource entitlement plists are equal and contain only reviewed entries.
- [ ] GitHub Actions issue #30 acceptance criteria pass on the exact Phase 2 head.

### Unsigned input

- [ ] Phase 1 regression runner passes.
- [ ] Unsigned input bundle verifies as unsigned.
- [ ] Unsigned manifest and checksums are captured before signing.
- [ ] Unsigned reproducibility remains byte-for-byte stable.

### Signing

- [ ] Exact `Developer ID Application` authority is present.
- [ ] Hardened Runtime metadata is present.
- [ ] Secure timestamp is present.
- [ ] TeamIdentifier matches the intended team.
- [ ] Embedded entitlements exactly match the reviewed plist.
- [ ] Nested code is signed deepest-first without using `codesign --deep` as a signing operation.
- [ ] `codesign --verify --deep --strict --verbose=2` passes as a verification operation.

### Notarization and stapling

- [ ] `notarytool` returns `Accepted`.
- [ ] Submission ID is recorded.
- [ ] Detailed notarization log is recorded and reviewed.
- [ ] The notarization log contains no warning or issue.
- [ ] `stapler staple` succeeds.
- [ ] `stapler validate` succeeds on the app and on the ZIP-extracted app.

### Gatekeeper, archive, and traceability

- [ ] `spctl --assess --type execute --verbose=4` passes on the stapled app.
- [ ] The final ZIP passes archive integrity testing.
- [ ] The ZIP-extracted app passes strict codesign, entitlement, staple, and Gatekeeper verification.
- [ ] Final ZIP SHA-256 matches the sidecar and `distribution-record.json`.
- [ ] The distribution record identifies the exact source commit, unsigned manifest, signed manifest, Developer ID identity, Team ID, notarization submission, and final artifact.

### Clean-account manual acceptance

- [ ] Artifact is downloaded or transferred to a clean, non-development account.
- [ ] Gatekeeper displays the intended developer identity.
- [ ] App launches without bypassing Gatekeeper.
- [ ] Menu-bar-only behavior is preserved.
- [ ] Accessibility and Screen Recording can be granted normally.
- [ ] Command-Tab interception and exact-window activation work.
- [ ] Live previews, including Arc, work after permission grant.
- [ ] Deliberate quit and relaunch work.
- [ ] A second build signed by the same identity preserves macOS privacy association.
- [ ] Launch at Login works without creating duplicate processes.
- [ ] A real legacy beta profile migrates supported defaults and Keychain state.
- [ ] Rollback to the prior accepted build is documented and tested.

## Current blockers

- Apple Developer Program membership, Team ID, bundle registration, certificate, and notarization credential availability have not yet been evidenced in this record.
- Hosted GitHub Actions remain blocked by the private-repository usage allowance under issue #30.
- No signed artifact has yet been created, submitted, stapled, Gatekeeper-assessed, or clean-account tested on this branch.

## Current decision

**NO-GO.** Phase 2 source implementation is ready for review and credential preflight, but public distribution remains blocked until every checklist row above is passed or explicitly narrows the supported release contract.
