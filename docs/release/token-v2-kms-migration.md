# Token v2 and AWS KMS migration

Status: the versioned issuer, verifier, native keyring, AWS KMS adapter,
trial route, and device-activation route are integrated. Production keys are
provisioned and trial signing is verified live (see below). Embedding the
public keyrings in the signed app remains an external release gate. The legacy `CMDTAB1` verifier remains available
during migration.

## Token contract

`CMDTAB2.<payload>.<P-256 DER signature>` signs the exact UTF-8 JSON payload.
The payload contains:

- `v: 2`, `kid`, `typ: trial|license`, and `aud: cmdtab`;
- SHA-256 `sub` and `order` identifiers, with no email or raw order identifier;
- an `install` or `activation` binding containing only a SHA-256 hash;
- integer UTC `iat`, exact 14-day `exp` for trials, and no expiry for paid
  licenses;
- `updates: 1.x`.

The native verifier selects the P-256 public key by signed `kid`, checks the
expected entitlement type and binding, rejects unknown keys or malformed
claims, and keeps paid v2 licenses valid offline without an expiry check.
`CMDTAB1` paid licenses remain verifiable against the legacy public key.

## Production KMS contract

Provision two asymmetric `ECC_NIST_P256`, `SIGN_VERIFY` AWS KMS keys: one for
trials and one for paid licenses. Configure:

```text
AWS_REGION
AWS_ROLE_ARN
CMDTAB_TRIAL_KMS_KEY_ID
CMDTAB_TRIAL_SIGNING_KID
CMDTAB_LICENSE_KMS_KEY_ID
CMDTAB_LICENSE_SIGNING_KID
CMDTAB_TRIAL_PUBLIC_KEYRING_JSON
CMDTAB_LICENSE_PUBLIC_KEYRING_JSON
CMDTAB_LICENSE_V1_PUBLIC_KEY_PEM
```

The production Vercel OIDC role must be scoped to the production project and
environment, and may call only `kms:Sign` and `kms:GetPublicKey` on those two
key ARNs. It must not receive `Decrypt`, key-management, or wildcard-resource
permissions. The signer reads the OIDC token per request with `@vercel/oidc` (`getVercelOidcToken()`): in a Vercel Function it arrives in the `x-vercel-oidc-token` header, while `VERCEL_OIDC_TOKEN` is set only in builds and local development. Do not add it to the project environment. No private
PEM is exported, stored in Vercel, logged, or returned by an API. Production
configuration fails closed if either legacy/local PEM variable is present.
Grandfathered `CMDTAB1` verification uses only
`CMDTAB_LICENSE_V1_PUBLIC_KEY_PEM`; it does not require the legacy private key.

`AwsKmsP256Signer` sends the exact payload as `RAW` with
`ECDSA_SHA_256` and verifies that `GetPublicKey` reports `SIGN_VERIFY` and the
same algorithm. `getTrialTokenSigner()` and `getLicenseTokenSigner()` create
route-ready signers using AWS SDK web-identity credentials. Their narrow client
interface keeps tests hermetic.

## Production provisioning (2026-10-10)

All values are public identifiers.

| Item | Value |
|---|---|
| AWS account / region | `880302055919` / `us-east-1` |
| Trial key | `arn:aws:kms:us-east-1:880302055919:key/a505db8e-d622-4603-b846-04542c50826a` (`alias/cmdtab-trial-signing`), kid `trial-2026-10` |
| License key | `arn:aws:kms:us-east-1:880302055919:key/31128a3f-47d7-4bf7-b2c1-6cf88bf43cee` (`alias/cmdtab-license-signing`), kid `license-2026-10` |
| OIDC provider | `oidc.vercel.com/siewheans-projects`, audience `https://vercel.com/siewheans-projects` |
| Role | `arn:aws:iam::880302055919:role/cmdtab-vercel-production-signing`; trusts only `owner:siewheans-projects:project:website:environment:production`; inline policy allows only `kms:Sign` and `kms:GetPublicKey` on the two keys |

Both keys are `ECC_NIST_P256` / `SIGN_VERIFY`. The two public keyrings pass
`release_config.validate_public_keyring`, and a KMS test signature from each
key verified against its keyring. The eight variables above are set in Vercel
Production only, and `CMDTAB_LICENSE_PRIVATE_KEY_PEM` is removed (from Preview
too, so Preview deployments cannot issue trials). After redeploying `main` at
`c2389cd1`, `POST https://cmdtab.net/api/trial/start` returned a `CMDTAB2`
trial token with kid `trial-2026-10` and a 14-day expiry whose signature
verifies against the trial keyring; it left one anonymous test claim
(`c0bab337-1212-46b9-b083-915ccdc620b9`, app version
`kms-selftest-2026-10-10`). Paid-license signing is not yet exercised because
commerce is disabled. The signed app must be built with the same
`CMDTAB_TRIAL_*` and `CMDTAB_LICENSE_*` kid and keyring values.

## Rotation and rollout

1. Add the new public key and `kid` to the server and native keyrings before
   issuing tokens with it.
2. Issue install-bound trials only with the trial key and activation-bound
   paid tokens only with the license key. New purchase emails carry an opaque
   high-entropy exchange credential; that credential cannot authorize offline
   access and is exchanged by the activation route for the device-bound token.
3. Keep prior public keys and v1 verification throughout the migration so
   already purchased licenses continue to work offline.
4. Remove an old public key only after all tokens it signed are no longer
   accepted. Perpetual paid-license keys therefore normally remain in the
   verification keyring indefinitely.
5. Treat full refunds, chargebacks, disputes, and manual revocations through
   the separate authoritative revocation/tombstone path; token expiry is not a
   substitute for paid-license revocation.

The local PEM signer exists only for hermetic tests and developer builds.
Production issuance must use the KMS-backed signer factory.
