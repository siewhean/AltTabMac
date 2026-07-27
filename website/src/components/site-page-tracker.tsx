"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";

import { trackSitePageView } from "@/lib/site-analytics-client";
import {
  ANALYTICS_CONSENT_EVENT,
  ANALYTICS_CONSENT_STORAGE_KEY,
  getAnalyticsConsent,
} from "@/lib/analytics-consent";

export function SitePageTracker() {
  const pathname = usePathname();
  const lastTrackedPath = useRef<string | null>(null);

  useEffect(() => {
    function trackCurrentPath() {
      if (!pathname || pathname.startsWith("/dashboard")) return;
      if (lastTrackedPath.current === pathname) return;

      if (trackSitePageView(pathname)) {
        lastTrackedPath.current = pathname;
      }
    }

    function handleConsentChange() {
      if (getAnalyticsConsent() !== "accepted") {
        lastTrackedPath.current = null;
        return;
      }
      trackCurrentPath();
    }

    function handleConsentStorage(event: StorageEvent) {
      if (event.key === ANALYTICS_CONSENT_STORAGE_KEY) {
        handleConsentChange();
      }
    }

    trackCurrentPath();
    window.addEventListener(ANALYTICS_CONSENT_EVENT, handleConsentChange);
    window.addEventListener("storage", handleConsentStorage);
    return () => {
      window.removeEventListener(ANALYTICS_CONSENT_EVENT, handleConsentChange);
      window.removeEventListener("storage", handleConsentStorage);
    };
  }, [pathname]);

  return null;
}
