export const faqItems = [
  {
    question: "What is CmdTab?",
    answer:
      "CmdTab is a native macOS window switcher that shows individual app windows with previews, recent-use ordering, search, quick actions, and three presentation modes.",
  },
  {
    question: "How is CmdTab different from the built-in macOS Cmd+Tab switcher?",
    answer:
      "The built-in switcher primarily cycles applications. CmdTab is designed around individual eligible windows, so two windows from the same app can appear as separate entries in the global recent-use sequence.",
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
    question: "What macOS version does CmdTab require?",
    answer:
      "The current project target requires macOS 13 or later. Public release notes should be checked for any build-specific compatibility changes.",
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
