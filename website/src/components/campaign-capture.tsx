"use client";

import { usePathname } from "next/navigation";
import { useEffect } from "react";

import { captureCampaignFromLocation } from "@/lib/campaign-capture";

/** Remembers campaign labels and invite codes from the landing URL across pages. */
export function CampaignCapture() {
  const pathname = usePathname();

  useEffect(() => {
    captureCampaignFromLocation();
  }, [pathname]);

  return null;
}
