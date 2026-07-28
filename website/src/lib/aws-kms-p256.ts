import {
  GetPublicKeyCommand,
  KMSClient,
  SignCommand,
} from "@aws-sdk/client-kms";
import { fromWebToken } from "@aws-sdk/credential-providers";
import { createPublicKey } from "node:crypto";

import { LocalPemP256Signer } from "./license-signing";
import type { P256TokenSigner } from "./license-signing";

export const AWS_KMS_P256_SIGNING_ALGORITHM = "ECDSA_SHA_256" as const;

export interface AwsKmsP256Client {
  sign(input: {
    KeyId: string;
    Message: Uint8Array;
    MessageType: "RAW";
    SigningAlgorithm: typeof AWS_KMS_P256_SIGNING_ALGORITHM;
  }): Promise<{ Signature?: Uint8Array }>;
  getPublicKey(input: { KeyId: string }): Promise<{
    PublicKey?: Uint8Array;
    KeyUsage?: string;
    SigningAlgorithms?: readonly string[];
  }>;
}

export type AwsKmsSigningKeyConfiguration = {
  keyId: string;
  kid: string;
};

export type CmdTabKmsSigningConfiguration = {
  region: string;
  trial: AwsKmsSigningKeyConfiguration;
  license: AwsKmsSigningKeyConfiguration;
};

export type CmdTabPublicKeyrings = {
  trial: Readonly<Record<string, string>>;
  license: Readonly<Record<string, string>>;
};

type SigningEnvironment = Readonly<Record<string, string | undefined>>;

function required(env: SigningEnvironment, name: string) {
  const value = env[name]?.trim();
  if (!value) throw new Error(`Missing required signing configuration: ${name}`);
  return value;
}

function validKid(kid: string) {
  return /^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$/.test(kid);
}

export function loadCmdTabKmsSigningConfiguration(
  env: SigningEnvironment = process.env,
): CmdTabKmsSigningConfiguration {
  if (
    env.VERCEL_ENV === "production" &&
    (env.CMDTAB_LICENSE_PRIVATE_KEY_PEM?.trim() ||
      env.CMDTAB_TRIAL_PRIVATE_KEY_PEM?.trim())
  ) {
    throw new Error(
      "Production signing must use AWS KMS; exported license PEM is forbidden.",
    );
  }

  const configuration: CmdTabKmsSigningConfiguration = {
    region: required(env, "AWS_REGION"),
    trial: {
      keyId: required(env, "CMDTAB_TRIAL_KMS_KEY_ID"),
      kid: required(env, "CMDTAB_TRIAL_SIGNING_KID"),
    },
    license: {
      keyId: required(env, "CMDTAB_LICENSE_KMS_KEY_ID"),
      kid: required(env, "CMDTAB_LICENSE_SIGNING_KID"),
    },
  };
  if (
    !validKid(configuration.trial.kid) ||
    !validKid(configuration.license.kid)
  ) {
    throw new Error("Signing kid contains unsupported characters.");
  }
  if (
    configuration.trial.keyId === configuration.license.keyId ||
    configuration.trial.kid === configuration.license.kid
  ) {
    throw new Error("Trial and license signing keys and kids must be separate.");
  }
  return configuration;
}

function parsePublicKeyring(value: string, name: string) {
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    throw new Error(`${name} must be a JSON object keyed by kid.`);
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${name} must be a JSON object keyed by kid.`);
  }
  const result: Record<string, string> = {};
  for (const [kid, publicKeyDerBase64] of Object.entries(parsed)) {
    if (!validKid(kid) || typeof publicKeyDerBase64 !== "string") {
      throw new Error(`${name} contains an invalid kid or public key.`);
    }
    try {
      const publicKey = createPublicKey({
        key: Buffer.from(publicKeyDerBase64, "base64"),
        format: "der",
        type: "spki",
      });
      if (
        publicKey.asymmetricKeyType !== "ec" ||
        publicKey.asymmetricKeyDetails?.namedCurve !== "prime256v1"
      ) {
        throw new Error("not P-256");
      }
    } catch {
      throw new Error(`${name} contains an invalid P-256 public key.`);
    }
    result[kid] = publicKeyDerBase64;
  }
  if (Object.keys(result).length === 0) {
    throw new Error(`${name} must contain at least one public key.`);
  }
  return Object.freeze(result);
}

export function loadCmdTabPublicKeyrings(
  env: SigningEnvironment = process.env,
): CmdTabPublicKeyrings {
  return {
    trial: parsePublicKeyring(
      required(env, "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON"),
      "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON",
    ),
    license: parsePublicKeyring(
      required(env, "CMDTAB_LICENSE_PUBLIC_KEYRING_JSON"),
      "CMDTAB_LICENSE_PUBLIC_KEYRING_JSON",
    ),
  };
}

export class AwsKmsP256Signer implements P256TokenSigner {
  private validatedPublicKeyDer?: Promise<Buffer>;

  constructor(
    readonly kid: string,
    private readonly keyId: string,
    private readonly client: AwsKmsP256Client,
  ) {}

  async sign(message: Buffer) {
    await this.getPublicKeyDer();
    const result = await this.client.sign({
      KeyId: this.keyId,
      Message: message,
      MessageType: "RAW",
      SigningAlgorithm: AWS_KMS_P256_SIGNING_ALGORITHM,
    });
    if (!result.Signature?.byteLength) {
      throw new Error("AWS KMS returned no signature.");
    }
    return Buffer.from(result.Signature);
  }

  async getPublicKeyDer() {
    this.validatedPublicKeyDer ??= this.loadAndValidatePublicKeyDer();
    return this.validatedPublicKeyDer;
  }

  private async loadAndValidatePublicKeyDer() {
    const result = await this.client.getPublicKey({ KeyId: this.keyId });
    if (
      result.KeyUsage !== "SIGN_VERIFY" ||
      !result.SigningAlgorithms?.includes(AWS_KMS_P256_SIGNING_ALGORITHM) ||
      !result.PublicKey?.byteLength
    ) {
      throw new Error("AWS KMS key is not an ECDSA SHA-256 signing key.");
    }
    const publicKeyDer = Buffer.from(result.PublicKey);
    const publicKey = createPublicKey({
      key: publicKeyDer,
      format: "der",
      type: "spki",
    });
    if (
      publicKey.asymmetricKeyType !== "ec" ||
      publicKey.asymmetricKeyDetails?.namedCurve !== "prime256v1"
    ) {
      throw new Error("AWS KMS key must use the P-256 curve.");
    }
    return publicKeyDer;
  }
}

class AwsSdkKmsP256Client implements AwsKmsP256Client {
  constructor(private readonly client: KMSClient) {}

  async sign(input: Parameters<AwsKmsP256Client["sign"]>[0]) {
    const result = await this.client.send(new SignCommand(input));
    return { Signature: result.Signature };
  }

  async getPublicKey(input: Parameters<AwsKmsP256Client["getPublicKey"]>[0]) {
    const result = await this.client.send(new GetPublicKeyCommand(input));
    return {
      PublicKey: result.PublicKey,
      KeyUsage: result.KeyUsage,
      SigningAlgorithms: result.SigningAlgorithms,
    };
  }
}

function productionKmsClient(
  configuration: CmdTabKmsSigningConfiguration,
  env: SigningEnvironment,
) {
  const webIdentityToken = required(env, "VERCEL_OIDC_TOKEN");
  const roleArn = required(env, "AWS_ROLE_ARN");
  const credentials = fromWebToken({
    roleArn,
    roleSessionName: `cmdtab-${env.VERCEL_ENV ?? "deployment"}`,
    webIdentityToken,
    clientConfig: { region: configuration.region },
  });
  return new AwsSdkKmsP256Client(
    new KMSClient({ region: configuration.region, credentials }),
  );
}

function getTokenSigner(
  kind: "trial" | "license",
  env: SigningEnvironment,
): P256TokenSigner {
  const privateKeyName =
    kind === "trial"
      ? "CMDTAB_TRIAL_PRIVATE_KEY_PEM"
      : "CMDTAB_LICENSE_PRIVATE_KEY_PEM";
  const kidName =
    kind === "trial"
      ? "CMDTAB_TRIAL_SIGNING_KID"
      : "CMDTAB_LICENSE_SIGNING_KID";
  const localPrivateKey = env[privateKeyName]?.trim();
  if (localPrivateKey && env.VERCEL_ENV !== "production") {
    return new LocalPemP256Signer(required(env, kidName), localPrivateKey);
  }

  const configuration = loadCmdTabKmsSigningConfiguration(env);
  const key = configuration[kind];
  return new AwsKmsP256Signer(
    key.kid,
    key.keyId,
    productionKmsClient(configuration, env),
  );
}

export function getTrialTokenSigner(
  env: SigningEnvironment = process.env,
): P256TokenSigner {
  return getTokenSigner("trial", env);
}

export function getLicenseTokenSigner(
  env: SigningEnvironment = process.env,
): P256TokenSigner {
  return getTokenSigner("license", env);
}
