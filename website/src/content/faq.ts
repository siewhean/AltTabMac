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
      "The current app sends a pseudonymous install identifier, event name and timestamp, license state and identifier when present, app version, and macOS version. It reports app activation, an hourly heartbeat while running, trial start, and license activation events.",
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
      "Yes. The current commercial path offers a 14-day trial so users can test CmdTab in their normal workflow before purchasing.",
  },
  {
    question: "Is CmdTab a subscription?",
    answer:
      "No. CmdTab is presented as a one-time purchase rather than a recurring subscription.",
  },
  {
    question: "Where can I get support?",
    answer:
      "Use the Help page for trial access, installation, activation, purchase recovery, billing, refunds, or moving a license to another Mac.",
  },
] as const;
