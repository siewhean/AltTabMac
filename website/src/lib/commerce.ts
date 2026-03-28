type CheckoutProvider = "lemonsqueezy" | "paddle" | "stripe" | "custom";

export type CommerceConfig = {
  checkoutProvider?: CheckoutProvider;
  checkoutUrl?: string;
  trialDownloadUrl?: string;
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
    trialDownloadUrl: optionalValue(process.env.NEXT_PUBLIC_TRIAL_URL),
    supportEmail: optionalValue(process.env.NEXT_PUBLIC_SUPPORT_EMAIL),
  };
}
