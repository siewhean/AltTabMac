"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { trackSiteEvent } from "@/lib/site-analytics-client";
import { REFERRAL_REWARD_CAP, referralShareText, referralUrl } from "@/lib/waitlist-referral";

export type WaitlistReferral = {
  code: string;
  /** Invitations that verified their email and passed the abuse checks. */
  qualified: number;
  target: number;
  confirmed: boolean;
};

type WaitlistSuccessProps = {
  message: string;
  referral?: WaitlistReferral;
  context: string;
  onReset: () => void;
};

const shareLinkClass =
  "inline-flex min-h-11 items-center justify-center rounded-full border border-white/12 bg-white/[0.05] px-4 py-2 text-sm font-medium text-text transition-colors duration-200 hover:border-white/20 hover:bg-white/[0.09] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-accent/60";

const useCases = [
  { id: "browsing", label: "Browsing and research" },
  { id: "development", label: "Development" },
  { id: "design", label: "Design" },
  { id: "writing", label: "Writing and docs" },
  { id: "other", label: "Something else" },
] as const;

export function WaitlistSuccess({ message, referral, context, onReset }: WaitlistSuccessProps) {
  const [copied, setCopied] = useState<"idle" | "copied" | "failed">("idle");
  const [answered, setAnswered] = useState(false);

  // Optional one-tap answer, saved against the signup's own invite code.
  async function answerUseCase(useCase: string) {
    if (!referral) return;
    setAnswered(true);
    trackSiteEvent("waitlist_use_case", { context, useCase });
    try {
      await fetch("/api/waitlist/profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ code: referral.code, useCase }),
      });
    } catch {
      // The answer is a nicety; never surface a failure.
    }
  }
  const link = referral ? referralUrl(window.location.origin, referral.code) : undefined;

  async function copyLink() {
    if (!link) return;
    try {
      await navigator.clipboard.writeText(link);
      setCopied("copied");
      trackSiteEvent("waitlist_referral_copy", { context });
    } catch {
      setCopied("failed");
    }
  }

  const encodedLink = link ? encodeURIComponent(link) : "";
  const encodedText = encodeURIComponent(referralShareText);
  const shares = link
    ? [
        { id: "x", label: "Share on X", href: `https://twitter.com/intent/tweet?text=${encodedText}&url=${encodedLink}` },
        { id: "whatsapp", label: "WhatsApp", href: `https://wa.me/?text=${encodeURIComponent(`${referralShareText} ${link}`)}` },
        { id: "telegram", label: "Telegram", href: `https://t.me/share/url?url=${encodedLink}&text=${encodedText}` },
        {
          id: "email",
          label: "Email a friend",
          href: `mailto:?subject=${encodeURIComponent("Try the CmdTab beta")}&body=${encodeURIComponent(`${referralShareText}\n\n${link}`)}`,
        },
      ]
    : [];

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

      {referral && link ? (
        <div className="space-y-3 rounded-xl border border-white/10 bg-ink/40 p-4 text-text">
          <p className="text-xs uppercase tracking-[0.18em] text-subdued">Optional · invite friends</p>
          <p className="text-sm font-medium">Get CmdTab free</p>
          <p className="text-sm leading-6 text-muted">
            Invite {referral.target} friends. When {referral.target} of them verify their email,
            you get a free CmdTab license after a quick review. The beta reward is limited to the
            first {REFERRAL_REWARD_CAP} members.
          </p>
          <div
            className="h-2 overflow-hidden rounded-full bg-white/10"
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={referral.target}
            aria-valuenow={referral.qualified}
            aria-label="Friends who verified their email"
          >
            <div
              className="h-full rounded-full bg-accent transition-[width] duration-300"
              style={{ width: `${Math.min(100, (referral.qualified / referral.target) * 100)}%` }}
            />
          </div>
          <p className="text-xs text-muted">
            {referral.qualified} of {referral.target} friends counted
            {referral.confirmed ? "" : ". Verify your own email too, using the link in your welcome email, so your invitations count"}
          </p>
          <div className="flex flex-col gap-2 sm:flex-row">
            <input
              readOnly
              aria-label="Your invite link"
              value={link}
              onFocus={(event) => event.currentTarget.select()}
              className="min-h-11 w-full rounded-xl border border-white/10 bg-white/5 px-3 text-xs text-text focus:border-accent/50 focus:outline-hidden"
            />
            <Button type="button" onClick={copyLink} className="sm:w-auto">
              {copied === "copied" ? "Copied" : "Copy link"}
            </Button>
          </div>
          {copied === "failed" ? (
            <p className="text-xs text-rose-200">Copy was blocked. Select the link above and copy it manually.</p>
          ) : null}
          <div className="flex flex-wrap gap-2">
            {shares.map((share) => (
              <a
                key={share.id}
                href={share.href}
                target="_blank"
                rel="noopener noreferrer"
                className={shareLinkClass}
                onClick={() => trackSiteEvent("waitlist_referral_share", { context, channel: share.id })}
              >
                {share.label}
              </a>
            ))}
          </div>
          <p className="text-xs leading-5 text-subdued">
            A friend counts once, after they verify a real email address. Invitations from your own
            device or network, duplicate or disposable addresses, and several signups from one device
            don’t count. Rewards are reviewed before a license is granted.
          </p>
        </div>
      ) : (
        <p className="text-sm leading-6 text-emerald-200/90">
          Check your inbox for your welcome email and your personal invite link.
        </p>
      )}

      {referral ? (
        <div className="space-y-2">
          <p className="text-xs text-emerald-200/90">
            {answered ? "Thanks, that helps us decide what to build first." : "What will you mostly use CmdTab for? (optional, one tap)"}
          </p>
          {answered ? null : (
            <div className="flex flex-wrap gap-2">
              {useCases.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => answerUseCase(item.id)}
                  className={shareLinkClass}
                >
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
