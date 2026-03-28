"use client";

import { useEffect } from "react";
import { track } from "@vercel/analytics";

export function SiteEventTracker() {
  useEffect(() => {
    function handleClick(event: MouseEvent) {
      const target = event.target;
      if (!(target instanceof Element)) return;

      const trackable = target.closest<HTMLElement>("[data-analytics-event]");
      if (!trackable) return;

      const eventName = trackable.dataset.analyticsEvent?.trim();
      if (!eventName) return;

      const context = trackable.dataset.analyticsContext?.trim();
      track(eventName, context ? { context } : {});
    }

    document.addEventListener("click", handleClick);
    return () => document.removeEventListener("click", handleClick);
  }, []);

  return null;
}
