export const privacyContent = {
  intro:
    "This page explains what the CmdTab website and native app currently collect, which fields are transmitted, and how that information is used while you browse, start a trial, activate a license, or run the app.",
  sections: [
    {
      title: "Website analytics",
      body: [
        "The website records page path, referrer, event name and context, event timestamp, a locally generated visitor identifier, and a session identifier. Campaign parameters and a broad discovery-source label may be stored so traffic from search, ChatGPT, Copilot, Perplexity, Gemini, Claude, and other referrals can be measured without storing a search query.",
        "The site also uses Vercel Web Analytics and Speed Insights for aggregate traffic and performance measurement.",
      ],
    },
    {
      title: "Native app telemetry",
      body: [
        "When the current app starts, it sends an app-activation event and then an hourly heartbeat while it remains running. It also reports trial-start and license-activation events.",
        "The current payload contains a pseudonymous install identifier, event name, license state, license identifier when present, app version, macOS version, and event timestamp.",
        "The current native-app telemetry payload does not contain window titles, window previews, screenshots, keystrokes, file names, clipboard contents, or search queries.",
      ],
    },
    {
      title: "Trial and licensing information",
      body: [
        "Starting a trial sends the email address provided by the user together with the install identifier, app version, and macOS version so the trial period can be registered and enforced.",
        "Purchase, receipt, billing, and license-portal information may be processed by the hosted commerce provider. CmdTab stores the operational records required to fulfil licenses and handle support requests.",
      ],
    },
    {
      title: "How the information is used",
      body: [
        "Website analytics are used to understand discovery, page performance, trial and purchase journeys, and whether factual product pages answer the questions visitors bring from search and AI-assisted discovery.",
        "App telemetry is used to understand active installations, trial state, license activation, app versions, macOS versions, and broad product activity. It is not used to reconstruct the contents of a user's open windows.",
      ],
    },
    {
      title: "Third-party services",
      body: [
        "Hosting, edge delivery, Web Analytics, and Speed Insights are provided through Vercel, which may process the operational data needed to deliver and measure the site.",
        "Transactional email may be delivered through Resend. Hosted checkout, receipt, and license-management links may point to Lemon Squeezy or another configured commerce provider, whose own terms and privacy policy apply to that transaction.",
      ],
    },
    {
      title: "Retention, access, and deletion",
      body: [
        "CmdTab keeps operational data for analytics, trial enforcement, licensing, fulfilment, support, fraud prevention, and launch operations. Retention periods should be reviewed as the public release process matures and documented here when formal limits are adopted.",
        "For access, correction, or deletion requests concerning CmdTab-held data, contact tohsh17@gmail.com and include enough information to locate the relevant trial, purchase, support request, or install record.",
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
        "Report a suspected security issue in the website or app privately to tohsh17@gmail.com.",
        "CmdTab also publishes its disclosure policy at /.well-known/security.txt and on the Security page.",
      ],
    },
  ],
};
