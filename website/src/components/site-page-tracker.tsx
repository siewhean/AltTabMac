"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";

import { trackSitePageView } from "@/lib/site-analytics-client";

export function SitePageTracker() {
  const pathname = usePathname();
  const lastTrackedPath = useRef<string | null>(null);

  useEffect(() => {
    if (!pathname || pathname.startsWith("/dashboard")) return;
    if (lastTrackedPath.current === pathname) return;

    lastTrackedPath.current = pathname;
    trackSitePageView(pathname);
  }, [pathname]);

  return null;
}
