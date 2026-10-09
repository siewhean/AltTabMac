import {
  createHash,
  createPublicKey,
  createVerify,
  timingSafeEqual,
} from "node:crypto";

import {
  verifyCmdTabLicenseToken,
  type VerifiedCmdTabLicense,
} from "./license-token";

export const CMDTAB_TOKEN_V2_PREFIX = "CMDTAB2";
export const CMDTAB_TOKEN_AUDIENCE = "cmdtab";
export const CMDTAB_TOKEN_V2 = 2;
export const CMDTAB_V1_UPDATE_ENTITLEMENT = "1.x";

const SHA256_HEX = /^[a-f0-9]{64}$/;
const KEY_ID = /^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$/;
const MAX_TOKEN_BYTES = 16 * 1024;
const TRIAL_SECONDS = 14 * 24 * 60 * 60;
// Paid entitlements are a renewable lease: the app renews while online, so a
// refund, revocation or remote deactivation takes effect within one lease even
// if the Mac blocks cmdtab.net.
export const LICENSE_LEASE_SECONDS = 30 * 24 * 60 * 60;

export type CmdTabEntitlementType = "trial" | "license";
export type CmdTabBindingType = "install" | "activation";

export type CmdTabTokenV2Payload = {
  v: 2;
  kid: string;
  typ: CmdTabEntitlementType;
  aud: "cmdtab";
  sub: string;
  order: string;
  binding: {
    typ: CmdTabBindingType;
    hash: string;
  };
  iat: number;
  exp?: number;
  updates: "1.x";
};

export type VerifiedCmdTabEntitlement =
  | {
      tokenVersion: 1;
      kind: "license";
      payload: VerifiedCmdTabLicense["payload"];
    }
  | {
      tokenVersion: 2;
      kind: CmdTabEntitlementType;
      payload: CmdTabTokenV2Payload;
    };

export type CmdTabTokenV2Verification = {
  token: string;
  keyring: Readonly<Record<string, string | Buffer>>;
  expectedType?: CmdTabEntitlementType;
  expectedBinding?: {
    typ: CmdTabBindingType;
    value: string;
  };
  now?: Date;
  /** Renewal only: accept an otherwise valid token whose lease has lapsed. */
  allowExpired?: boolean;
};

export function hashEntitlementIdentifier(value: string) {
  const normalized = value.trim().toLowerCase();
  if (!normalized) {
    throw new Error("Entitlement identifiers must not be empty.");
  }
  return createHash("sha256").update(normalized, "utf8").digest("hex");
}

export function base64UrlDecodeStrict(value: string): Buffer | null {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) return null;
  const decoded = Buffer.from(
    value.replaceAll("-", "+").replaceAll("_", "/"),
    "base64",
  );
  const canonical = decoded
    .toString("base64")
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/g, "");
  return canonical === value ? decoded : null;
}

export function validateCmdTabTokenV2Payload(
  value: unknown,
): CmdTabTokenV2Payload | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const payload = value as Partial<CmdTabTokenV2Payload>;
  if (
    payload.v !== CMDTAB_TOKEN_V2 ||
    !KEY_ID.test(payload.kid ?? "") ||
    (payload.typ !== "trial" && payload.typ !== "license") ||
    payload.aud !== CMDTAB_TOKEN_AUDIENCE ||
    !SHA256_HEX.test(payload.sub ?? "") ||
    !SHA256_HEX.test(payload.order ?? "") ||
    payload.updates !== CMDTAB_V1_UPDATE_ENTITLEMENT ||
    typeof payload.iat !== "number" ||
    !Number.isSafeInteger(payload.iat) ||
    payload.iat < 0 ||
    !payload.binding ||
    (payload.binding.typ !== "install" &&
      payload.binding.typ !== "activation") ||
    !SHA256_HEX.test(payload.binding.hash ?? "")
  ) {
    return null;
  }

  if (payload.typ === "trial") {
    if (
      payload.binding.typ !== "install" ||
      !Number.isSafeInteger(payload.exp) ||
      payload.exp !== payload.iat + TRIAL_SECONDS
    ) {
      return null;
    }
  } else if (
    payload.binding.typ !== "activation" ||
    !Number.isSafeInteger(payload.exp) ||
    payload.exp !== payload.iat + LICENSE_LEASE_SECONDS
  ) {
    return null;
  }

  return payload as CmdTabTokenV2Payload;
}

export function verifyCmdTabTokenV2(
  input: CmdTabTokenV2Verification,
): VerifiedCmdTabEntitlement | null {
  const token = input.token.trim().replace(/\s+/g, "");
  if (Buffer.byteLength(token, "utf8") > MAX_TOKEN_BYTES) return null;
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== CMDTAB_TOKEN_V2_PREFIX) return null;

  try {
    const payloadBuffer = base64UrlDecodeStrict(parts[1]);
    const signature = base64UrlDecodeStrict(parts[2]);
    if (!payloadBuffer || !signature) return null;

    const payload = validateCmdTabTokenV2Payload(
      JSON.parse(payloadBuffer.toString("utf8")),
    );
    if (!payload || (input.expectedType && payload.typ !== input.expectedType)) {
      return null;
    }

    const publicKeyDer = input.keyring[payload.kid];
    if (!publicKeyDer) return null;
    const publicKey = createPublicKey({
      key:
        typeof publicKeyDer === "string"
          ? Buffer.from(publicKeyDer, "base64")
          : publicKeyDer,
      format: "der",
      type: "spki",
    });
    if (
      publicKey.asymmetricKeyType !== "ec" ||
      publicKey.asymmetricKeyDetails?.namedCurve !== "prime256v1"
    ) {
      return null;
    }
    const verifier = createVerify("sha256");
    verifier.update(payloadBuffer);
    verifier.end();
    if (!verifier.verify({ key: publicKey, dsaEncoding: "der" }, signature)) {
      return null;
    }

    if (input.expectedBinding) {
      if (payload.binding.typ !== input.expectedBinding.typ) return null;
      const expectedHash = Buffer.from(
        hashEntitlementIdentifier(input.expectedBinding.value),
        "hex",
      );
      const actualHash = Buffer.from(payload.binding.hash, "hex");
      if (
        expectedHash.length !== actualHash.length ||
        !timingSafeEqual(expectedHash, actualHash)
      ) {
        return null;
      }
    }

    if (
      !input.allowExpired &&
      payload.exp! <= Math.floor((input.now ?? new Date()).getTime() / 1000)
    ) {
      return null;
    }

    return { tokenVersion: 2, kind: payload.typ, payload };
  } catch {
    return null;
  }
}

export function verifyCmdTabEntitlementToken(input: {
  token: string;
  v2Keyring: Readonly<Record<string, string | Buffer>>;
  legacyV1PrivateKeyPem?: string;
  legacyV1PublicKeyPem?: string;
  expectedType?: CmdTabEntitlementType;
  expectedBinding?: {
    typ: CmdTabBindingType;
    value: string;
  };
  now?: Date;
}): VerifiedCmdTabEntitlement | null {
  if (input.token.trim().startsWith(`${CMDTAB_TOKEN_V2_PREFIX}.`)) {
    return verifyCmdTabTokenV2({
      token: input.token,
      keyring: input.v2Keyring,
      expectedType: input.expectedType,
      expectedBinding: input.expectedBinding,
      now: input.now,
    });
  }

  if (
    (!input.legacyV1PrivateKeyPem && !input.legacyV1PublicKeyPem) ||
    input.expectedType === "trial"
  ) return null;
  const legacy = verifyCmdTabLicenseToken({
    token: input.token,
    privateKeyPem: input.legacyV1PrivateKeyPem,
    publicKeyPem: input.legacyV1PublicKeyPem,
  });
  return legacy
    ? { tokenVersion: 1, kind: "license", payload: legacy.payload }
    : null;
}
