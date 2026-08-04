# G1 Artifact-Source Record — 2026-08-04

## Required exact evidence

The public beta requires an `arm64`-only unsigned artifact built twice from
distinct clean scratch directories, with file inventory, executable hashes,
bundle metadata, resources, entitlement, Sparkle, secret/local-path, and dSYM
review bound to the frozen candidate SHA.

Historical Phase 1 and prior source checks establish the policy and prove the
repository verifier exists. They do **not** prove the next frozen candidate.
The current working tree has later source changes, so neither
`081ec04199885dffb5c7dddd30b6dcd23279bd55`, the documentation commit
`2bcb2275b41cc6712dec8abcb2a4b62f3569143c`, nor the current operational-controls
candidate `5c6bf288baae9f20bc5b43e5ddfe351539b4a08d` may be inherited as exact
unsigned-artifact evidence.

## Status

**NOT TESTED for the next frozen candidate.** This deliberately replaces the
unsupported blanket G1 repository pass; it is not a signing or distribution
blocker waiver.

## Required command and record

Run on the frozen source SHA:

```bash
python3 scripts/release/release_config.py verify-repository
./scripts/release/reproducibility-check.sh
```

Record the exact SHA, commands/exits, two scratch paths (not credentials),
artifact SHA-256 values, bundle verifier output, reviewed differences, QA/QC
reviewer, status, and next action. Do not commit artifacts, private dSYMs, or
machine-local paths.

**Next action:** run this record after the next source candidate is frozen and
before asking for Developer-ID credentials.
