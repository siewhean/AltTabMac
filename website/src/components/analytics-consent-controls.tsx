"use client";

import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";
import { useEffect, useState } from "react";

import {
  ANALYTICS_CONSENT_EVENT,
  ANALYTICS_CONSENT_STORAGE_KEY,
  deleteAnalyticsIdentifiers,
  getAnalyticsConsent,
  setAnalyticsConsent,
  withdrawAnalyticsConsent,
  type AnalyticsConsent,
} from "@/lib/analytics-consent";

export function consentAwareVercelAnalyticsBeforeSend<T>(event: T) {
  return getAnalyticsConsent() === "accepted" ? event : null;
}

export function consentAwareSpeedInsightsBeforeSend<T>(event: T) {
  return getAnalyticsConsent() === "accepted" ? event : null;
}

function useAnalyticsConsent() {
  const [consent, setConsent] = useState<AnalyticsConsent | null>(null);

  useEffect(() => {
    const refresh = () => setConsent(getAnalyticsConsent());
    const handleStorage = (event: StorageEvent) => {
      if (event.key !== ANALYTICS_CONSENT_STORAGE_KEY) return;
      if (event.newValue !== "accepted") deleteAnalyticsIdentifiers();
      refresh();
    };
    refresh();
    window.addEventListener(ANALYTICS_CONSENT_EVENT, refresh);
    window.addEventListener("storage", handleStorage);
    return () => {
      window.removeEventListener(ANALYTICS_CONSENT_EVENT, refresh);
      window.removeEventListener("storage", handleStorage);
    };
  }, []);

  return consent;
}

export function OptionalAnalytics() {
  const consent = useAnalyticsConsent();
  if (consent !== "accepted") return null;

  return (
    <>
      <Analytics beforeSend={consentAwareVercelAnalyticsBeforeSend} />
      <SpeedInsights beforeSend={consentAwareSpeedInsightsBeforeSend} />
    </>
  );
}

export function AnalyticsConsentBanner() {
  const consent = useAnalyticsConsent();
  if (consent === null || consent !== "unset") return null;

  return (
    <aside
      aria-labelledby="analytics-consent-title"
      className="fixed inset-x-4 bottom-4 z-50 mx-auto max-w-3xl rounded-3xl border border-white/12 bg-ink/95 p-5 shadow-2xl backdrop-blur-xl sm:p-6"
    >
      <h2 id="analytics-consent-title" className="text-lg font-medium text-text">
        Optional privacy-friendly analytics
      </h2>
      <p className="mt-2 text-sm leading-6 text-muted">
        CmdTab keeps website analytics and Vercel performance measurement off until you accept.
        Trial, purchase, download, licensing, and support features work either way.
      </p>
      <div className="mt-4 flex flex-col gap-3 sm:flex-row">
        <button
          type="button"
          className="min-h-12 rounded-full border border-accent/45 bg-accent px-6 py-3 text-sm font-medium text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60"
          onClick={() => setAnalyticsConsent("accepted")}
        >
          Accept optional analytics
        </button>
        <button
          type="button"
          className="min-h-12 rounded-full border border-white/12 bg-white/[0.05] px-6 py-3 text-sm font-medium text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60"
          onClick={() => setAnalyticsConsent("declined")}
        >
          Decline
        </button>
        <a
          href="/privacy#analytics-controls"
          className="inline-flex min-h-12 items-center justify-center px-4 text-sm font-medium text-muted underline decoration-white/30 underline-offset-4 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60"
        >
          Learn more
        </a>
      </div>
    </aside>
  );
}

export function AnalyticsPrivacyControls() {
  const consent = useAnalyticsConsent();
  const status =
    consent === null
      ? "Checking your saved analytics choice…"
      : consent === "accepted"
      ? "Optional analytics are on."
      : consent === "declined"
        ? "Optional analytics are off."
        : "No choice has been saved. Optional analytics are off.";

  return (
    <section
      id="analytics-controls"
      aria-labelledby="analytics-controls-title"
      className="rounded-3xl border border-white/10 bg-white/[0.035] p-6"
    >
      <h2 id="analytics-controls-title" className="text-2xl font-medium text-text">
        Analytics controls
      </h2>
      <p className="mt-3 text-base leading-7 text-muted" aria-live="polite">
        {status}
      </p>
      <div className="mt-5 flex flex-col gap-3 sm:flex-row">
        <button
          type="button"
          className="min-h-12 rounded-full border border-accent/45 bg-accent px-6 py-3 text-sm font-medium text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60 disabled:opacity-60"
          onClick={() => setAnalyticsConsent("accepted")}
          disabled={consent === "accepted"}
        >
          Accept optional analytics
        </button>
        <button
          type="button"
          className="min-h-12 rounded-full border border-white/12 bg-white/[0.05] px-6 py-3 text-sm font-medium text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60 disabled:opacity-60"
          onClick={withdrawAnalyticsConsent}
          disabled={consent === "declined"}
        >
          {consent === "accepted" ? "Withdraw consent" : "Decline optional analytics"}
        </button>
      </div>
      <p className="mt-4 text-sm leading-6 text-subdued">
        Declining or withdrawing deletes CmdTab&apos;s stored website visitor and session
        identifiers from this browser. Essential commerce and trial records are not analytics and
        are retained under their separate operational terms.
      </p>
    </section>
  );
}
