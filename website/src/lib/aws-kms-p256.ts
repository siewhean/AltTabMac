import {
  GetPublicKeyCommand,
  KMSClient,
  SignCommand,
} from "@aws-sdk/client-kms";
import { fromWebToken } from "@aws-sdk/credential-providers";
import { getVercelOidcToken } from "@vercel/oidc";
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

export type CmdTabKmsSignerConfiguration = {
  region: string;
  key: AwsKmsSigningKeyConfiguration;
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

  const trial = loadTrialKmsSigningConfiguration(env);
  const license = loadLicenseKmsSigningConfiguration(env);
  const configuration: CmdTabKmsSigningConfiguration = {
    region: trial.region,
    trial: trial.key,
    license: license.key,
  };
  if (configuration.region !== license.region) {
    throw new Error("Trial and license KMS signing regions must match.");
  }
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

function loadKmsSignerConfiguration(
  env: SigningEnvironment,
  kind: "trial" | "license",
): CmdTabKmsSignerConfiguration {
  const prefix = kind === "trial" ? "CMDTAB_TRIAL" : "CMDTAB_LICENSE";
  if (
    env.VERCEL_ENV === "production" &&
    (env.CMDTAB_TRIAL_PRIVATE_KEY_PEM?.trim() ||
      env.CMDTAB_LICENSE_PRIVATE_KEY_PEM?.trim())
  ) {
    throw new Error(
      `Production ${kind} signing must use AWS KMS; exported PEM is forbidden.`,
    );
  }

  const configuration: CmdTabKmsSignerConfiguration = {
    region: required(env, "AWS_REGION"),
    key: {
      keyId: required(env, `${prefix}_KMS_KEY_ID`),
      kid: required(env, `${prefix}_SIGNING_KID`),
    },
  };
  if (!validKid(configuration.key.kid)) {
    throw new Error("Signing kid contains unsupported characters.");
  }
  // Trial issuance must not depend on paid configuration, but when both are
  // configured they must never share a key or kid.
  const otherPrefix = kind === "trial" ? "CMDTAB_LICENSE" : "CMDTAB_TRIAL";
  const otherKeyId = env[`${otherPrefix}_KMS_KEY_ID`]?.trim();
  const otherKid = env[`${otherPrefix}_SIGNING_KID`]?.trim();
  if (
    (otherKeyId && otherKeyId === configuration.key.keyId) ||
    (otherKid && otherKid === configuration.key.kid)
  ) {
    throw new Error("Trial and license signing keys and kids must be separate.");
  }
  return configuration;
}

/** Trial issuance deliberately has no paid-license configuration dependency. */
export function loadTrialKmsSigningConfiguration(
  env: SigningEnvironment = process.env,
): CmdTabKmsSignerConfiguration {
  return loadKmsSignerConfiguration(env, "trial");
}

/** Paid issuance is isolated from the beta-trial path. */
export function loadLicenseKmsSigningConfiguration(
  env: SigningEnvironment = process.env,
): CmdTabKmsSignerConfiguration {
  return loadKmsSignerConfiguration(env, "license");
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

export function loadTrialPublicKeyring(
  env: SigningEnvironment = process.env,
): Readonly<Record<string, string>> {
  return parsePublicKeyring(
    required(env, "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON"),
    "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON",
  );
}

export class AwsKmsP256Signer implements P256TokenSigner {
  private validatedPublicKeyDer?: Promise<Buffer>;

  /**
   * `publishedPublicKeyDerBase64` is the keyring entry the app will verify
   * with: a string is compared before the first signature, `null` means it is
   * required but missing (signing fails closed), `undefined` skips the check.
   */
  constructor(
    readonly kid: string,
    private readonly keyId: string,
    private readonly client: AwsKmsP256Client,
    private readonly publishedPublicKeyDerBase64?: string | null,
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
    if (this.publishedPublicKeyDerBase64 === null) {
      throw new Error(`No published public key for signing kid ${this.kid}.`);
    }
    if (
      this.publishedPublicKeyDerBase64 !== undefined &&
      !publicKeyDer.equals(Buffer.from(this.publishedPublicKeyDerBase64, "base64"))
    ) {
      throw new Error(
        `AWS KMS public key does not match the published keyring entry for ${this.kid}.`,
      );
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
  configuration: CmdTabKmsSignerConfiguration,
  env: SigningEnvironment,
) {
  const roleArn = required(env, "AWS_ROLE_ARN");
  // In a Vercel Function the OIDC token arrives per request in the
  // `x-vercel-oidc-token` header; `VERCEL_OIDC_TOKEN` exists only in builds
  // and local development. Resolve it when credentials are first needed
  // (inside the request), never at module load, and never cache it.
  const credentials = async () =>
    fromWebToken({
      roleArn,
      roleSessionName: `cmdtab-${env.VERCEL_ENV ?? "deployment"}`,
      webIdentityToken: await getVercelOidcToken(),
      clientConfig: { region: configuration.region },
    })();
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

  const configuration = kind === "trial"
    ? loadTrialKmsSigningConfiguration(env)
    : loadLicenseKmsSigningConfiguration(env);
  const keyringName =
    kind === "trial"
      ? "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON"
      : "CMDTAB_LICENSE_PUBLIC_KEYRING_JSON";
  const keyringJson = env[keyringName]?.trim();
  // Never sign with a key the shipped app cannot verify: production requires
  // the KMS key to match its published keyring entry.
  const published = keyringJson
    ? (parsePublicKeyring(keyringJson, keyringName)[configuration.key.kid] ?? null)
    : env.VERCEL_ENV === "production"
      ? null
      : undefined;
  return new AwsKmsP256Signer(
    configuration.key.kid,
    configuration.key.keyId,
    productionKmsClient(configuration, env),
    published,
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
