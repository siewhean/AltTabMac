"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { FormTextArea } from "@/components/ui/form-textarea";
import { licenseRequestReasonOptions } from "@/content/commerce-pages";
import { analyticsAttributes } from "@/lib/analytics";

type FormState =
  | { kind: "idle"; message?: string; fieldErrors?: Record<string, string> }
  | { kind: "submitting" }
  | { kind: "success"; message: string }
  | { kind: "error"; message: string; fieldErrors?: Record<string, string> };

function collectMetadata() {
  if (typeof window === "undefined") return undefined;

  return {
    path: window.location.pathname,
  };
}

export function LicenseRequestForm() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [purchaseEmail, setPurchaseEmail] = useState("");
  const [reason, setReason] = useState<(typeof licenseRequestReasonOptions)[number]["value"]>("license_recovery");
  const [message, setMessage] = useState("");
  const [honeypot, setHoneypot] = useState("");
  const [state, setState] = useState<FormState>({ kind: "idle" });

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState({ kind: "submitting" });

    try {
      const response = await fetch("/api/license-help", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email,
          name: name || undefined,
          purchaseEmail: purchaseEmail || undefined,
          reason,
          message,
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
          message: data.message ?? "We could not send your request right now.",
          fieldErrors: data.fieldErrors,
        });
        return;
      }

      setState({
        kind: "success",
        message: data.message ?? "Your request is in. We’ll reply by email.",
      });
      setName("");
      setEmail("");
      setPurchaseEmail("");
      setReason("license_recovery");
      setMessage("");
      setHoneypot("");
    } catch {
      setState({ kind: "error", message: "We could not send your request right now." });
    }
  }

  const isSubmitting = state.kind === "submitting";
  const fieldErrors = state.kind === "error" ? state.fieldErrors : undefined;

  return (
    <div className="surface-panel p-6">
      {state.kind === "success" ? (
        <div className="space-y-4">
          <p className="type-eyebrow text-cyan">Request saved</p>
          <p className="text-2xl font-medium tracking-[-0.04em] text-text">{state.message}</p>
          <p className="text-sm leading-7 text-muted">
            Keep an eye on your inbox. If this is about a lost purchase email, include the original
            checkout address when you reply.
          </p>
          <Button href="/buy" variant="secondary" {...analyticsAttributes("license_request_success_buy_click", "help")}>
            Review buy page
          </Button>
        </div>
      ) : (
        <form className="space-y-5" onSubmit={handleSubmit} noValidate>
          <FormField
            id="license-name"
            label="Name"
            name="name"
            autoComplete="name"
            placeholder="How should we address you?"
            value={name}
            onChange={(event) => setName(event.target.value)}
            disabled={isSubmitting}
            error={fieldErrors?.name}
          />
          <FormField
            id="license-email"
            label="Email address"
            type="email"
            name="email"
            autoComplete="email"
            inputMode="email"
            placeholder="you@mac.com"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            disabled={isSubmitting}
            error={fieldErrors?.email}
            required
          />
          <FormField
            id="license-purchase-email"
            label="Purchase email (optional)"
            type="email"
            name="purchase-email"
            autoComplete="email"
            inputMode="email"
            placeholder="The email used at checkout, if different"
            value={purchaseEmail}
            onChange={(event) => setPurchaseEmail(event.target.value)}
            disabled={isSubmitting}
            error={fieldErrors?.purchaseEmail}
          />

          <label className="block" htmlFor="license-reason">
            <span className="mb-2 block text-sm font-medium text-text">What do you need help with?</span>
            <select
              id="license-reason"
              name="reason"
              value={reason}
              onChange={(event) => setReason(event.target.value as typeof reason)}
              disabled={isSubmitting}
              className="min-h-12 w-full rounded-2xl border border-white/10 bg-white/5 px-4 text-sm text-text transition-[border-color,background-color,transform] duration-200 ease-[cubic-bezier(0.23,1,0.32,1)] focus:border-accent/50 focus:bg-white/8 focus:outline-none focus:ring-2 focus:ring-accent/20 active:scale-[0.995]"
            >
              {licenseRequestReasonOptions.map((option) => (
                <option key={option.value} value={option.value} className="bg-[#0B1018] text-text">
                  {option.label}
                </option>
              ))}
            </select>
            {fieldErrors?.reason ? (
              <span className="mt-2 block text-sm text-rose-300">{fieldErrors.reason}</span>
            ) : null}
          </label>

          <FormTextArea
            id="license-message"
            label="Message"
            name="message"
            placeholder="Tell us what happened, what you expected, and any purchase details that will help us find the order."
            value={message}
            onChange={(event) => setMessage(event.target.value)}
            disabled={isSubmitting}
            error={fieldErrors?.message}
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
              {...analyticsAttributes("license_request_submit", "license")}
            >
              {isSubmitting ? (
                <>
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-slate-950/25 border-t-slate-950" />
                  Sending request
                </>
              ) : (
                "Send request"
              )}
            </Button>
            <p className="text-sm leading-6 text-subdued">
              This goes straight to CmdTab support and is stored in the admin dashboard.
            </p>
          </div>

          {state.kind === "error" ? (
            <p className="rounded-2xl border border-rose-400/20 bg-rose-400/8 px-4 py-3 text-sm text-rose-100">
              {state.message}
            </p>
          ) : null}
        </form>
      )}
    </div>
  );
}
