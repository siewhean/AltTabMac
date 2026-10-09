"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { analyticsAttributes } from "@/lib/analytics";
import { hasAnalyticsConsent } from "@/lib/analytics-consent";
import { collectWaitlistAttribution } from "@/lib/waitlist-attribution";
import { trackSiteEvent } from "@/lib/site-analytics-client";

type FormState =
  | { kind: "idle" }
  | { kind: "submitting" }
  | { kind: "success"; message: string }
  | { kind: "error"; message: string; fieldErrors?: Record<string, string> };

export function TrialWaitlistForm() {
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [honeypot, setHoneypot] = useState("");
  const [state, setState] = useState<FormState>({ kind: "idle" });

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!email.trim()) return;

    setState({ kind: "submitting" });

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email: email.trim(),
          name: name.trim() || undefined,
          source: "trial_page_waitlist",
          metadata: collectWaitlistAttribution(
            window.location.search,
            window.location.pathname,
            hasAnalyticsConsent(),
          ),
          honeypot,
        }),
      });

      const data = (await response.json()) as {
        ok: boolean;
        message?: string;
        fieldErrors?: Record<string, string>;
      };

      if (!response.ok || !data.ok) {
        setState({
          kind: "error",
          message: data.message ?? "Failed to join waitlist. Please try again.",
          fieldErrors: data.fieldErrors,
        });
        return;
      }

      setState({
        kind: "success",
        message: data.message ?? "Your request was received. We’ll email you when early access opens.",
      });
      trackSiteEvent("waitlist_form_success_response", {
        context: "trial_page_waitlist",
      });
      setEmail("");
      setName("");
      setHoneypot("");
    } catch {
      setState({
        kind: "error",
        message: "An unexpected error occurred. Please try again shortly.",
      });
    }
  }

  const isSubmitting = state.kind === "submitting";
  const fieldErrors = state.kind === "error" ? state.fieldErrors : undefined;

  return (
    <div className="space-y-4">
      {state.kind === "success" ? (
        <div className="rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-6 text-emerald-200 space-y-3">
          <div className="flex items-center gap-2 font-semibold text-emerald-300">
            <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
            Waitlist Registration Received
          </div>
          <p className="text-sm leading-6 text-emerald-200/90">{state.message}</p>
          <Button
            type="button"
            variant="secondary"
            onClick={() => setState({ kind: "idle" })}
            className="mt-2 text-xs"
          >
            Register another email
          </Button>
        </div>
      ) : (
        <form className="space-y-4" onSubmit={handleSubmit} noValidate>
          <FormField
            id="trial-name"
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
            id="trial-email"
            label="Email address for waitlist updates"
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

          <input
            aria-hidden="true"
            autoComplete="off"
            className="hidden"
            name="company"
            tabIndex={-1}
            value={honeypot}
            onChange={(e) => setHoneypot(e.target.value)}
          />

          <div className="pt-2 flex flex-col gap-3 sm:flex-row sm:items-center">
            <Button
              type="submit"
              disabled={isSubmitting || !email.trim()}
              className="w-full sm:w-auto"
              {...analyticsAttributes("trial_waitlist_submit", "trial_page")}
            >
              {isSubmitting ? (
                <>
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-slate-950/25 border-t-slate-950" />
                  Joining Waitlist...
                </>
              ) : (
                "Request Trial Access"
              )}
            </Button>
            <p className="text-xs leading-5 text-muted">
              We&apos;ll only email you about CmdTab&apos;s beta, trial, and launch. Every email has an
              unsubscribe link.{" "}
              <a href="/privacy" className="underline underline-offset-2 hover:text-text">
                Privacy policy
              </a>
            </p>
          </div>

          {state.kind === "error" ? (
            <p className="rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-xs text-rose-200">
              {state.message}
            </p>
          ) : null}
        </form>
      )}
    </div>
  );
}
