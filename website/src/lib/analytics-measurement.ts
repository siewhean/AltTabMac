export const OPTIONAL_ANALYTICS_PRODUCTION_STARTED_AT = "2026-07-28T23:41:27.543+08:00";

export function isComparableOptionalAnalyticsWindow(days: number, now = new Date()) {
  const safeDays = Math.max(1, Math.min(Math.floor(days), 365));
  const windowStart = now.getTime() - safeDays * 24 * 60 * 60 * 1000;

  return windowStart >= Date.parse(OPTIONAL_ANALYTICS_PRODUCTION_STARTED_AT);
}
