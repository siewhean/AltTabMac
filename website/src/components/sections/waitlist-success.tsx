"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { trackSiteEvent } from "@/lib/site-analytics-client";
import { REFERRAL_REWARD_CAP, REFERRAL_REWARD_TARGET } from "@/lib/waitlist-referral";

type WaitlistSuccessProps = {
  message: string;
  /**
   * Opaque token from the signup response. It authorizes one optional write
   * (how the person will use CmdTab). Every response carries one, so it says
   * nothing about the address.
   */
  profileToken?: string;
  context: string;
  onReset: () => void;
};

const useCases = [
  { id: "browsing", label: "Browsing and research" },
  { id: "development", label: "Development" },
  { id: "design", label: "Design" },
  { id: "writing", label: "Writing and docs" },
  { id: "other", label: "Something else" },
] as const;

const chipClass =
  "inline-flex min-h-11 items-center justify-center rounded-full border border-white/12 bg-white/[0.05] px-4 py-2 text-sm font-medium text-text transition-colors duration-200 hover:border-white/20 hover:bg-white/[0.09] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-accent/60";

export function WaitlistSuccess({ message, profileToken, context, onReset }: WaitlistSuccessProps) {
  const [answered, setAnswered] = useState(false);

  // Optional one-tap answer, authorized by the signed token from the response.
  async function answerUseCase(useCase: string) {
    if (!profileToken) return;
    setAnswered(true);
    trackSiteEvent("waitlist_use_case", { context, useCase });
    try {
      await fetch("/api/waitlist/profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token: profileToken, useCase }),
      });
    } catch {
      // The answer is a nicety; never surface a failure.
    }
  }

  return (
    <div
      className="space-y-5 rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-6 text-emerald-200"
      role="status"
      aria-live="polite"
    >
      <div className="flex items-center gap-2 font-semibold text-emerald-300">
        <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
        </svg>
        You’re in the beta
      </div>
      <p className="text-sm leading-6 text-emerald-200/90">{message}</p>

      <div className="space-y-2 rounded-xl border border-white/10 bg-ink/40 p-4 text-text">
        <p className="text-xs uppercase tracking-[0.18em] text-subdued">Optional · invite friends</p>
        <p className="text-sm font-medium">Get CmdTab free</p>
        <p className="text-sm leading-6 text-muted">
          Invite {REFERRAL_REWARD_TARGET} friends. When {REFERRAL_REWARD_TARGET} of them verify their
          email, you get a free CmdTab license after a quick review. The beta reward is limited to
          the first {REFERRAL_REWARD_CAP} members.
        </p>
        <p className="text-sm leading-6 text-muted">
          Your personal invite link is in the welcome email we just sent. Open it there, and verify
          your own email with the link in the same message so your invitations count.
        </p>
        <p className="text-xs leading-5 text-subdued">
          A friend counts once, after they verify a real email address. Invitations from your own
          device or network, duplicate or disposable addresses, and several signups from one device
          don’t count. Rewards are reviewed before a license is granted.
        </p>
      </div>

      {profileToken ? (
        <div className="space-y-2">
          <p className="text-xs text-emerald-200/90">
            {answered
              ? "Thanks, that helps us decide what to build first."
              : "What will you mostly use CmdTab for? (optional, one tap)"}
          </p>
          {answered ? null : (
            <div className="flex flex-wrap gap-2">
              {useCases.map((item) => (
                <button key={item.id} type="button" onClick={() => answerUseCase(item.id)} className={chipClass}>
                  {item.label}
                </button>
              ))}
            </div>
          )}
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-3">
        <Button href="/#demo" variant="secondary" className="whitespace-normal text-center text-xs">
          Try the switcher in your browser
        </Button>
        <button
          type="button"
          onClick={onReset}
          className="text-xs text-emerald-200/80 underline underline-offset-2 hover:text-emerald-100"
        >
          Register another email
        </button>
      </div>
    </div>
  );
}
