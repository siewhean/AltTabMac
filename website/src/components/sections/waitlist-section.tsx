"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { waitlistContent } from "@/content/waitlist";
import { analyticsAttributes } from "@/lib/analytics";

type FormState =
  | { kind: "idle"; message?: string; fieldErrors?: Record<string, string> }
  | { kind: "submitting" }
  | { kind: "success"; message: string }
  | { kind: "error"; message: string; fieldErrors?: Record<string, string> };

function collectMetadata() {
  if (typeof window === "undefined") return undefined;

  const params = new URLSearchParams(window.location.search);
  const metadata: Record<string, string> = {
    path: window.location.pathname,
  };

  for (const key of ["utm_source", "utm_medium", "utm_campaign", "utm_content"]) {
    const value = params.get(key);
    if (value) metadata[key] = value;
  }

  return Object.keys(metadata).length > 0 ? metadata : undefined;
}

export function WaitlistSection() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [honeypot, setHoneypot] = useState("");
  const [state, setState] = useState<FormState>({ kind: "idle" });

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState({ kind: "submitting" });

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email,
          name: name || undefined,
          source: "homepage_waitlist",
          metadata: collectMetadata(),
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
          message: data.message ?? waitlistContent.errorMessage,
          fieldErrors: data.fieldErrors,
        });
        return;
      }

      setState({
        kind: "success",
        message: waitlistContent.successMessage,
      });
      setName("");
      setEmail("");
      setHoneypot("");
    } catch {
      setState({ kind: "error", message: waitlistContent.errorMessage });
    }
  }

  const isSubmitting = state.kind === "submitting";
  const fieldErrors = state.kind === "error" ? state.fieldErrors : undefined;

  return (
    <SectionShell
      id="waitlist"
      eyebrow="Join the beta"
      title={waitlistContent.heading}
      description={waitlistContent.summary}
    >
      <div className="grid gap-8 lg:grid-cols-[minmax(0,0.85fr)_minmax(0,1.15fr)]">
        <MotionReveal className="space-y-5" direction="left">
          <p className="max-w-lg text-base leading-8 text-muted">{waitlistContent.note}</p>
          <div className="space-y-4 border-t border-white/8 pt-6">
            {[
              "Private beta updates only.",
              "Minimal data collection and a clean beta signup flow.",
              "Waitlist members get first access to the trial and founder launch price.",
            ].map((item) => (
              <div key={item} className="flex items-start gap-3 text-sm leading-7 text-subdued">
                <span className="mt-2 h-2 w-2 rounded-full bg-success" />
                <span>{item}</span>
              </div>
            ))}
          </div>
        </MotionReveal>

        <MotionReveal
          direction="right"
          delay={120}
          className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl"
        >
          {state.kind === "success" ? (
            <div className="space-y-4">
              <p className="text-sm font-semibold uppercase tracking-[0.22em] text-success">
                Waitlist saved
              </p>
              <p className="text-2xl font-medium tracking-[-0.04em] text-text">
                {state.message}
              </p>
              <p className="text-sm leading-7 text-muted">{waitlistContent.footnote}</p>
              <Button
                href="#top"
                variant="secondary"
                {...analyticsAttributes("waitlist_success_back_to_top", "waitlist")}
              >
                Back to the top
              </Button>
            </div>
          ) : (
            <form className="space-y-5" onSubmit={handleSubmit} noValidate>
              <FormField
                id="name"
                label={waitlistContent.labels.name}
                name="name"
                autoComplete="name"
                placeholder={waitlistContent.placeholders.name}
                value={name}
                onChange={(event) => setName(event.target.value)}
                disabled={isSubmitting}
                error={fieldErrors?.name}
              />
              <FormField
                id="email"
                label={waitlistContent.labels.email}
                type="email"
                name="email"
                autoComplete="email"
                inputMode="email"
                placeholder={waitlistContent.placeholders.email}
                value={email}
                onChange={(event) => setEmail(event.target.value)}
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
                onChange={(event) => setHoneypot(event.target.value)}
              />

              <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <Button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full sm:w-auto"
                  {...analyticsAttributes("waitlist_submit", "waitlist")}
                >
                  {isSubmitting
                    ? waitlistContent.labels.submitting
                    : waitlistContent.labels.submit}
                </Button>
                <p className="text-sm leading-6 text-subdued">{waitlistContent.footnote}</p>
              </div>

              {state.kind === "error" ? (
                <p className="rounded-2xl border border-rose-400/20 bg-rose-400/8 px-4 py-3 text-sm text-rose-100">
                  {state.message}
                </p>
              ) : null}
            </form>
          )}
        </MotionReveal>
      </div>
    </SectionShell>
  );
}
