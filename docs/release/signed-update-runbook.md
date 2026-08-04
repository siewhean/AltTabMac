# Signed Update Runbook

CmdTab uses Sparkle 2.9.2 on the isolated beta channel. The application keeps
one `SPUStandardUpdaterController` for its lifetime, uses Sparkle's standard
second-launch consent prompt, and checks daily only after the user opts in. Its
packaged feed is `https://cmdtab.net/releases/beta/appcast.xml`; the stable
endpoint remains unavailable until GA.

## One-time owner setup

1. Run Sparkle's `generate_keys` tool on the protected release Mac.
2. Back up the private Ed25519 key separately from the repository.
3. Record the printed public key as the protected
   `CMDTAB_SPARKLE_PUBLIC_ED_KEY` release variable.
4. Configure the Developer ID identity and a `notarytool` Keychain profile.

The private update key, Apple credentials, and exported certificates must never
be committed. Local QA bundles intentionally omit `SUPublicEDKey`, so their
update UI is disabled and they cannot contact a production feed.

## Build and notarize

```bash
export CMDTAB_SIGNING_IDENTITY='Developer ID Application: Owner (TEAMID)'
export CMDTAB_NOTARY_PROFILE='cmdtab-notary-profile'
export CMDTAB_SPARKLE_PUBLIC_ED_KEY='<base64-public-key>'
./scripts/release/build-notarized-dmg.sh
```

The script signs Sparkle's nested services leaf-first, signs the app with
Hardened Runtime and a secure timestamp, notarizes and staples the app and DMG,
then records Gatekeeper output. The credential-gated release path requests
`arm64` and rejects the artifact if the app or any Sparkle helper is missing its
Apple Silicon slice. An accepted local ad-hoc build is not equivalent evidence,
and this beta does not support Intel execution.

## Prepare beta update metadata

The immutable DMG URL must include the exact 40-character source SHA and end in
`CmdTab-{version}-{build}.dmg`. Before signing, set `ReleaseConfig.json` and
the rendered bundle to the intended three-integer Apple marketing version and
build (for example `1.0.0` and `1`). `--beta` identifies the prerelease
(`1.0.0-beta.N`) and must use that bundled marketing version as its base. The
publication command mounts and verifies the DMG before it writes any metadata.

```bash
./scripts/release/prepare-release-publication.sh --beta 1.0.0-beta.1 \
  dist/release/CmdTab-1.0.0-beta.1-1.dmg \
  "https://releases.cmdtab.net/<source-sha>/CmdTab-1.0.0-beta.1-1.dmg" \
  "<source-sha>" \
  dist/release/publication \
  previous-beta.json
```

The command verifies the mounted app's `CFBundleShortVersionString` base and
`CFBundleVersion`, bytes and SHA-256, rejects an equal or lower build than the
published beta manifest, generates EdDSA enclosure and feed signatures, and
validates both the appcast build and bundled marketing version against the
manifest. `--beta` is required and must use `x.y.z-beta.N`; it emits `beta.json` and
`beta-appcast.xml`. Omitting `--beta` preserves the stable-only command for GA
and emits `stable.json` and `appcast.xml`.

Publish only in this order:

1. Immutable notarized DMG.
2. Copy the generated `beta.json` to the repository's `release/beta.json`,
   rebuild and deploy the website, then verify that `/releases/beta.json` is
   byte-for-byte equivalent and `/trial` links to its immutable `dmgURL`.
   Stable surfaces remain unavailable until GA.
3. Publish `beta-appcast.xml` as `/releases/beta/appcast.xml` last.

Rollback never lowers a client build number. Rebuild reverted source as a newly
signed, notarized release with a strictly higher `CFBundleVersion`.

## Required external evidence

Before public promotion, retain the accepted notarization JSON, stapler
validation, Gatekeeper output, manifest, DMG checksum, and successful
N-to-N+1 installations on clean Apple Silicon Macs. Repository tests cannot
substitute for those credentials, machines, or live update endpoints.
