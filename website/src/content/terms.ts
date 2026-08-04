import { productFacts } from "@/content/product-facts";

export const termsReviewedAt = "2026-07-27";

export const termsSections = [
  {
    title: "Public beta access",
    body: [
      "CmdTab is preparing a direct, Apple-silicon-only public beta. No beta download is currently published; if approved for publication, it will be provided for testing and feedback, not as a paid offer.",
      "The beta configuration has no checkout, payment, fulfilment, subscription, refund, or licence-sale path. A US$12 personal licence is planned for general availability only.",
      "If a beta is published, do not redistribute it or use it to access data that is not yours. Keep backups of important work and use the published privacy or security contact path for relevant reports.",
    ],
  },
  {
    title: "Permissions and limitations",
    body: [
      `The planned beta target requires ${productFacts.minimumMacOS} and claims Apple-silicon support only. Intel Macs and configurations without clean-machine acceptance are not covered.`,
      "Accessibility is required for exact-window switching. Screen Recording enables previews; if preview capture is unavailable, eligible windows use an icon or placeholder presentation.",
    ],
  },
  {
    title: "Updates, support, and recovery",
    body: [
      "If approved for publication, beta updates will use the isolated beta channel. No beta download or beta update feed is currently published; stable downloads and stable update feeds remain unavailable until general availability.",
      "support@cmdtab.net is the published privacy and security contact path. It does not promise a response time or indicate that installation, update, licensing, recovery, or other support operations are currently available. CmdTab will never ask for your password.",
    ],
  },
  {
    title: "Security reporting",
    body: [
      "You may report a suspected vulnerability privately to support@cmdtab.net with the affected build, macOS version, reproduction steps, and impact.",
      "Do not access other people’s data, publish unpatched details, alter production data, use social engineering, or conduct sustained denial-of-service testing.",
    ],
  },
  {
    title: "Warranty and liability",
    body: [
      "CmdTab is provided as available and without warranties beyond those required by law. Window close and application quit actions can cause unsaved work to be lost; review the selected target before using them.",
      "To the maximum extent permitted by law, CmdTab is not liable for indirect, incidental, special, or consequential loss. Nothing here excludes rights or liability that cannot legally be excluded.",
    ],
  },
  {
    title: "Privacy, retention, and changes",
    body: [
      "The Privacy page describes optional analytics, aggregate app telemetry, the fail-closed beta commerce boundary, third parties, and the privacy-request path.",
      "The beta configuration collects only the data documented in the Privacy page. No beta payment, purchase, receipt, licence, activation, fulfilment, or support-operation data is collected because those operations are unavailable.",
      "Material changes to these planned beta terms apply prospectively and will be shown with a new review date. Future paid licences will be subject to terms published with an operating general-availability purchase service and applicable law.",
    ],
  },
] as const;
