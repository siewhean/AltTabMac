import { createSign, randomUUID } from "node:crypto";

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
