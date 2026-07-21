import { commerceContent } from "@/content/commerce";

export const commercePageContent = {
  buy: {
    eyebrow: "Buy CmdTab",
    title: "Trial first, then buy once.",
    description:
      "Try first, then decide. One-time purchase only. Support stays one click away.",
    process: [
      {
        title: "Start the trial",
        body: "Download the build, enable permissions, and try it where you work.",
      },
      {
        title: "Buy through hosted checkout",
        body: "When ready, complete a one-time checkout in the hosted purchase flow.",
      },
      {
        title: "Use Help if needed",
        body: "Lost a receipt or need activation help? Use Help after checkout.",
      },
    ],
    notes: [
      "No subscription",
      "Hosted checkout",
      "One-time purchase flow",
    ],
  },
  trial: {
    eyebrow: "Free trial",
    title: `${commerceContent.trialLength} before you decide.`,
    description:
      "Download the build, enable permissions, and test in your normal workflow.",
    checklist: [
      "Download the current trial build.",
      "Enable Accessibility and Screen Recording.",
      "Use CmdTab in your normal app-switching workflow.",
    ],
    note:
      "If the build link is not live, use Help and request access.",
  },
  help: {
    eyebrow: "Help",
    title: "Purchase, activation, and recovery help.",
    description:
      "Use this page after trial or purchase when you need activation, receipt, or billing help.",
    journey: [
      {
        title: "Start with the trial",
        body: "Use CmdTab first in real work. No purchase needed to validate.",
      },
      {
        title: "Buy through checkout",
        body: "When it fits your workflow, complete checkout and keep your receipt.",
      },
      {
        title: "Use Help if needed",
        body: "Lost access or have billing questions? Submit one request and we will reply.",
      },
    ],
    supportPoints: [
      "Find a lost receipt or purchase email.",
      "Ask about activation or moving Macs.",
      "Get billing or refund help.",
    ],
    terms: [
      {
        title: "One-time purchase",
        body: "CmdTab is sold once, not as a subscription.",
      },
      {
        title: "Trial first, then decide",
        body: "The trial gives you a chance to validate the app before purchase.",
      },
      {
        title: "Hosted checkout, direct help",
        body: "Checkout stays provider-hosted. Purchase questions still land on this page.",
      },
    ],
  },
} as const;

export const licenseRequestReasonOptions = [
  { value: "license_recovery", label: "Find my license or receipt" },
  { value: "activation_help", label: "Activation or moving to another Mac" },
  { value: "billing_question", label: "Billing or purchase question" },
  { value: "refund_request", label: "Refund request" },
  { value: "general", label: "General license help" },
] as const;
