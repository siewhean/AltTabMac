import {
  createPublicKey,
  createSign,
  createVerify,
  randomUUID,
} from "node:crypto";

const TOKEN_PREFIX = "CMDTAB1";
const PRODUCT_IDENTIFIER = "cmdtab";

export type CmdTabLicensePayload = {
  version: number;
  product: string;
  email: string;
  licenseID: string;
  issuedAt: string;
  purchaserName?: string;
};

export function base64UrlEncode(value: Buffer | string) {
  return Buffer.from(value)
    .toString("base64")
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/g, "");
}

export function issueCmdTabLicenseToken(input: {
  privateKeyPem: string;
  email: string;
  purchaserName?: string;
  licenseID?: string;
  issuedAt?: string;
}) {
  const payload: CmdTabLicensePayload = {
    version: 1,
    product: PRODUCT_IDENTIFIER,
    email: input.email.trim().toLowerCase(),
    licenseID: input.licenseID?.trim() || randomUUID().toUpperCase(),
    issuedAt: input.issuedAt ?? new Date().toISOString(),
    purchaserName: input.purchaserName?.trim() || undefined,
  };

  const payloadJson = JSON.stringify(payload);
  const payloadBuffer = Buffer.from(payloadJson, "utf8");
  const signer = createSign("sha256");
  signer.update(payloadBuffer);
  signer.end();

  const signature = signer.sign({
    key: input.privateKeyPem,
    dsaEncoding: "der",
  });

  return {
    payload,
    token: [
      TOKEN_PREFIX,
      base64UrlEncode(payloadBuffer),
      base64UrlEncode(signature),
    ].join("."),
  };
}

export type VerifiedCmdTabLicense = {
  tokenVersion: 1;
  payload: CmdTabLicensePayload;
};

export function verifyCmdTabLicenseToken(input: {
  token: string;
  privateKeyPem?: string;
  publicKeyPem?: string;
}): VerifiedCmdTabLicense | null {
  const token = input.token.trim().replace(/\s+/g, "");
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== TOKEN_PREFIX) return null;

  try {
    const verificationKeyPem = input.publicKeyPem ?? input.privateKeyPem;
    if (!verificationKeyPem) return null;
    const payloadBuffer = Buffer.from(
      parts[1].replaceAll("-", "+").replaceAll("_", "/"),
      "base64",
    );
    const signature = Buffer.from(
      parts[2].replaceAll("-", "+").replaceAll("_", "/"),
      "base64",
    );
    const verifier = createVerify("sha256");
    verifier.update(payloadBuffer);
    verifier.end();
    if (!verifier.verify(createPublicKey(verificationKeyPem), signature)) {
      return null;
    }

    const payload = JSON.parse(payloadBuffer.toString("utf8")) as Partial<CmdTabLicensePayload>;
    if (
      payload.version !== 1 ||
      payload.product !== PRODUCT_IDENTIFIER ||
      typeof payload.email !== "string" ||
      typeof payload.licenseID !== "string" ||
      typeof payload.issuedAt !== "string" ||
      payload.email.length > 320 ||
      payload.licenseID.length < 1 ||
      payload.licenseID.length > 160 ||
      !Number.isFinite(Date.parse(payload.issuedAt))
    ) {
      return null;
    }

    return {
      tokenVersion: 1,
      payload: payload as CmdTabLicensePayload,
    };
  } catch {
    return null;
  }
}
