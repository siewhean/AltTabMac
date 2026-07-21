export const heroContent = {
  eyebrow: "Window switching for macOS",
  title: "A macOS app switcher that shows the real window first.",
  summary:
    "CmdTab shows live previews, so you can confirm the exact window before switching. Quick mode changes keep your flow smooth.",
  status:
    "Built for people who keep lots of apps open. Start with the trial, then buy once if it fits your workflow.",
};

export const proofPoints = [
  "Real previews first, so you switch by window, not by icon.",
  "Command Palette remembers common picks and supports quick acronym typing.",
  "Current space, visible spaces, or all spaces with display-aware placement.",
  "Hide, minimize, close, or quit from the switcher without opening extra windows.",
  "Alternate right-side modifier triggers for cleaner one-handed workflows.",
  "Exclude noisy apps and titles so your list stays readable.",
  "Try the trial in real work, then buy once if it feels right.",
];

export const styleVariants = [
  {
    id: "classicGrid",
    name: "Classic Grid",
    summary: "Open CmdTab, scan live thumbnails, and release on the right window.",
    bestFor: "Best when you want to scan many windows quickly.",
    screenshotId: "classicGrid",
  },
  {
    id: "commandPalette",
    name: "Command Palette",
    summary: "Type the app or window you want, then jump to it.",
    bestFor: "Best for repeated, keyboard-first switching.",
    screenshotId: "commandPalette",
  },
  {
    id: "radialMenu",
    name: "Radial Menu",
    summary: "Move through a stable ring and commit by position when directional switching is fastest.",
    bestFor: "Best when directional switching helps you move faster.",
    screenshotId: "radialMenu",
  },
];

export const walkthroughSteps = [
  {
    id: "grid-flow",
    eyebrow: "Classic Grid",
    title: "Open, scan, release.",
    body: "Hold the shortcut, scan the live previews, and release on the right window.",
    screenshotId: "walkthroughInvoke",
  },
  {
    id: "palette-flow",
    eyebrow: "Command Palette",
    title: "Type the app name and go.",
    body: "If you already know what you need, open Command Palette, type a few letters, and jump straight to the result.",
    screenshotId: "walkthroughKeyboard",
  },
  {
    id: "radial-flow",
    eyebrow: "Radial Menu",
    title: "Switch by direction and rhythm.",
    body: "Use a stable ring for left-right switching when direction is faster than typing.",
    screenshotId: "radialMenu",
  },
  {
    id: "feature-flow",
    eyebrow: "Quick actions",
    title: "Take action on the selected item first.",
    body: "Hide, minimize, close, or quit directly from the switcher when you want a quick cleanup.",
    screenshotId: "walkthroughCommit",
  },
];

export const interactiveDemoContent = {
  eyebrow: "Interactive demo",
  title: "Try the switcher in the browser before you download.",
  body:
    "Try all three modes, move the selection, and type in the palette before downloading.",
  modes: [
    {
      id: "classicGrid",
      label: "Classic Grid",
      hint: "Click tiles, or step through the selection.",
    },
    {
      id: "commandPalette",
      label: "Command Palette",
      hint: "Type a few letters and pick the result.",
    },
    {
      id: "radialMenu",
      label: "Radial Menu",
      hint: "Move around the ring without losing your place.",
    },
  ],
} as const;

export const interactiveDemoWindows = [
  {
    id: "claude",
    app: "Claude",
    title: "Security checklist review",
    accent: "from-amber-300/25 via-slate-950 to-slate-950",
    pill: "Recent",
  },
  {
    id: "telegram",
    app: "Telegram",
    title: "Founder launch feedback",
    accent: "from-sky-400/25 via-slate-950 to-slate-950",
    pill: "Messages",
  },
  {
    id: "vscode",
    app: "VS Code",
    title: "CmdTab Website",
    accent: "from-cyan/25 via-slate-950 to-slate-950",
    pill: "Code",
  },
  {
    id: "pdfgear",
    app: "PDFGear",
    title: "Launch pricing notes",
    accent: "from-rose-400/25 via-slate-950 to-slate-950",
    pill: "PDF",
  },
  {
    id: "mimestream",
    app: "Mimestream",
    title: "Launch support replies",
    accent: "from-indigo-400/20 via-slate-950 to-slate-950",
    pill: "Mail",
  },
  {
    id: "spotify",
    app: "Spotify",
    title: "Deep work mix",
    accent: "from-emerald-400/20 via-slate-950 to-slate-950",
    pill: "Audio",
  },
  {
    id: "notebooklm",
    app: "NotebookLM",
    title: "Research synthesis",
    accent: "from-violet-400/20 via-slate-950 to-slate-950",
    pill: "Notes",
  },
  {
    id: "calendar",
    app: "Calendar",
    title: "Founder launch week",
    accent: "from-orange-400/20 via-slate-950 to-slate-950",
    pill: "Plan",
  },
] as const;

export const detailBands = [
  {
    id: "previews",
    eyebrow: "Live previews",
    title: "See the right window before you switch.",
    body: "CmdTab shows live previews so you can pick the right window with confidence.",
    points: [
      "Real window thumbnails.",
      "Faster first reveal.",
      "Less wrong-window switching.",
    ],
    screenshotId: "featurePreviewReliability",
  },
  {
    id: "search",
    eyebrow: "Search that lands faster",
    title: "Command Palette is built for repeated switching patterns.",
    body: "Search by app, title, or acronym, and let recent picks make repeat searches faster.",
    points: [
      "App, title, and acronym matching.",
      "Remembered search picks.",
      "Stable ranking instead of reshuffling.",
    ],
    screenshotId: "featureSearchMemory",
  },
  {
    id: "actions",
    eyebrow: "More than switching",
    title: "Use the switcher to tidy your workspace too.",
    body: "You can hide, minimize, close, or quit directly from your current selection.",
    points: [
      "Hide the selected app.",
      "Minimize the selected window.",
      "Close the selected window.",
      "Quit when you need to.",
    ],
    screenshotId: "featureQuickActions",
  }
];

export const featureHighlights = [
  {
    title: "Hot swap without opening the switcher",
    body: "Double-tap your preferred modifier and jump to your latest app or window instantly.",
  },
  {
    title: "Space and display-aware placement",
    body: "Keep CmdTab on the current display, near your cursor, or across all displays when needed.",
  },
  {
    title: "Cleaner lists when your desktop gets noisy",
    body: "Exclude apps you never want in the switcher so your next switch lands on useful work.",
  },
];

export const permissionsContent = {
  eyebrow: "Why permissions are needed",
  title: "CmdTab uses the macOS access you need for reliable switching.",
  summary:
    "Accessibility enables shortcut handling. Screen Recording enables live previews. Permission status is shown in Settings so setup is easier.",
  notes: [
    "Accessibility powers the keyboard interaction.",
    "Screen Recording powers live previews of your open windows.",
    "Secure-input interruptions and permission state are surfaced inside CmdTab Settings.",
    "You can review both permissions any time in System Settings.",
  ],
  screenshotId: "permissions",
};

export const faqItems = [
  {
    question: "Is CmdTab available now?",
    answer: "CmdTab is currently in a waitlist-first phase while the next release is being prepared.",
  },
  {
    question: "Do I need to download the app before reading help?",
    answer: "No. You can read setup and trial details on the website first, then download when you are ready to test live.",
  },
  {
    question: "How does the trial work?",
    answer: "Start from the trial path, grant permissions, and use the full app for a short test period before upgrading.",
  },
  {
    question: "Will there be a subscription charge?",
    answer: "CmdTab is positioned as a one-time purchase after the trial phase, not a recurring monthly subscription.",
  },
];
