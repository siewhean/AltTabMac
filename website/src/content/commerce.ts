export const commerceContent = {
  eyebrow: "Launch path",
  title: "Start with a 14-day trial, then buy it once.",
  summary:
    "CmdTab is a premium Mac utility, not a subscription. The offer is a short free trial and a one-time license you can either buy after the trial or purchase immediately.",
  trialLength: "14-day trial",
  founder: {
    title: "Buy now",
    price: "US$5",
    note: "Buy the founder price directly if you already know you want CmdTab.",
    points: [
      "One-time purchase",
      "Buy straight away",
      "Founder price for the first launch wave",
    ],
    cta: "Buy founder license",
  },
  standard: {
    title: "Free trial",
    price: "US$9.99",
    note: "Try CmdTab for 14 days first, then decide if you want to keep it.",
    points: [
      "14-day free trial",
      "At least 1 year of updates",
      "No recurring subscription",
    ],
    cta: "Download the trial",
  },
  fallback:
    "The trial and buy buttons appear here automatically after you add the hosted URLs.",
} as const;
