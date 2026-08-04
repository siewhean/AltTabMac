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
        body: "Join the waitlist for a release notification. No beta download, installation, or operational support service is currently published.",
      },
      {
        title: "Watch for GA details",
        body: "A US$12 personal licence is planned for general availability, not the beta period.",
      },
      {
        title: "Privacy and security contact",
        body: "support@cmdtab.net is the published contact path for privacy and security reports; it does not promise a response time or beta operational support.",
      },
    ],
    notes: [
      "No payment during beta",
      "Planned US$12 at GA",
      "Privacy and security contact only",
    ],
  },
  trial: {
    eyebrow: "Public beta",
    title: "Join the CmdTab beta waitlist.",
    description:
      "Get notified when a signed Apple-silicon beta download is available. Installation, permissions, updates, licensing, and support operations remain unavailable until the required release gates pass.",
    checklist: [
      "Join the waitlist for a beta publication notification.",
      "Review the documented Accessibility and Screen Recording requirements.",
      "Read the known limitations before any future beta installation.",
    ],
    note:
      "The beta build is not published. Join the waitlist for updates; support@cmdtab.net is reserved for privacy and security reports.",
  },
  help: {
    eyebrow: "Beta boundaries",
    title: "Privacy, security, and beta availability information.",
    description:
      "CmdTab has no published beta download, installation, update, licensing, recovery, or operational-support service. Use the documented privacy and security contact path for relevant reports.",
    journey: [
      {
        title: "Check beta availability",
        body: "The signed beta is not published. Join the waitlist for a future release notification rather than attempting installation or update steps.",
      },
      {
        title: "Keep commerce fail-closed",
        body: "The planned US$12 personal licence belongs to general availability. The beta provides no payment, licence, recovery, fulfilment, or refund service.",
      },
      {
        title: "Report privacy or security concerns",
        body: "support@cmdtab.net is the published privacy and security contact path. It does not promise a response time or operational support.",
      },
    ],
    supportPoints: [
      "Review permission requirements and known limitations.",
      "Report a security issue privately.",
      "Make a privacy request through the published contact path.",
    ],
    terms: [
      {
        title: "Planned pricing",
        body: "US$12 is planned for general availability; no checkout, payment, or purchase support is available now.",
      },
      {
        title: "Unpublished beta",
        body: "The beta is still in release preparation and does not include a download, checkout, trial, or operational support service.",
      },
      {
        title: "Contact boundary",
        body: "Privacy and security reports may go to support@cmdtab.net without a promised response time; it is not a licence-recovery or beta-support service.",
      },
    ],
  },
} as const;

// Kept for the dormant, commerce-gated request handler. No public route renders
// this form while the beta's operational support boundary is fail-closed.
export const licenseRequestReasonOptions = [
  { value: "license_recovery", label: "Find my license or receipt" },
  { value: "activation_help", label: "Activation or moving to another Mac" },
  { value: "billing_question", label: "Billing or purchase question" },
  { value: "refund_request", label: "Refund request" },
  { value: "general", label: "General license help" },
] as const;
