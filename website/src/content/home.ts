export const heroContent = {
  eyebrow: "Window switching for macOS",
  title: "Find the right Mac window in one move.",
  summary:
    "CmdTab gives you real window previews, fast mode switching, keyboard-first search, and instant hot swap so you can get to the right app or window without guessing.",
  status: "Built for people who keep too many apps and windows open. Start with the trial, then buy once if it earns a place in your workflow.",
};

export const proofPoints = [
  "Real previews with a warm first frame instead of blind icon guessing.",
  "Learned Command Palette search with acronym matching and remembered picks.",
  "Current Space, visible spaces, or all spaces with display-aware placement.",
  "Hide, minimize, close, or quit the selected item without leaving the switcher.",
  "Alternate right-side modifier triggers for one-handed sessions.",
  "Exclusions and ignored-title rules to keep noisy windows out of the way.",
  "Start with the trial and buy once if CmdTab proves itself in real work.",
];

export const styleVariants = [
  {
    id: "classicGrid",
    name: "Classic Grid",
    summary: "Open the switcher, scan real thumbnails, and release on the right window.",
    bestFor: "Best for visual scanning across many open windows.",
    screenshotId: "classicGrid",
  },
  {
    id: "commandPalette",
    name: "Command Palette",
    summary: "Type straight to the app or window you want, then hit return.",
    bestFor: "Best for keyboard-heavy workflows and repeated searches.",
    screenshotId: "commandPalette",
  },
  {
    id: "radialMenu",
    name: "Radial Menu",
    summary: "Move through a stable ring and commit by position instead of scanning a long list.",
    bestFor: "Best for directional switching and positional recall.",
    screenshotId: "radialMenu",
  },
];

export const walkthroughSteps = [
  {
    id: "grid-flow",
    eyebrow: "Classic Grid",
    title: "Start with a visual scan",
    body: "Open Classic Grid, glance at the thumbnails, then release on the window you want. You can make a switch decision in one motion.",
    screenshotId: "classicGrid",
  },
  {
    id: "palette-flow",
    eyebrow: "Command Palette",
    title: "Narrow with text",
    body: "Know what you want? Use Command Palette, type the app or window title, and jump immediately without scanning a full list.",
    screenshotId: "commandPalette",
  },
  {
    id: "radial-flow",
    eyebrow: "Radial Menu",
    title: "Use position when your eyes are already open",
    body: "Radial Menu keeps target positions stable as you move through windows, so repeat flows become faster once you learn where each position lives.",
    screenshotId: "radialMenu",
  },
  {
    id: "feature-flow",
    eyebrow: "Quick actions",
    title: "Clean up your context",
    body: "Use quick actions to hide, minimize, close, or quit the selected item without opening the app. Keep your focus on what matters next.",
    screenshotId: "featureQuickActions",
  },
];

export const interactiveDemoContent = {
  eyebrow: "Interactive demo",
  title: "Try the switcher in the browser before you download.",
  body:
    "Click through the same three modes, move the selection, type into the palette, and see how each style feels when you are choosing a real target.",
  modes: [
    {
      id: "classicGrid",
      label: "Classic Grid",
      hint: "Click tiles or step through the selection.",
    },
    {
      id: "commandPalette",
      label: "Command Palette",
      hint: "Type a few letters and select the result you want.",
    },
    {
      id: "radialMenu",
      label: "Radial Menu",
      hint: "Run the selector around the ring without losing your place.",
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
    title: "See the actual window before you commit.",
    body: "CmdTab shows real previews so you can pick the right target instead of cycling through icons and hoping the next app is the one you meant.",
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
    title: "Command Palette is built for real repeated queries.",
    body: "Search by app name, title, or acronym, and let remembered picks make repeated searches feel more direct over time.",
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
    title: "Use the switcher to clean up windows too.",
    body: "CmdTab can hide apps, minimize windows, close windows, or quit apps directly from the current selection.",
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
    body: "Double-tap your chosen modifier and jump straight to the most recent app or window.",
  },
  {
    title: "Space and display-aware placement",
    body: "Keep CmdTab on the current display, the cursor display, or every display when your setup gets wider.",
  },
  {
    title: "Cleaner lists when your desktop gets noisy",
    body: "Exclude apps you never want in the switcher so the actual work stays easier to reach.",
  },
];

export const permissionsContent = {
  eyebrow: "Why permissions are needed",
  title: "CmdTab uses the same macOS access you would expect from a serious switcher.",
  summary:
    "Accessibility lets CmdTab respond to the switcher shortcut. Screen Recording lets it show real window previews. CmdTab also surfaces that health directly in Settings so permission problems are easier to diagnose.",
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
    answer: "Yes, CmdTab is available. You can download the 14-day free trial or purchase a license directly.",
  },
];
