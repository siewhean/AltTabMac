"use client";

import { WaitlistForm } from "@/components/sections/waitlist-form";

/** Trial-page waitlist form. Source stays `trial_page_waitlist` so history is comparable. */
export function TrialWaitlistForm() {
  return (
    <div className="space-y-4">
      <WaitlistForm source="trial_page_waitlist" variant="page" />
    </div>
  );
}
