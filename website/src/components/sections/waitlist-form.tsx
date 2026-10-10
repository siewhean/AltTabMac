"use client";

import { useState } from "react";

import { WaitlistSuccess, type WaitlistReferral } from "@/components/sections/waitlist-success";
import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { analyticsAttributes } from "@/lib/analytics";
import { hasAnalyticsConsent } from "@/lib/analytics-consent";
import { readCapturedCampaign, readCapturedReferralCode } from "@/lib/campaign-capture";
import { getOrCreateDeviceId } from "@/lib/device-id";
import { trackSiteEvent } from "@/lib/site-analytics-client";
import { collectWaitlistAttribution } from "@/lib/waitlist-attribution";

type FormState =
  | { kind: "idle" }
  | { kind: "submitting" }
  | { kind: "success"; message: string; referral?: WaitlistReferral }
  | { kind: "error"; message: string; fieldErrors?: Record<string, string> };

type WaitlistFormProps = {
  /** Stored as the signup source, e.g. "homepage_hero". Letters, digits, . _ - only. */
  source: string;
  /** "hero" is a one-line email capture; "page" adds the optional name field. */
  variant?: "page" | "hero";
  submitLabel?: string;
};

export function WaitlistForm({
  source,
  variant = "page",
  submitLabel = "Join the private beta",
}: WaitlistFormProps) {
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [honeypot, setHoneypot] = useState("");
  const [marketingConsent, setMarketingConsent] = useState(false);
  const [state, setState] = useState<FormState>({ kind: "idle" });
  const idPrefix = `waitlist-${source}`;
  const compact = variant === "hero";

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!email.trim()) return;

    setState({ kind: "submitting" });

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: email.trim(),
          name: name.trim() || undefined,
          source,
          metadata: collectWaitlistAttribution(
            window.location.search,
            window.location.pathname,
            hasAnalyticsConsent(),
            readCapturedCampaign(),
          ),
          referralCode: readCapturedReferralCode(),
          deviceId: getOrCreateDeviceId(),
          // Only the full form offers the optional checkbox; it is never pre-checked.
          marketingConsent: compact ? undefined : marketingConsent,
          honeypot,
        }),
      });

      const data = (await response.json()) as {
        ok: boolean;
        message?: string;
        fieldErrors?: Record<string, string>;
        referral?: WaitlistReferral;
      };

      if (!response.ok || !data.ok) {
        setState({
          kind: "error",
          message: data.message ?? "Failed to join the list. Please try again.",
          fieldErrors: data.fieldErrors,
        });
        return;
      }

      setState({
        kind: "success",
        message: data.message ?? "Your request was received. We’ll email you when the next beta opens.",
        referral: data.referral,
      });
      trackSiteEvent("waitlist_form_success_response", { context: source });
      setEmail("");
      setName("");
      setHoneypot("");
      setMarketingConsent(false);
    } catch {
      setState({
        kind: "error",
        message: "An unexpected error occurred. Please try again shortly.",
      });
    }
  }

  if (state.kind === "success") {
    return (
      <WaitlistSuccess
        message={state.message}
        referral={state.referral}
        context={source}
        onReset={() => setState({ kind: "idle" })}
      />
    );
  }

  const isSubmitting = state.kind === "submitting";
  const fieldErrors = state.kind === "error" ? state.fieldErrors : undefined;

  const honeypotField = (
    <input
      aria-hidden="true"
      autoComplete="off"
      className="hidden"
      name="company"
      tabIndex={-1}
      value={honeypot}
      onChange={(e) => setHoneypot(e.target.value)}
    />
  );

  const submitButton = (
    <Button
      type="submit"
      disabled={isSubmitting || !email.trim()}
      className="w-full sm:w-auto"
      {...analyticsAttributes("waitlist_submit", source)}
    >
      {isSubmitting ? (
        <>
          <span className="h-4 w-4 animate-spin rounded-full border-2 border-slate-950/25 border-t-slate-950" />
          Saving your spot...
        </>
      ) : (
        submitLabel
      )}
    </Button>
  );

  const errorMessage =
    state.kind === "error" ? (
      <p
        role="alert"
        className="rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-xs text-rose-200"
      >
        {state.message}
      </p>
    ) : null;

  if (compact) {
    return (
      <form className="space-y-3" onSubmit={handleSubmit} noValidate>
        <div className="flex flex-col gap-3 sm:flex-row">
          <label className="sr-only" htmlFor={`${idPrefix}-email`}>
            Email address
          </label>
          <input
            id={`${idPrefix}-email`}
            type="email"
            name="email"
            autoComplete="email"
            inputMode="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={isSubmitting}
            required
            aria-invalid={fieldErrors?.email ? true : undefined}
            className="min-h-12 w-full rounded-full border border-white/12 bg-white/[0.06] px-5 text-sm text-text placeholder:text-subdued focus:border-accent/60 focus:outline-none focus:ring-2 focus:ring-accent/25 sm:max-w-[300px]"
          />
          {honeypotField}
          {submitButton}
        </div>
        {fieldErrors?.email ? <p className="text-sm text-rose-300">{String(fieldErrors.email)}</p> : null}
        {errorMessage}
        <p className="max-w-[34rem] text-xs leading-5 text-subdued">
          macOS 14+, invitations in waves. Previews need Accessibility and Screen Recording
          permission. Beta emails only; unsubscribe anytime.{" "}
          <a href="/privacy" className="underline underline-offset-2 hover:text-text">
            Privacy
          </a>
        </p>
      </form>
    );
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit} noValidate>
      <FormField
        id={`${idPrefix}-name`}
        label="Name (optional)"
        name="name"
        autoComplete="name"
        placeholder="Jane Doe"
        value={name}
        onChange={(e) => setName(e.target.value)}
        disabled={isSubmitting}
        error={fieldErrors?.name}
      />
      <FormField
        id={`${idPrefix}-email`}
        label="Email address for beta updates"
        type="email"
        name="email"
        autoComplete="email"
        inputMode="email"
        placeholder="you@example.com"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        disabled={isSubmitting}
        error={fieldErrors?.email}
        required
      />
      {honeypotField}
      <label className="flex items-start gap-3 text-sm leading-6 text-muted">
        <input
          type="checkbox"
          name="marketingConsent"
          checked={marketingConsent}
          onChange={(e) => setMarketingConsent(e.target.checked)}
          disabled={isSubmitting}
          className="mt-1.5 h-4 w-4 shrink-0 accent-[#79AFFF]"
        />
        <span>Also send me occasional CmdTab product updates (optional). Unsubscribe anytime.</span>
      </label>
      <div className="flex flex-col gap-3 pt-2 sm:flex-row sm:items-center">
        {submitButton}
        <p className="text-xs leading-5 text-muted">
          We&apos;ll only email you about CmdTab&apos;s beta, trial, and launch. Every email has an
          unsubscribe link.{" "}
          <a href="/privacy" className="underline underline-offset-2 hover:text-text">
            Privacy policy
          </a>
        </p>
      </div>
      {errorMessage}
    </form>
  );
}
