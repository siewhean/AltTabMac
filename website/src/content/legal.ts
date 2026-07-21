export const privacyContent = {
  intro:
    "This page explains what the website and app collect, why we keep it, and what choices you have.",
  sections: [
    {
      title: "What we collect",
      body: [
        "We collect limited site metadata like page path, performance signals, and campaign context so we can understand how people move through the site.",
        "Starting a trial stores your email, a random install identifier, trial dates, and app/macOS versions so your trial state survives reinstalls.",
        "When you make a purchase or request license help, we store contact details, provider order IDs, fulfillment status, and the license token tied to that order.",
        "Optional in-app diagnostics stay off by default. If you turn them on in Settings, CmdTab sends a random install ID, app and macOS versions, license state, optional license ID, and activation heartbeat signals. CmdTab does not send window titles, thumbnails, app contents, keystrokes, or what apps you switch between.",
      ],
    },
    {
      title: "How we use it",
      body: [
        "We use site analytics to understand where people come from and how pages perform.",
        "Trial, purchase, and support data is used to prevent trial abuse, fulfill licenses, recover purchases, support users, and investigate delivery failures.",
        "Optional app diagnostics are used to measure active installs and reliability. You can disable them at any time in Settings > Licensing > Diagnostics & Privacy.",
      ],
    },
    {
      title: "Third-party services",
      body: [
        "Hosting and edge protections use Vercel, which may process operational data needed to serve the website and API routes.",
        "The site uses Vercel Web Analytics and Speed Insights for aggregate traffic and performance data.",
        "Email delivery uses Resend, hosted checkout uses Lemon Squeezy, and production records are stored in managed PostgreSQL. Those providers process data only for their parts under their own policies.",
      ],
    },
    {
      title: "Retention and deletion",
      body: [
        "CmdTab keeps operational records only as long as needed for analytics, trial checks, purchases, support, and security. Backups can keep deleted records for a short recovery window.",
        "If you want access, correction, or deletion of your data, email the CmdTab team at tohsh17@gmail.com. Purchase records may still be kept for tax, fraud checks, refunds, or accounting.",
      ],
    },
    {
      title: "Security contact",
      body: [
        "If you suspect a security issue in the website or app, report it to security@cmdtab.net.",
        "CmdTab publishes a disclosure contact and policy at /.well-known/security.txt and on the security page.",
      ],
    },
    {
      title: "Permissions and the app itself",
      body: [
        "The website itself does not request macOS Accessibility or Screen Recording permissions.",
        "Accessibility is used for global shortcut handling and window activation. Screen Recording is used locally to generate window previews. Previews stay on your Mac and are not uploaded by CmdTab.",
      ],
    },
  ],
};
