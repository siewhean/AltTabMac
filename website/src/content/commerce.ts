export const commerceContent = {
  eyebrow: "Public beta",
  title: "CmdTab public beta is preparing for launch.",
  summary:
    "The planned beta will be an Apple-silicon download with no payment path. A US$12 personal licence is planned for general availability.",
  trialLength: "Beta waitlist",
  license: {
    title: "General availability pricing",
    price: "Planned US$12",
    note: "Planned for general availability; no purchase is available during beta.",
    points: [
      "No checkout or payment path is published",
      "No licence, fulfilment, or recovery operation is available",
      "General-availability terms will be published before checkout opens",
    ],
    cta: "Planned for GA",
  },
  trial: {
    title: "Beta waitlist",
    note: "The signed beta download appears only after the beta release is published.",
    points: [
      "Apple silicon (arm64) only",
      "No beta trial, checkout, or payment operation is available",
      "Stable download and appcast remain unavailable",
    ],
    cta: "Join beta waitlist",
  },
  fallback:
    "Join the beta waitlist for a release notification. No payment CTA is published during beta.",
} as const;
