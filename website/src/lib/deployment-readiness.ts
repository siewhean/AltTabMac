type ReadinessEnvironment = Readonly<Record<string, string | undefined>>;

export type DeploymentReadinessSummary = {
  checkoutConfigured: boolean;
  databaseConfigured: boolean;
  webhookConfigured: boolean;
  emailConfigured: boolean;
  persistentRetryConfigured: boolean;
  sandboxSigningConfigured: boolean;
  productionSigningConfigured: boolean;
  stableReleasePublished: boolean;
  sandboxPurchaseFlowReady: boolean;
  productionPurchaseFlowReady: boolean;
  updateFlowReady: boolean;
};

function value(env: ReadinessEnvironment, name: string) {
  return env[name]?.trim() ?? "";
}

function allPresent(env: ReadinessEnvironment, names: readonly string[]) {
  return names.every((name) => Boolean(value(env, name)));
}

function positiveInteger(env: ReadinessEnvironment, name: string) {
  const parsed = Number(value(env, name));
  return Number.isSafeInteger(parsed) && parsed > 0;
}

function httpsUrl(env: ReadinessEnvironment, name: string) {
  try {
    const url = new URL(value(env, name));
    return url.protocol === "https:" && Boolean(url.hostname) && !url.username && !url.password;
  } catch {
    return false;
  }
}

export function summarizeDeploymentReadiness(
  env: ReadinessEnvironment,
  stableReleasePublished: boolean,
): DeploymentReadinessSummary {
  const checkoutConfigured =
    value(env, "NEXT_PUBLIC_CHECKOUT_PROVIDER").toLowerCase() === "lemonsqueezy" &&
    httpsUrl(env, "NEXT_PUBLIC_CHECKOUT_URL");
  const databaseConfigured = Boolean(value(env, "DATABASE_URL"));
  const webhookConfigured =
    Boolean(value(env, "LEMONSQUEEZY_WEBHOOK_SECRET")) &&
    positiveInteger(env, "CMDTAB_LEMONSQUEEZY_STORE_ID") &&
    positiveInteger(env, "CMDTAB_LEMONSQUEEZY_PRODUCT_ID") &&
    positiveInteger(env, "CMDTAB_LEMONSQUEEZY_VARIANT_ID") &&
    ["true", "false"].includes(
      value(env, "CMDTAB_LEMONSQUEEZY_EXPECT_TEST_MODE").toLowerCase(),
    ) &&
    value(env, "CMDTAB_LICENSE_LOOKUP_PEPPER").length >= 32;
  const emailConfigured = allPresent(env, [
    "RESEND_API_KEY",
    "WAITLIST_FROM_EMAIL",
    "WAITLIST_TO_EMAIL",
    "LICENSE_DELIVERY_FROM_EMAIL",
  ]);
  const persistentRetryConfigured =
    databaseConfigured &&
    value(env, "CMDTAB_LICENSE_OUTBOX_SECRET").length >= 32 &&
    value(env, "CRON_SECRET").length >= 32;
  const localSigningConfigured = allPresent(env, [
    "CMDTAB_LICENSE_PRIVATE_KEY_PEM",
    "CMDTAB_LICENSE_SIGNING_KID",
    "CMDTAB_LICENSE_PUBLIC_KEYRING_JSON",
  ]);
  const productionSigningConfigured =
    allPresent(env, [
      "AWS_REGION",
      "AWS_ROLE_ARN",
      "CMDTAB_TRIAL_KMS_KEY_ID",
      "CMDTAB_TRIAL_SIGNING_KID",
      "CMDTAB_LICENSE_KMS_KEY_ID",
      "CMDTAB_LICENSE_SIGNING_KID",
      "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON",
      "CMDTAB_LICENSE_PUBLIC_KEYRING_JSON",
    ]) &&
    value(env, "CMDTAB_TRIAL_KMS_KEY_ID") !==
      value(env, "CMDTAB_LICENSE_KMS_KEY_ID") &&
    value(env, "CMDTAB_TRIAL_SIGNING_KID") !==
      value(env, "CMDTAB_LICENSE_SIGNING_KID") &&
    !value(env, "CMDTAB_LICENSE_PRIVATE_KEY_PEM") &&
    !value(env, "CMDTAB_TRIAL_PRIVATE_KEY_PEM");
  const sandboxSigningConfigured = localSigningConfigured || productionSigningConfigured;
  const commonPurchaseBoundaries =
    checkoutConfigured &&
    databaseConfigured &&
    webhookConfigured &&
    emailConfigured &&
    persistentRetryConfigured;
  const sandboxPurchaseFlowReady = commonPurchaseBoundaries && sandboxSigningConfigured;
  const productionPurchaseFlowReady =
    commonPurchaseBoundaries &&
    productionSigningConfigured &&
    value(env, "CMDTAB_LEMONSQUEEZY_EXPECT_TEST_MODE") === "false";

  return {
    checkoutConfigured,
    databaseConfigured,
    webhookConfigured,
    emailConfigured,
    persistentRetryConfigured,
    sandboxSigningConfigured,
    productionSigningConfigured,
    stableReleasePublished,
    sandboxPurchaseFlowReady,
    productionPurchaseFlowReady,
    updateFlowReady: stableReleasePublished,
  };
}
