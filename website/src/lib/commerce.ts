type CheckoutProvider = "lemonsqueezy" | "paddle" | "stripe" | "custom";

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

export function getCommerceConfig(): CommerceConfig {
  const checkoutProvider = optionalValue(
    process.env.NEXT_PUBLIC_CHECKOUT_PROVIDER,
  ) as CheckoutProvider | undefined;

  return {
    checkoutProvider,
    checkoutUrl: optionalValue(process.env.NEXT_PUBLIC_CHECKOUT_URL),
    licensePortalUrl: optionalValue(process.env.NEXT_PUBLIC_LICENSE_PORTAL_URL),
    supportEmail: optionalValue(process.env.NEXT_PUBLIC_SUPPORT_EMAIL),
  };
}
