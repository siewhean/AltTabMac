# Phase 1 Failures and Open Items

## Resolved from the first local macOS run

### Reproducibility path misclassified an automatically signed executable

The first local run passed 129 Swift tests, built and verified the normal ad-hoc QA bundle, then stopped during the two-build reproducibility check with:

```text
Expected unsigned bundle, but a signature is present.
```

The cause was not nondeterminism. Apple Silicon toolchains may add an ad-hoc code signature to the linked Mach-O executable even when the packaging script skips bundle signing.

**Resolution:** the unsigned reproducibility path now removes the linker-generated signature from the staged executable copy before bundle verification and byte comparison. The normal local QA artifact remains ad-hoc signed.

### Deprecated noninteractive Keychain query API

The compiler warned that `kSecUseAuthenticationUIFail` is deprecated.

**Resolution:** Keychain migration queries now use `LAContext`, `kSecUseAuthenticationContext`, and `interactionNotAllowed = true`. Repository verification rejects the deprecated literal.

### Failure evidence did not include the manual checklist

The first run exited before creating `manual-checks.md`.

**Resolution:** the QA runner now creates `manual-checks.md` before tests and always writes `result.txt`. Failed runs retain a FAIL checklist and complete command log.

## Open

- Re-run `scripts/release/run-phase1-qa.sh` on the updated branch.
- Confirm the two clean unsigned bundles are byte-for-byte reproducible.
- Complete the manual menu-bar, Dock, native switcher, migration, permission re-grant, and deliberate-quit observations.
- Developer ID signing and notarization are intentionally out of scope until Phase 2.

## Deferred infrastructure

GitHub-hosted runners are unavailable because the private-repository Actions usage limit is exhausted. This does not count as a passed check. Local macOS execution is the accepted Phase 1 verification path under the user-approved quota waiver.
