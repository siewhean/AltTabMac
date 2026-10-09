import { commerceContent } from "@/content/commerce";

export const commercePageContent = {
  buy: {
    eyebrow: "Buy CmdTab",
    title: "Pricing and early access.",
    description:
      "Review the planned one-time license and join the waitlist while CmdTab remains in private preview.",
    process: [
      {
        title: "Join the waitlist",
        body: "We’ll email you when early access opens. No download is currently available.",
      },
      {
        title: "Purchase when checkout opens",
        body: "The one-time purchase will be available through hosted checkout when access opens.",
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
    eyebrow: "Early access",
    title: "Find your next window faster.",
    description:
      "Join the waitlist for an email when CmdTab early access opens.",
    checklist: [
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
      "Use this page if you started the trial, bought CmdTab, or need help finding a purchase later.",
    journey: [
      {
        title: "Start with the trial",
        body: "Use CmdTab in real work first. The trial exists to prove the app before you pay.",
      },
      {
        title: "Buy through checkout",
        body: "When it earns a place in your setup, complete the one-time purchase through the hosted checkout.",
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
        body: "CmdTab is sold once, not as a subscription.",
      },
      {
        title: "Trial first, then decide",
        body: "The trial exists so people can prove the app in real use before paying.",
      },
      {
        title: "Hosted checkout, direct help",
        body: "Checkout runs through the provider, but purchase questions still come back here.",
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
