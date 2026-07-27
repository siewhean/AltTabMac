# Token v2 and AWS KMS migration

Status: the versioned issuer, verifier, native keyring, AWS KMS adapter,
trial route, and device-activation route are integrated. Production key
provisioning and embedding the resulting public keyrings in the signed app
remain external release gates. The legacy `CMDTAB1` verifier remains available
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
permissions. `VERCEL_OIDC_TOKEN` is supplied by Vercel at runtime. No private
PEM is exported, stored in Vercel, logged, or returned by an API. Production
configuration fails closed if either legacy/local PEM variable is present.
Grandfathered `CMDTAB1` verification uses only
`CMDTAB_LICENSE_V1_PUBLIC_KEY_PEM`; it does not require the legacy private key.

`AwsKmsP256Signer` sends the exact payload as `RAW` with
`ECDSA_SHA_256` and verifies that `GetPublicKey` reports `SIGN_VERIFY` and the
same algorithm. `getTrialTokenSigner()` and `getLicenseTokenSigner()` create
route-ready signers using AWS SDK web-identity credentials. Their narrow client
interface keeps tests hermetic.

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
