import { siteConfig } from "@/content/site";

export const privacyContent = {
  intro:
    "This page explains what the CmdTab website and native app currently collect, which fields are transmitted, and how that information is used while you browse, start a trial, activate a license, or run the app.",
  lastUpdated: "2026-10-15",
  sections: [
    {
      title: "Website analytics",
      body: [
        "Optional website analytics are off by default. CmdTab does not create its website visitor identifier or session identifier and does not load Vercel Web Analytics or Speed Insights until you accept.",
        "If accepted, the website records page path, referrer, event name and context, event timestamp, a locally generated visitor identifier, and a session identifier. Campaign parameters and a broad discovery-source label may be stored so traffic from search, ChatGPT, Copilot, Perplexity, Gemini, Claude, and other referrals can be measured without storing a search query.",
        "If you accept optional analytics and then submit the waitlist form, the landing-page path and safe campaign labels (UTM source, medium, campaign, and content) may be stored with your waitlist request to measure which campaign links lead to requests. Those attribution fields are omitted when analytics consent is not accepted. To make this work across pages, the campaign labels from the link you arrived on are kept in this browser tab's session storage; they are not sent anywhere unless you accepted optional analytics and submit the form.",
        "You can decline or withdraw consent at any time using the controls on this page. Declining or withdrawing deletes the CmdTab website visitor and session identifiers stored in this browser and stops future optional analytics requests.",
      ],
    },
    {
      title: "Beta waitlist",
      body: [
        "When you join the beta waitlist, CmdTab stores your email address, your name if you give one, the page you signed up from, a request identifier, the delivery status of the welcome email, and when you signed up. If you accepted optional analytics, the landing-page path and campaign labels described above are stored as well.",
        "Entering your email is all it takes to join: you are in the beta as soon as the signup is saved. Each signup receives a personal invite code and an optional link to verify the address; verifying matters only for the invite reward and for product-update consent. If you arrive through a friend's invite link, that code is saved in this browser for up to 30 days and stored with your signup, only to credit your friend; this does not depend on optional analytics. Inviting 5 friends who each verify a real email address can earn a free CmdTab license, which a person reviews before it is granted.",
        "The signup form has an optional, unchecked box to receive occasional product updates; ticking it records that choice with a timestamp and takes effect when you verify the address. After you sign up you may answer one optional question about how you will use CmdTab, which is stored with your signup. The free-license reward is limited to the first 100 qualifying members. To keep the invite reward fair, a signup also stores keyed (HMAC) hashes of your network (the first part of your IP address, never the full address), of a random identifier your browser keeps after you submit the form, and of the network you verified the address from. These are used only to detect one person creating several signups or inviting themselves, are never used for advertising or analytics, are not shared, and are deleted 90 days after signup unless a referral is waiting for review. Matching signals make an invitation ineligible or send it for review; they are not proof of wrongdoing, and you can write to us to contest a decision. Different spellings of one mailbox (for example Gmail dots or plus tags) count as one address.",
        "The address is used only to email you about CmdTab beta access, trial availability, and launch. It is not sold or shared for anyone else's marketing. Emails are delivered through Resend, and the list is stored in CmdTab's database (see Third-party services). A notice of each new signup, with the email address and name, is sent to CmdTab's own mailbox.",
        "To limit abuse, short-lived hashed fingerprints derived from the submitted address and network request are kept temporarily for rate limiting. They expire automatically.",
        "Every waitlist email includes an unsubscribe link. Unsubscribing deletes your waitlist record, and you receive no further waitlist email. If you sign up again later, you start over as a new signup. Signups are kept until you unsubscribe, ask for deletion, or the beta list is no longer needed.",
      ],
    },
    {
      title: "Native app telemetry",
      body: [
        "Optional native-app telemetry is off by default and can be enabled or disabled in CmdTab Settings. When enabled, the app sends an app-activation event and then an hourly heartbeat while it remains running. It also reports trial-start and license-activation events.",
        "When enabled, the payload contains a pseudonymous install identifier, event name, license state, license identifier when present, app version, macOS version, and event timestamp.",
        "The current native-app telemetry payload does not contain window titles, window previews, screenshots, keystrokes, file names, clipboard contents, or search queries.",
      ],
    },
    {
      title: "Trial and licensing information",
      body: [
        "Starting a trial sends the email address provided by the user together with the install identifier, app version, and macOS version so the trial period can be registered and enforced. The address is also used to email you a reminder before the trial ends.",
        "To allow one trial per Mac, the app also sends a one-way, CmdTab-specific hash of the Mac's hardware identifier. The hardware identifier itself never leaves the Mac, and the hash is used only to enforce the trial.",
        "Activating a license sends the activation code, a device identifier (a hash of a random value created on that Mac), and the Mac's name (as set in System Settings) so the license holder can recognise and manage their activated Macs. The name is shown only to someone holding that license's activation code. CmdTab stores activation codes only as hashes.",
        "A paid license is a 30-day lease that the app renews automatically by sending its current license token and the device identifier. Listing or deactivating activated Macs sends the activation code and the device identifier.",
        "Purchase, receipt, billing, and license-portal information may be processed by the hosted commerce provider. For each purchase CmdTab stores the operational records required to fulfil licenses and handle support requests: the purchaser's email address and name, order number, product, amount and currency, receipt link, and the issued license, which is emailed to the purchaser. A license-recovery request stores only a hash of the email address entered.",
        "Trial registration, purchase, download, licensing, fulfilment, fraud prevention, refunds, and support are essential product operations. They remain available when optional analytics are declined and are not switched on or off by the analytics controls.",
      ],
    },
    {
      title: "License help requests",
      body: [
        "The license help form sends your email address, your name and purchase email if you give them, the reason you choose, your message, and the page you sent it from. CmdTab stores the request and emails it to its own mailbox so it can reply.",
      ],
    },
    {
      title: "How the information is used",
      body: [
        "When accepted, website analytics are used to understand discovery, page performance, trial and purchase journeys, and whether factual product pages answer the questions visitors bring from search and AI-assisted discovery.",
        "When enabled, app telemetry is used to understand active installations, trial state, license activation, app versions, macOS versions, and broad product activity. It is not used to reconstruct the contents of a user's open windows.",
      ],
    },
    {
      title: "Third-party services",
      body: [
        "Hosting and edge delivery are provided through Vercel, which processes request data such as IP addresses to deliver the site; CmdTab's server functions run in Vercel's Singapore region. If you accept optional analytics, Vercel Web Analytics and Speed Insights also process aggregate traffic and performance measurements.",
        "To limit abuse, requests to the waitlist, trial, licensing, help, analytics, and telemetry endpoints are rate-limited using short-lived keyed hashes of the network address, user agent, and, where given, email address. They expire automatically.",
        "CmdTab's database is PostgreSQL hosted by Neon in the AWS Singapore region (ap-southeast-1). Nightly encrypted backups of it are stored in Amazon S3 in the same region.",
        "Trial and license tokens are signed with keys held in AWS Key Management Service (US East region). The data sent for signing contains only hashed identifiers, not your email address or Mac name.",
        `Signup notices, help requests, and privacy requests are sent to CmdTab's own mailbox, ${siteConfig.contactEmail}.`,
        "Transactional email, including waitlist, trial-reminder, and license emails, is delivered through Resend, which processes it in the United States. Hosted checkout, receipt, and license-management links may point to Lemon Squeezy or another configured commerce provider, whose own terms and privacy policy apply to that transaction.",
        "We and our service providers process data in Singapore and the United States. Where the law requires it, these transfers rely on our providers' standard contractual clauses.",
      ],
    },
    {
      title: "Retention, access, and deletion",
      body: [
        "CmdTab keeps purchase, license, activation, fulfilment, fraud-prevention, refund, revocation, and support records while they are needed to operate and recover perpetual licenses. Non-personal order, license, refund, chargeback, dispute, and revocation tombstones may be retained indefinitely so recovery cannot bypass payment or revocation state.",
        "Trial records are kept for 90 days after the trial ends. Then the email address and other personal details are deleted automatically. Only hashed device identifiers and the trial dates are kept, so the same Mac cannot start another free trial.",
        "Optional native-app telemetry, optional website analytics events, and license help requests are kept for 90 days and then deleted automatically. Withdrawing analytics consent stops future collection and deletes browser-side CmdTab visitor and session identifiers; it does not retroactively identify and delete already pseudonymized server events.",
        "Deleted records can remain in encrypted database backups until those backups expire, up to 35 days later.",
        `For access, correction, or deletion requests concerning CmdTab-held data, contact ${siteConfig.contactEmail} and include enough information to locate the relevant trial, purchase, support request, or install record.`,
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
        `Report a suspected security issue in the website or app privately to ${siteConfig.contactEmail}.`,
        "CmdTab also publishes its disclosure policy at /.well-known/security.txt and on the Security page.",
      ],
    },
  ],
};
