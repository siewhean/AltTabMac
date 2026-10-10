import { siteConfig } from "@/content/site";

export const privacyContent = {
  intro:
    "This page explains what the CmdTab website and native app currently collect, which fields are transmitted, and how that information is used while you browse, start a trial, activate a license, or run the app.",
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
        "When you join the beta waitlist, CmdTab stores your email address, your name if you give one, the page you signed up from, a request identifier, the delivery status of the confirmation email, and when you signed up. If you accepted optional analytics, the landing-page path and campaign labels described above are stored as well.",
        "Each signup receives a personal invite code and a link to confirm the address. If you arrive through a friend's invite link, that code is saved in this browser for up to 30 days and stored with your signup, only to credit your friend; this does not depend on optional analytics. Inviting 5 friends who each confirm a real email address can earn a free CmdTab license, which a person reviews before it is granted.",
        "To keep the invite reward fair, a signup also stores keyed (HMAC) hashes of your network (the first part of your IP address, never the full address), of a random identifier your browser keeps after you submit the form, and of the network you confirmed the address from. These are used only to detect one person creating several signups or inviting themselves, are never used for advertising or analytics, are not shared, and are deleted 90 days after signup unless a referral is waiting for review. Matching signals make an invitation ineligible or send it for review; they are not proof of wrongdoing, and you can write to us to contest a decision. Different spellings of one mailbox (for example Gmail dots or plus tags) count as one address.",
        "The address is used only to email you about CmdTab beta access, trial availability, and launch. It is not sold or shared for anyone else's marketing. Emails are delivered through Resend, and the list is stored in CmdTab's database hosted through Vercel.",
        "To limit abuse, short-lived hashed fingerprints derived from the submitted address and network request are kept temporarily for rate limiting. They expire automatically.",
        "Every waitlist email includes an unsubscribe link. Unsubscribing deletes your waitlist record. Signups are otherwise kept until you unsubscribe, ask for deletion, or the beta list is no longer needed.",
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
        "Starting a trial sends the email address provided by the user together with the install identifier, app version, and macOS version so the trial period can be registered and enforced.",
        "To allow one trial per Mac, the app also sends a one-way, CmdTab-specific hash of the Mac's hardware identifier. The hardware identifier itself never leaves the Mac, and the hash is used only to enforce the trial.",
        "Activating a license sends a hashed device identifier and the Mac's name (as set in System Settings) so the license holder can recognise and manage their activated Macs. The name is shown only to someone holding that license's activation code.",
        "Purchase, receipt, billing, and license-portal information may be processed by the hosted commerce provider. CmdTab stores the operational records required to fulfil licenses and handle support requests.",
        "Trial registration, purchase, download, licensing, fulfilment, fraud prevention, refunds, and support are essential product operations. They remain available when optional analytics are declined and are not switched on or off by the analytics controls.",
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
        "Hosting and edge delivery are provided through Vercel. If you accept optional analytics, Vercel Web Analytics and Speed Insights also process aggregate traffic and performance measurements.",
        "Transactional email may be delivered through Resend. Hosted checkout, receipt, and license-management links may point to Lemon Squeezy or another configured commerce provider, whose own terms and privacy policy apply to that transaction.",
      ],
    },
    {
      title: "Retention, access, and deletion",
      body: [
        "CmdTab keeps purchase, license, activation, fulfilment, fraud-prevention, refund, revocation, and support records while they are needed to operate and recover perpetual licenses. Non-personal order, license, refund, chargeback, dispute, and revocation tombstones may be retained indefinitely so recovery cannot bypass payment or revocation state.",
        "Optional website analytics and native-app telemetry are retained while needed for the stated product and reliability purposes or until the associated record is deleted. Withdrawing analytics consent stops future collection and deletes browser-side CmdTab visitor and session identifiers; it does not retroactively identify and delete already pseudonymized server events.",
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
