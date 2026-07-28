import { commerceContent } from "@/content/commerce";

export const dashboardContent = {
  title: "CmdTab launch dashboard",
  summary:
    "This page is the owner-facing view of the website funnel, pricing setup, event instrumentation, and operational support flows. Core website traffic and interaction metrics are mirrored into this dashboard from the live site.",
  offer: [
    { label: "License price", value: commerceContent.license.price },
    { label: "Trial length", value: commerceContent.trialLength },
  ],
  funnelMetrics: [
    {
      title: "Acquisition",
      metrics: [
        "Visitors and pageviews via Vercel Web Analytics",
        "Traffic source metadata from homepage waitlist submissions",
        "CTA click-through on hero, walkthrough, launch, and waitlist sections",
      ],
    },
    {
      title: "Conversion",
      metrics: [
        "Waitlist submissions",
        "License recovery and billing support requests",
        "Launch section trial clicks",
        "Launch section checkout clicks",
      ],
    },
    {
      title: "Preference signals",
      metrics: [
        "Which switcher mode demo visitors choose most often",
        "Which demo targets visitors interact with most",
        "Command Palette search usage bucketed by query length and result count",
      ],
    },
  ],
  privacyNote:
    "Preference metrics are instrumented in an aggregate-safe way. The demo does not send raw search text; it only sends coarse buckets like query length and result count.",
  sources: [
    {
      title: "Vercel Web Analytics",
      body: "Use this for traffic, referrers, top pages, and click events.",
      href: "https://vercel.com/dashboard",
    },
    {
      title: "Vercel Speed Insights",
      body: "Use this for page performance, slow routes, and render quality.",
      href: "https://vercel.com/dashboard",
    },
  ],
} as const;
