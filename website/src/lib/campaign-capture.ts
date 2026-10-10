"use client";

import { parseCampaignParams, SAFE_CAMPAIGN_VALUE } from "@/lib/waitlist-attribution";
import { normalizeReferralCode } from "@/lib/waitlist-referral";

// Campaign labels live in this tab's session only. They are not an identifier
// and are never transmitted unless the visitor accepted optional analytics
// and then submits the waitlist form.
const CAMPAIGN_STORAGE_KEY = "cmdtab-session-campaign";
// An invite code is functional, not analytics: it credits the friend who
// shared the link. Kept for 30 days so a later signup is still credited.
const REFERRAL_STORAGE_KEY = "cmdtab-invite-code";
const REFERRAL_TTL_MS = 30 * 24 * 60 * 60 * 1000;

/** Records first-touch campaign labels and any invite code from the landing URL. */
export function captureCampaignFromLocation() {
  if (typeof window === "undefined") return;
  const { campaign, referralCode } = parseCampaignParams(
    window.location.search,
    window.location.pathname,
  );

  try {
    if (campaign && !window.sessionStorage.getItem(CAMPAIGN_STORAGE_KEY)) {
      window.sessionStorage.setItem(CAMPAIGN_STORAGE_KEY, JSON.stringify(campaign));
    }
  } catch {
    // Storage can be unavailable in hardened browser modes.
  }

  try {
    if (referralCode) {
      window.localStorage.setItem(
        REFERRAL_STORAGE_KEY,
        JSON.stringify({ code: referralCode, savedAt: Date.now() }),
      );
    }
  } catch {
    // Storage can be unavailable in hardened browser modes.
  }
}

export function readCapturedCampaign(): Record<string, string> | undefined {
  if (typeof window === "undefined") return undefined;
  try {
    const raw = window.sessionStorage.getItem(CAMPAIGN_STORAGE_KEY);
    if (!raw) return undefined;
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const safe: Record<string, string> = {};
    for (const [key, value] of Object.entries(parsed)) {
      if (typeof value === "string" && (key === "path" || SAFE_CAMPAIGN_VALUE.test(value))) {
        safe[key] = value.slice(0, 120);
      }
    }
    return Object.keys(safe).length > 0 ? safe : undefined;
  } catch {
    return undefined;
  }
}

export function readCapturedReferralCode(): string | undefined {
  if (typeof window === "undefined") return undefined;
  try {
    const raw = window.localStorage.getItem(REFERRAL_STORAGE_KEY);
    if (!raw) return undefined;
    const parsed = JSON.parse(raw) as { code?: unknown; savedAt?: unknown };
    if (typeof parsed.savedAt !== "number" || Date.now() - parsed.savedAt > REFERRAL_TTL_MS) {
      window.localStorage.removeItem(REFERRAL_STORAGE_KEY);
      return undefined;
    }
    return normalizeReferralCode(parsed.code);
  } catch {
    return undefined;
  }
}
