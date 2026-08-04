export const privacyContent = {
  intro:
    "This page describes the information CmdTab currently collects while you browse the website and the telemetry contract that would apply if an approved beta build is later made available. It describes the beta's fail-closed configuration; it does not announce or provide beta checkout, payment, trial registration, licensing, fulfilment, or customer-support operations.",
  sections: [
    {
      title: "Website analytics",
      body: [
        "Optional website analytics are off by default. CmdTab does not create its website visitor identifier or session identifier and does not load Vercel Web Analytics or Speed Insights until you accept.",
        "If accepted, the website records page path, referrer, event name and context, event timestamp, a locally generated visitor identifier, and a session identifier. Campaign parameters and a broad discovery-source label may be stored so traffic from search, ChatGPT, Copilot, Perplexity, Gemini, Claude, and other referrals can be measured without storing a search query.",
        "You can decline or withdraw consent at any time using the controls on this page. Declining or withdrawing deletes the CmdTab website visitor and session identifiers stored in this browser and stops future optional analytics requests.",
      ],
    },
    {
      title: "Native app telemetry",
      body: [
        "Optional native-app telemetry is off by default and can be enabled or disabled in CmdTab Settings. When enabled, the app sends an app-activation event and then an hourly heartbeat while it remains running.",
        "When enabled, the payload contains event name, license state without a license identifier, app version, macOS version, and event timestamp. It does not contain an install, device, account, or license identifier.",
        "The fixed telemetry schema reserves state labels for a future licensing implementation. Those labels do not start a beta trial, activate a beta license, fulfil an order, or make a beta purchase service available.",
        "The current native-app telemetry payload does not contain window titles, window previews, screenshots, keystrokes, file names, clipboard contents, search queries, tokens, or secrets.",
      ],
    },
    {
      title: "Beta commerce and licensing boundary",
      body: [
        "CmdTab's beta configuration does not provide checkout, payment, receipts, billing, trial registration, license activation or recovery, fulfilment, refunds, or purchase processing.",
        "Related commerce endpoints and background work are fail-closed while the beta commerce switch is disabled. Optional analytics consent cannot enable those operations.",
      ],
    },
    {
      title: "How the information is used",
      body: [
        "When accepted, website analytics are used to understand discovery, page performance, and whether factual product pages answer the questions visitors bring from search and AI-assisted discovery.",
        "When enabled, app telemetry is used to understand aggregate app versions, macOS versions, and broad product activity. It is not used to count uniquely identifiable installations, establish an entitlement, or reconstruct the contents of a user's open windows.",
      ],
    },
    {
      title: "Third-party services",
      body: [
        "Hosting and edge delivery are provided through Vercel. If you accept optional analytics, Vercel Web Analytics and Speed Insights also process aggregate traffic and performance measurements.",
        "The beta does not expose transactional email, hosted checkout, receipt, billing, or license-management services. A future commerce provider is not part of this beta privacy practice.",
      ],
    },
    {
      title: "Retention, access, and deletion",
      body: [
        "Optional website analytics and native-app telemetry are retained while needed for the stated product and reliability purposes. Withdrawing analytics consent stops future collection and deletes browser-side CmdTab visitor and session identifiers; native telemetry records are aggregate-only and cannot be linked back to an install or account.",
        "Because beta commerce is fail-closed, CmdTab does not collect or retain beta payment, purchase, receipt, license, activation, fulfilment, refund, or fraud-prevention records.",
        "For an access, correction, or deletion request concerning CmdTab-held data, contact support@cmdtab.net with enough information to identify the request. This contact path does not promise a response time.",
      ],
    },
    {
      title: "Permissions and local window data",
      body: [
        "The website does not request macOS Accessibility or Screen Recording permission. Those permissions apply only to the native app.",
        "Accessibility is used to detect the switcher shortcut, inspect eligible windows, and focus the selected target. Screen Recording is used to render local window previews. If preview capture is unavailable, eligible windows remain represented with an icon or placeholder.",
      ],
    },
    {
      title: "Security contact",
      body: [
        "Report a suspected security issue in the website or app privately to support@cmdtab.net.",
        "CmdTab also publishes its disclosure policy at /.well-known/security.txt and on the Security page.",
      ],
    },
  ],
};
