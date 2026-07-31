import { productFacts } from "@/content/product-facts";

export const termsReviewedAt = "2026-07-27";

export const termsSections = [
  {
    title: "Public beta access",
    body: [
      "CmdTab’s public beta is a direct, Apple-silicon-only download. It is provided for testing and feedback, not as a paid offer.",
      "The beta has no checkout, payment, fulfilment, subscription, refund, or licence-sale path. A US$12 personal licence is planned for general availability only.",
      "Do not redistribute the beta or use it to access data that is not yours. Keep backups of important work and report reproducible issues through the documented support path.",
    ],
  },
  {
    title: "Permissions and limitations",
    body: [
      `CmdTab requires ${productFacts.minimumMacOS}. The public beta claims Apple-silicon support only; Intel Macs and configurations without clean-machine acceptance are not covered.`,
      "Accessibility is required for exact-window switching. Screen Recording enables previews; if preview capture is unavailable, eligible windows use an icon or placeholder presentation.",
    ],
  },
  {
    title: "Updates, support, and recovery",
    body: [
      "Beta updates use the isolated beta channel. Stable downloads and stable update feeds are unavailable until general availability.",
      "Email support@cmdtab.net for installation, update, security, or existing licence-recovery guidance. CmdTab will never ask for your password and does not promise a particular response time.",
    ],
  },
  {
    title: "Security reporting",
    body: [
      "Report suspected vulnerabilities privately to support@cmdtab.net with the affected beta build, macOS version, reproduction steps, and impact.",
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
      "The Privacy page describes optional analytics, app telemetry, product operations, third parties, and the available access or deletion request path.",
      "CmdTab’s beta operations collect only the data documented in the Privacy page. No beta payment or fulfilment data is collected because no beta purchase path exists.",
      "Material changes to these beta terms apply prospectively and will be shown with a new review date. Existing paid licences remain subject to the terms that applied at purchase and applicable law.",
    ],
  },
] as const;
