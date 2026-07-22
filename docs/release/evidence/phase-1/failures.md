# Phase 1 Failures and Open Items

## Resolved from the first local macOS run

### Reproducibility path misclassified an automatically signed executable

The first local run passed 129 Swift tests, built and verified the normal ad-hoc QA bundle, then stopped during the two-build reproducibility check with:

```text
Expected unsigned bundle, but a signature is present.
```

The cause was not nondeterminism. Apple Silicon toolchains may add an ad-hoc code signature to the linked Mach-O executable even when the packaging script skips bundle signing.

**Resolution:** the unsigned reproducibility path removes the linker-generated signature from the staged executable copy before bundle verification and byte comparison. The normal local QA artifact remains ad-hoc signed.

### Deprecated noninteractive Keychain query API

The compiler warned that `kSecUseAuthenticationUIFail` is deprecated.

**Resolution:** Keychain migration queries use `LAContext`, `kSecUseAuthenticationContext`, and `interactionNotAllowed = true`. Repository verification rejects the deprecated literal.

### Failure evidence did not include the manual checklist

The first run exited before creating `manual-checks.md`.

**Resolution:** the QA runner creates `manual-checks.md` before tests and always writes `result.txt`. Failed runs retain a FAIL checklist and complete command log.

## Resolved from the second local macOS run

### Clean builds used different absolute SwiftPM scratch paths

The second run removed signatures correctly and verified both bundles as unsigned, but their executable hashes differed. The first build used a path ending in `first-scratch/swift-build`; the second used `second-scratch/swift-build`.

SwiftPM and the linker can preserve absolute module or debug paths in Mach-O metadata. Comparing binaries produced with different scratch paths therefore mixed two variables: clean-build determinism and build-path sensitivity.

**Resolution:** the reproducibility check now deletes and recreates one canonical scratch path before each build. This keeps the toolchain, source, flags, and absolute build path identical while still proving that no prior build output is reused. If binaries still differ, the script prints Mach-O UUIDs and the first differing byte offsets.

This Phase 1 gate proves repeatability on the same host, toolchain, source tree, and canonical release path. Cross-directory or cross-machine byte identity remains a separate claim and is not made.

## Open

- Re-run `scripts/release/run-phase1-qa.sh` on commit `ded7f0f48dc7c506ea115cbe30148a33117588a0` or later.
- Confirm the two clean unsigned bundles from the same canonical build path are byte-for-byte reproducible.
- Complete the manual menu-bar, Dock, native switcher, migration, permission re-grant, and deliberate-quit observations.
- Developer ID signing and notarization are intentionally out of scope until Phase 2.

## Deferred infrastructure

GitHub-hosted runners are unavailable because the private-repository Actions usage limit is exhausted. This does not count as a passed check. Local macOS execution is the accepted Phase 1 verification path under the user-approved quota waiver.
