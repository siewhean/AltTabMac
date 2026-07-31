import { commerceContent } from "@/content/commerce";

export const commercePageContent = {
  buy: {
    eyebrow: "General availability pricing",
    title: "Planned US$12 at general availability.",
    description:
      "The public beta is non-transactional. CmdTab does not publish checkout, payment, fulfilment, or refund actions during beta.",
    process: [
      {
        title: "Join the beta",
        body: "Use the signed Apple-silicon beta when it is published and report issues through the documented support path.",
      },
      {
        title: "Watch for GA details",
        body: "A US$12 personal licence is planned for general availability, not the beta period.",
      },
      {
        title: "Use support if needed",
        body: "For beta installation, permissions, security, or recovery guidance, email support@cmdtab.net.",
      },
    ],
    notes: [
      "No payment during beta",
      "Planned US$12 at GA",
      "Support is available by email",
    ],
  },
  trial: {
    eyebrow: "Public beta",
    title: "Join the CmdTab beta waitlist.",
    description:
      "Get notified when a signed Apple-silicon beta download is available, then enable the required permissions and try CmdTab in real work.",
    checklist: [
      "Download the signed beta build when it is published.",
      "Enable Accessibility and Screen Recording in macOS.",
      "Use CmdTab in your normal app-switching workflow.",
    ],
    note:
      "If the beta build is not live yet, join the waitlist or email support@cmdtab.net for help.",
  },
  help: {
    eyebrow: "Help",
    title: "Beta support and recovery guidance.",
    description:
      "Use this page for beta installation, permissions, security reporting, or existing licence recovery guidance. The beta has no payment path.",
    journey: [
      {
        title: "Use the public beta",
        body: "Use the signed beta in real work and report issues with your macOS version and CmdTab build.",
      },
      {
        title: "No payment during beta",
        body: "The planned US$12 personal licence belongs to general availability, not the beta release.",
      },
      {
        title: "Email support",
        body: "For existing licence recovery or beta help, send one concise request to support@cmdtab.net.",
      },
    ],
    supportPoints: [
      "Get beta installation or permission help.",
      "Report a security issue privately.",
      "Ask for existing licence recovery guidance.",
    ],
    terms: [
      {
        title: "Planned pricing",
        body: "US$12 is planned for general availability; there is no payment path during beta.",
      },
      {
        title: "Beta before GA",
        body: "The beta exists for tested feedback and does not include checkout or an offer.",
      },
      {
        title: "Direct support",
        body: "Support, recovery, and security reports go to support@cmdtab.net without a promised response time.",
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
