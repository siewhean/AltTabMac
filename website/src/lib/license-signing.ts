import {
  createPrivateKey,
  createPublicKey,
  createSign,
  type KeyObject,
} from "node:crypto";

import {
  CMDTAB_TOKEN_AUDIENCE,
  CMDTAB_TOKEN_V2,
  CMDTAB_TOKEN_V2_PREFIX,
  CMDTAB_V1_UPDATE_ENTITLEMENT,
  LICENSE_LEASE_SECONDS,
  hashEntitlementIdentifier,
  type CmdTabBindingType,
  type CmdTabEntitlementType,
  type CmdTabTokenV2Payload,
} from "./entitlement-token";
import { base64UrlEncode } from "./license-token";

export interface P256TokenSigner {
  readonly kid: string;
  sign(message: Buffer): Promise<Buffer>;
  getPublicKeyDer(): Promise<Buffer>;
}

export type TokenV2IssueInput = {
  signer: P256TokenSigner;
  typ: CmdTabEntitlementType;
  /** Raw identifiers, or the already-hashed claims when renewing a lease. */
  subjectIdentifier: string | { hash: string };
  orderIdentifier: string | { hash: string };
  binding: {
    typ: CmdTabBindingType;
    value: string;
  };
  issuedAt?: Date;
};

function claimHash(identifier: string | { hash: string }) {
  if (typeof identifier === "string") return hashEntitlementIdentifier(identifier);
  if (!/^[a-f0-9]{64}$/.test(identifier.hash)) {
    throw new Error("Precomputed claim hashes must be SHA-256 hex.");
  }
  return identifier.hash;
}

export async function issueCmdTabTokenV2(input: TokenV2IssueInput) {
  if (
    (input.typ === "trial" && input.binding.typ !== "install") ||
    (input.typ === "license" && input.binding.typ !== "activation")
  ) {
    throw new Error(
      "Trial tokens require install binding and license tokens require activation binding.",
    );
  }
  const issuedAt = Math.floor((input.issuedAt ?? new Date()).getTime() / 1000);
  if (!Number.isSafeInteger(issuedAt) || issuedAt < 0) {
    throw new Error("Token issue time must be a valid date.");
  }

  const payload: CmdTabTokenV2Payload = {
    v: CMDTAB_TOKEN_V2,
    kid: input.signer.kid,
    typ: input.typ,
    aud: CMDTAB_TOKEN_AUDIENCE,
    sub: claimHash(input.subjectIdentifier),
    order: claimHash(input.orderIdentifier),
    binding: {
      typ: input.binding.typ,
      hash: hashEntitlementIdentifier(input.binding.value),
    },
    iat: issuedAt,
    updates: CMDTAB_V1_UPDATE_ENTITLEMENT,
    exp:
      issuedAt +
      (input.typ === "trial" ? 14 * 24 * 60 * 60 : LICENSE_LEASE_SECONDS),
  };
  const payloadBuffer = Buffer.from(JSON.stringify(payload), "utf8");
  const signature = await input.signer.sign(payloadBuffer);
  return {
    payload,
    token: [
      CMDTAB_TOKEN_V2_PREFIX,
      base64UrlEncode(payloadBuffer),
      base64UrlEncode(signature),
    ].join("."),
  };
}

/**
 * Local/test-only signer. Production configuration rejects exported PEM and
 * must construct AwsKmsP256Signer instead.
 */
export class LocalPemP256Signer implements P256TokenSigner {
  private readonly key: KeyObject;

  constructor(
    readonly kid: string,
    privateKeyPem: string,
  ) {
    this.key = createPrivateKey(privateKeyPem);
    if (
      this.key.asymmetricKeyType !== "ec" ||
      this.key.asymmetricKeyDetails?.namedCurve !== "prime256v1"
    ) {
      throw new Error("Local token signing requires a P-256 private key.");
    }
  }

  async sign(message: Buffer) {
    const signer = createSign("sha256");
    signer.update(message);
    signer.end();
    return signer.sign({ key: this.key, dsaEncoding: "der" });
  }

  async getPublicKeyDer() {
    return Buffer.from(
      createPublicKey(this.key).export({ format: "der", type: "spki" }),
    );
  }
}
