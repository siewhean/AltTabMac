export const faqItems = [
  {
    question: "What is CmdTab?",
    answer:
      "CmdTab is a native macOS window switcher that shows individual app windows with previews, exact-window recent-use ordering, search, quick actions, and three presentation modes.",
  },
  {
    question: "How is CmdTab different from the built-in macOS Cmd+Tab switcher?",
    answer:
      "Apple's built-in Cmd+Tab switcher cycles applications. CmdTab is designed around individual eligible windows, so two windows from the same app can appear as separate entries in one global recent-use sequence.",
  },
  {
    question: "Does CmdTab show multiple windows from the same app?",
    answer:
      "Yes. Eligible windows receive separate switcher entries rather than being forced into one app-level group. Users can still configure exclusions and an optional per-app window cap.",
  },
  {
    question: "How are windows ordered?",
    answer:
      "CmdTab uses one global exact-window recent-use sequence. Windows from the same app can be separated by windows from other apps, and the current exact window remains visible at the end of the cycling order.",
  },
  {
    question: "What happens when a window preview cannot be captured?",
    answer:
      "Preview availability changes presentation, not membership. An eligible window remains in the switcher using its app icon or a placeholder when Screen Recording permission or a capture path is unavailable.",
  },
  {
    question: "Which switcher modes are available?",
    answer:
      "CmdTab includes Classic Grid for visual scanning, Command Palette for keyboard search, and Radial Menu for directional selection.",
  },
  {
    question: "Does CmdTab work across Spaces and multiple displays?",
    answer:
      "CmdTab includes Current Space, Visible Spaces, and All Spaces scope options, plus placement on the active-window display, cursor display, or all displays.",
  },
  {
    question: "Which quick actions are available?",
    answer:
      "The selected item can be hidden, minimized, closed, or quit from the switcher using the configured keyboard actions.",
  },
  {
    question: "Why does CmdTab need Accessibility permission?",
    answer:
      "Accessibility lets CmdTab handle the switcher shortcut, inspect eligible windows, move selection, and focus the chosen app or exact window.",
  },
  {
    question: "Why does CmdTab need Screen Recording permission?",
    answer:
      "Screen Recording lets CmdTab capture previews of open windows. If preview capture is unavailable, eligible windows remain represented using their app icon or a placeholder.",
  },
  {
    question: "Does CmdTab upload window titles or preview images?",
    answer:
      "The current native-app telemetry payload does not contain window titles, preview images, screenshots, keystrokes, file names, clipboard contents, or search queries. Preview capture is used to render the local switcher interface.",
  },
  {
    question: "What app telemetry does CmdTab send?",
    answer:
      "Optional native-app telemetry is off by default. If enabled in Settings, the app sends a pseudonymous install identifier, event name and timestamp, license state and identifier when present, app version, and macOS version. It reports app activation, an hourly heartbeat while running, trial start, and license activation events.",
  },
  {
    question: "Does the website use analytics by default?",
    answer:
      "No. CmdTab's first-party website analytics, Vercel Web Analytics, and Speed Insights stay off until you accept. You can decline or withdraw on the Privacy page; doing so deletes the website visitor and session identifiers stored by CmdTab in that browser. Trial, purchase, download, licensing, and support features continue to work.",
  },
  {
    question: "What macOS version does CmdTab require?",
    answer:
      "The current project target and packaged app metadata require macOS 13.0 Ventura or later. Check the Compatibility and Changelog pages for build-specific changes.",
  },
  {
    question: "What is the current CmdTab version?",
    answer:
      "The current packaged version recorded in the project is CmdTab 1.0.0, build 1. The Changelog page is the canonical public source for dated changes.",
  },
  {
    question: "Is there a free trial?",
    answer:
      "CmdTab is preparing a signed public beta for Apple-silicon Macs. The beta has no checkout or payment path; join the waitlist to be notified when it is published.",
  },
  {
    question: "Is CmdTab a subscription?",
    answer:
      "No subscription is offered during beta because no purchase is offered. A US$12 personal licence is planned for general availability.",
  },
  {
    question: "What is the refund policy?",
    answer:
      "There is no refund path during beta because CmdTab does not take payment. General-availability terms will be published before any checkout opens.",
  },
  {
    question: "How do I move CmdTab to another Mac?",
    answer:
      "The public beta does not issue paid licences. For an existing licence recovery question, email support@cmdtab.net from the purchase address; CmdTab will never ask for your password.",
  },
  {
    question: "Where can I get support?",
    answer:
      "Use the Help page or email support@cmdtab.net for beta installation, permissions, update, security-reporting, or existing licence-recovery guidance. No response time is guaranteed.",
  },
] as const;
