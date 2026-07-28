"use client";

export const ANALYTICS_CONSENT_STORAGE_KEY = "cmdtab-optional-analytics-consent";
export const ANALYTICS_CONSENT_EVENT = "cmdtab:analytics-consent-changed";
export const VISITOR_STORAGE_KEY = "cmdtab-website-visitor-id";
export const SESSION_STORAGE_KEY = "cmdtab-website-session-id";

export type AnalyticsConsent = "accepted" | "declined" | "unset";

export function getAnalyticsConsent(): AnalyticsConsent {
  if (typeof window === "undefined") return "unset";

  try {
    const value = window.localStorage.getItem(ANALYTICS_CONSENT_STORAGE_KEY);
    return value === "accepted" || value === "declined" ? value : "unset";
  } catch {
    return "unset";
  }
}

export function hasAnalyticsConsent() {
  return getAnalyticsConsent() === "accepted";
}

export function deleteAnalyticsIdentifiers() {
  try {
    window.localStorage.removeItem(VISITOR_STORAGE_KEY);
  } catch {
    // Storage can be unavailable in hardened browser modes.
  }

  try {
    window.sessionStorage.removeItem(SESSION_STORAGE_KEY);
  } catch {
    // Storage can be unavailable in hardened browser modes.
  }
}

export function setAnalyticsConsent(consent: Exclude<AnalyticsConsent, "unset">) {
  if (typeof window === "undefined") return;

  try {
    window.localStorage.setItem(ANALYTICS_CONSENT_STORAGE_KEY, consent);
  } catch {
    // A failed write remains fail-closed: analytics stay disabled.
  }

  if (consent === "declined") {
    deleteAnalyticsIdentifiers();
  }

  window.dispatchEvent(
    new CustomEvent(ANALYTICS_CONSENT_EVENT, {
      detail: { consent: getAnalyticsConsent() },
    }),
  );
}

export function withdrawAnalyticsConsent() {
  setAnalyticsConsent("declined");
}
