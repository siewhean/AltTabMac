const DEFAULT_SITE_URL = "https://cmdtab.net";

type ServerEnv = {
  resendApiKey: string;
  waitlistFromEmail: string;
  waitlistToEmail: string;
  waitlistReplyToEmail?: string;
  lemonsqueezyWebhookSecret?: string;
  cmdtabLicensePrivateKeyPem?: string;
  licenseDeliveryFromEmail?: string;
  licenseLookupPepper?: string;
  licenseOutboxSecret?: string;
  lemonsqueezyStoreId?: number;
  lemonsqueezyProductId?: number;
  lemonsqueezyVariantId?: number;
  lemonsqueezyExpectedTestMode?: boolean;
};

type EnvironmentMap = Readonly<Record<string, string | undefined>>;

function optionalPositiveInteger(value: string | undefined) {
  const parsed = Number(value?.trim());
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : undefined;
}

function optionalBoolean(value: string | undefined) {
  if (value?.trim().toLowerCase() === "true") return true;
  if (value?.trim().toLowerCase() === "false") return false;
  return undefined;
}

export function isCommerceLaunchEnabled(
  environment: EnvironmentMap = process.env,
) {
  return environment.CMDTAB_REQUIRE_COMMERCE_READY?.trim() === "1";
}

const KNOWN_SECRET_PLACEHOLDERS = new Set([
  "replace_with_a_random_internal_worker_secret",
  "replace_with_a_random_cron_secret",
]);

export function optionalStrongInternalSecret(value: string | undefined) {
  const candidate = value?.trim();
  if (
    !candidate ||
    candidate.length < 32 ||
    KNOWN_SECRET_PLACEHOLDERS.has(candidate)
  ) {
    return undefined;
  }
  return candidate;
}

export function getSiteUrl() {
  const candidate =
    process.env.NEXT_PUBLIC_SITE_URL?.trim() ||
    process.env.SITE_URL?.trim() ||
    DEFAULT_SITE_URL;

  try {
    return new URL(candidate).toString().replace(/\/$/, "");
  } catch {
    return DEFAULT_SITE_URL;
  }
}

export function getServerEnv(): ServerEnv {
  const required = {
    resendApiKey: process.env.RESEND_API_KEY?.trim(),
    waitlistFromEmail: process.env.WAITLIST_FROM_EMAIL?.trim(),
    waitlistToEmail: process.env.WAITLIST_TO_EMAIL?.trim(),
    waitlistReplyToEmail: process.env.WAITLIST_REPLY_TO_EMAIL?.trim() || undefined,
    lemonsqueezyWebhookSecret:
      process.env.LEMONSQUEEZY_WEBHOOK_SECRET?.trim() || undefined,
    cmdtabLicensePrivateKeyPem:
      process.env.CMDTAB_LICENSE_PRIVATE_KEY_PEM?.trim() || undefined,
    licenseDeliveryFromEmail:
      process.env.LICENSE_DELIVERY_FROM_EMAIL?.trim() || undefined,
    licenseLookupPepper:
      process.env.CMDTAB_LICENSE_LOOKUP_PEPPER?.trim() || undefined,
    licenseOutboxSecret: optionalStrongInternalSecret(
      process.env.CMDTAB_LICENSE_OUTBOX_SECRET,
    ),
    lemonsqueezyStoreId: optionalPositiveInteger(
      process.env.CMDTAB_LEMONSQUEEZY_STORE_ID,
    ),
    lemonsqueezyProductId: optionalPositiveInteger(
      process.env.CMDTAB_LEMONSQUEEZY_PRODUCT_ID,
    ),
    lemonsqueezyVariantId: optionalPositiveInteger(
      process.env.CMDTAB_LEMONSQUEEZY_VARIANT_ID,
    ),
    lemonsqueezyExpectedTestMode: optionalBoolean(
      process.env.CMDTAB_LEMONSQUEEZY_EXPECT_TEST_MODE,
    ),
  };

  if (!required.resendApiKey || !required.waitlistFromEmail || !required.waitlistToEmail) {
    throw new Error("Missing required waitlist email environment variables.");
  }

  return {
    resendApiKey: required.resendApiKey,
    waitlistFromEmail: required.waitlistFromEmail,
    waitlistToEmail: required.waitlistToEmail,
    waitlistReplyToEmail: required.waitlistReplyToEmail,
    lemonsqueezyWebhookSecret: required.lemonsqueezyWebhookSecret,
    cmdtabLicensePrivateKeyPem: required.cmdtabLicensePrivateKeyPem,
    licenseDeliveryFromEmail: required.licenseDeliveryFromEmail,
    licenseLookupPepper: required.licenseLookupPepper,
    licenseOutboxSecret: required.licenseOutboxSecret,
    lemonsqueezyStoreId: required.lemonsqueezyStoreId,
    lemonsqueezyProductId: required.lemonsqueezyProductId,
    lemonsqueezyVariantId: required.lemonsqueezyVariantId,
    lemonsqueezyExpectedTestMode: required.lemonsqueezyExpectedTestMode,
  };
}

export function getLicenseLifecycleEnv() {
  const legacyPublicKeyPem =
    process.env.CMDTAB_LICENSE_V1_PUBLIC_KEY_PEM?.trim() || null;
  const localPrivateKeyPem =
    process.env.VERCEL_ENV === "production"
      ? null
      : process.env.CMDTAB_LICENSE_PRIVATE_KEY_PEM?.trim() || null;
  return {
    verificationKeyPem: legacyPublicKeyPem ?? localPrivateKeyPem,
    lookupPepper: process.env.CMDTAB_LICENSE_LOOKUP_PEPPER?.trim() || null,
    outboxSecret:
      optionalStrongInternalSecret(
        process.env.CMDTAB_LICENSE_OUTBOX_SECRET,
      ) ?? null,
  };
}
