export const heroContent = {
  eyebrow: "Window switching for macOS",
  title: "A macOS app switcher that shows the real window first.",
  summary:
    "CmdTab shows live previews so you can confirm the exact window before switching. Keep your flow fast without extra clicks.",
  status:
    "Built for people who keep lots of apps open. Start with the trial, then buy once if it fits your workflow.",
};

export const proofPoints = [
  "Real previews first, so you switch by window, not by icon.",
  "Command Palette remembers your common picks and stays quick for repeated searches.",
  "Choose current space, visible spaces, or all spaces with display-aware placement.",
  "Hide, minimize, close, or quit without opening extra windows.",
  "Right-side modifier triggers for cleaner one-handed workflows.",
  "Filter out noisy apps and title patterns.",
  "Try the trial in real work, then buy once if it feels right.",
];

export const styleVariants = [
  {
    id: "classicGrid",
    name: "Classic Grid",
    summary: "Open CmdTab, scan live thumbnails, and release on the right window.",
    bestFor: "Best when you need to scan many windows quickly.",
    screenshotId: "classicGrid",
  },
  {
    id: "commandPalette",
    name: "Command Palette",
    summary: "Type the app or window you want and jump straight to it.",
    bestFor: "Best for repeated keyboard-only switching.",
    screenshotId: "commandPalette",
  },
  {
    id: "radialMenu",
    name: "Radial Menu",
    summary: "Move through a stable ring and commit by position.",
    bestFor: "Best when directional switching is faster than typing.",
    screenshotId: "radialMenu",
  },
];

export const walkthroughSteps = [
  {
    id: "grid-flow",
    eyebrow: "Classic Grid",
    title: "Open, scan, switch.",
    body: "Hold the shortcut, scan live previews, and switch to the window you need.",
    screenshotId: "walkthroughInvoke",
  },
  {
    id: "palette-flow",
    eyebrow: "Command Palette",
    title: "Type the app name and go.",
    body: "If you already know your target, open Command Palette, type a few letters, and jump.",
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
    title: "Clean up before you move on.",
    body: "Hide, minimize, close, or quit directly from the selected item.",
    screenshotId: "walkthroughCommit",
  },
];

export const interactiveDemoContent = {
  eyebrow: "Interactive demo",
  title: "Try the switcher in the browser before you download.",
  body:
    "Try all three modes before download: move the selection, and type in the palette.",
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
    body: "CmdTab shows live previews so you can confirm the target window before switching.",
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
    title: "Search lands faster for repeated patterns.",
    body: "Search by app, title, or acronym, and let recent picks stay top.",
    points: [
      "App, title, and acronym matching.",
      "Remembered search picks.",
      "Stable ranking instead of reshuffling every time.",
      ],
    screenshotId: "featureSearchMemory",
  },
  {
    id: "actions",
    eyebrow: "More than switching",
    title: "Use the switcher to tidy your workspace.",
    body: "From the selected window, hide, minimize, close, or quit.",
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
    body: "Double-tap your preferred modifier and jump to your latest app or window.",
  },
  {
    title: "Space and display-aware placement",
    body: "Show CmdTab on current display, near your cursor, or across all displays.",
  },
  {
    title: "Cleaner lists when your desktop gets noisy",
    body: "Exclude apps you never want in the switcher so the next switch hits useful work.",
  },
];

export const permissionsContent = {
  eyebrow: "Why permissions are needed",
  title: "CmdTab uses the macOS access you need for reliable switching.",
  summary:
    "Accessibility handles shortcut input. Screen Recording enables live previews. Permissions are shown in Settings.",
  notes: [
    "Accessibility powers the keyboard interaction.",
    "Screen Recording powers live previews of your open windows.",
    "Secure-input interruptions and permission state show up in CmdTab Settings.",
    "You can review both permissions any time in System Settings.",
  ],
  screenshotId: "permissions",
};

export const faqItems = [
  {
    question: "Is CmdTab available now?",
    answer: "CmdTab is currently in a waitlist-first phase. A new release is being prepared.",
  },
  {
    question: "Do I need to download the app before reading help?",
    answer: "No. You can read setup and trial details here, then download when you are ready to test.",
  },
  {
    question: "How does the trial work?",
    answer: "Start with the trial, grant permissions, and use the app in real work before upgrading.",
  },
  {
    question: "Will there be a subscription charge?",
    answer: "CmdTab is a one-time purchase after the trial. No monthly subscription.",
  },
];
