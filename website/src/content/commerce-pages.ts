import { commerceContent } from "@/content/commerce";

export const commercePageContent = {
  buy: {
    eyebrow: "Buy CmdTab",
    title: "Trial first, then buy once.",
    description:
      "A short trial, a one-time purchase, and a clear help path after checkout.",
    process: [
      {
        title: "Start the trial",
        body: "Download the current build, enable the required permissions, and use it in real work.",
      },
      {
        title: "Buy through hosted checkout",
        body: "When you are ready, complete the one-time purchase through the hosted checkout.",
      },
      {
        title: "Use Help if needed",
        body: "If you lose the receipt or need activation help later, use the Help page.",
      },
    ],
    notes: [
      "No subscription",
      "Hosted checkout",
      "Help requests land in the dashboard",
    ],
  },
  trial: {
    eyebrow: "Free trial",
    title: `${commerceContent.trialLength} before you decide.`,
    description:
      "Download the current build, enable the required permissions, and try CmdTab in real work.",
    checklist: [
      "Download the current trial build.",
      "Enable Accessibility and Screen Recording in macOS.",
      "Use CmdTab in your normal app-switching workflow.",
    ],
    note:
      "If the build is not live yet, this page should point people to Help for access.",
  },
  help: {
    eyebrow: "Help",
    title: "Purchase, activation, and recovery help.",
    description:
      "Use this page for waitlist questions, privacy requests, or existing customer activation and license recovery.",
    journey: [
      {
        title: "Waitlist questions",
        body: "CmdTab is in private preview. Ask about your signup or request removal from the list.",
      },
      {
        title: "Existing customer recovery",
        body: "If you already have a license, use your original purchase email when requesting recovery or activation help.",
      },
      {
        title: "Use Help if needed",
        body: "If you lose the receipt, need activation help, or have a billing issue, send one request here.",
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
        body: "Existing personal license terms continue to apply. New purchases are closed.",
      },
      {
        title: "Waitlist only",
        body: "New purchases, downloads, and public trial enrollment are closed for now.",
      },
      {
        title: "Hosted checkout, direct help",
        body: "Existing purchase questions and license recovery requests can still be submitted here.",
      },
    ],
  },
} as const;

export const licenseRequestReasonOptions = [
  { value: "license_recovery", label: "Find my license or receipt" },
  { value: "activation_help", label: "Activation or moving to another Mac" },
  { value: "billing_question", label: "Billing or purchase question" },
  { value: "refund_request", label: "Refund request" },
  { value: "general", label: "Waitlist, privacy, security, or general help" },
] as const;
