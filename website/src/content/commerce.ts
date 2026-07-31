export const commerceContent = {
  eyebrow: "Public beta",
  title: "CmdTab public beta is preparing for launch.",
  summary:
    "The beta is a direct Apple-silicon download with no payment path. A US$12 personal licence is planned for general availability.",
  trialLength: "Public beta",
  license: {
    title: "General availability pricing",
    price: "Planned US$12",
    note: "Planned for general availability; no purchase is available during beta.",
    points: [
      "Use on up to three personally owned Macs",
      "All CmdTab 1.x updates",
      "Self-service device deactivation",
      "14-day full-refund policy",
    ],
    cta: "Planned for GA",
  },
  trial: {
    title: "Beta access",
    note: "The signed beta download appears only after the beta release is published.",
    points: [
      "Apple silicon (arm64) only",
      "No checkout or payment during beta",
      "Stable release and appcast remain unavailable",
    ],
    cta: "Download beta",
  },
  fallback:
    "Join the beta waitlist for a release notification. No payment CTA is published during beta.",
} as const;
