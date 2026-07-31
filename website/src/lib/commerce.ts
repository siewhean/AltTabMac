import { isCommerceLaunchEnabled } from "./env";

const CHECKOUT_PROVIDERS = new Set([
  "lemonsqueezy",
  "paddle",
  "stripe",
  "custom",
] as const);

type CheckoutProvider = "lemonsqueezy" | "paddle" | "stripe" | "custom";

type CommerceEnvironment = Readonly<Record<string, string | undefined>>;

export type CommerceConfig = {
  checkoutProvider?: CheckoutProvider;
  checkoutUrl?: string;
  /** @deprecated Active download surfaces use the signed stable release manifest. */
  trialDownloadUrl?: string;
  licensePortalUrl?: string;
  supportEmail?: string;
};

function optionalValue(value: string | undefined) {
  const normalized = value?.trim();
  return normalized ? normalized : undefined;
}

function optionalProvider(value: string | undefined): CheckoutProvider | undefined {
  const normalized = optionalValue(value)?.toLowerCase();
  return normalized && CHECKOUT_PROVIDERS.has(normalized as CheckoutProvider)
    ? (normalized as CheckoutProvider)
    : undefined;
}

function optionalHttpsUrl(value: string | undefined) {
  const normalized = optionalValue(value);
  if (!normalized) return undefined;
  try {
    const url = new URL(normalized);
    if (
      url.protocol !== "https:" ||
      !url.hostname ||
      url.username ||
      url.password
    ) {
      return undefined;
    }
    return url.toString();
  } catch {
    return undefined;
  }
}

export function getCommerceConfig(
  env: CommerceEnvironment = process.env,
): CommerceConfig {
  const launchEnabled = isCommerceLaunchEnabled(env);

  return {
    checkoutProvider: launchEnabled
      ? optionalProvider(env.NEXT_PUBLIC_CHECKOUT_PROVIDER)
      : undefined,
    checkoutUrl: launchEnabled
      ? optionalHttpsUrl(env.NEXT_PUBLIC_CHECKOUT_URL)
      : undefined,
    licensePortalUrl: optionalHttpsUrl(env.NEXT_PUBLIC_LICENSE_PORTAL_URL),
    supportEmail: optionalValue(env.NEXT_PUBLIC_SUPPORT_EMAIL),
  };
}
