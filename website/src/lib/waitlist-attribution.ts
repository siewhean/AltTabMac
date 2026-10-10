import { normalizeReferralCode } from "./waitlist-referral";

const CAMPAIGN_KEYS = [
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_content",
] as const;

export const SAFE_CAMPAIGN_VALUE = /^[a-z0-9._-]{1,120}$/i;

/**
 * Attribution is stored only when the visitor accepted optional analytics
 * (see the privacy policy). Labels in the current URL win; otherwise the
 * first-touch labels remembered for this tab session are used, so a visitor
 * who landed on a campaign link and then navigated to the form is still attributed.
 */
export function collectWaitlistAttribution(
  search: string,
  pathname: string,
  analyticsConsented: boolean,
  remembered?: Record<string, string>,
): Record<string, string> | undefined {
  if (!analyticsConsented) return undefined;

  const metadata: Record<string, string> = { path: pathname.slice(0, 120) };
  const params = new URLSearchParams(search);
  let fromUrl = false;

  for (const key of CAMPAIGN_KEYS) {
    const value = params.get(key)?.trim();
    if (value && SAFE_CAMPAIGN_VALUE.test(value)) {
      metadata[key] = value.toLowerCase();
      fromUrl = true;
    }
  }

  if (!fromUrl && remembered) {
    for (const key of CAMPAIGN_KEYS) {
      const value = remembered[key];
      if (value && SAFE_CAMPAIGN_VALUE.test(value)) metadata[key] = value.toLowerCase();
    }
    if (remembered.path) metadata.path = remembered.path.slice(0, 120);
  }

  return metadata;
}

/** Extracts safe campaign labels and a well-formed invite code from a landing URL. */
export function parseCampaignParams(search: string, pathname: string) {
  const params = new URLSearchParams(search);
  const campaign: Record<string, string> = {};

  for (const key of CAMPAIGN_KEYS) {
    const value = params.get(key)?.trim();
    if (value && SAFE_CAMPAIGN_VALUE.test(value)) campaign[key] = value.toLowerCase();
  }
  if (Object.keys(campaign).length > 0) campaign.path = pathname.slice(0, 120);

  return {
    campaign: Object.keys(campaign).length > 0 ? campaign : undefined,
    referralCode: normalizeReferralCode(params.get("ref")),
  };
}
