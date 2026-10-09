const CAMPAIGN_KEYS = [
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_content",
] as const;

const SAFE_CAMPAIGN_VALUE = /^[a-z0-9._-]{1,120}$/i;

export function collectWaitlistAttribution(
  search: string,
  pathname: string,
  analyticsConsented: boolean,
): Record<string, string> | undefined {
  if (!analyticsConsented) return undefined;

  const metadata: Record<string, string> = { path: pathname.slice(0, 120) };
  const params = new URLSearchParams(search);

  for (const key of CAMPAIGN_KEYS) {
    const value = params.get(key)?.trim();
    if (value && SAFE_CAMPAIGN_VALUE.test(value)) {
      metadata[key] = value.toLowerCase();
    }
  }

  return metadata;
}
