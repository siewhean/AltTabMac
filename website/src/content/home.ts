export const heroContent = {
  eyebrow: "Private beta for macOS",
  title: "Find the right Mac window in one move.",
  summary:
    "CmdTab gives you real window previews, fast mode switching, keyboard-first search, and instant hot swap so you can get to the right app or window without guessing.",
  status: "Built for people who keep too many apps and windows open.",
};

export const proofPoints = [
  "Real previews with a warm first frame instead of blind icon guessing.",
  "Learned Command Palette search with acronym matching and remembered picks.",
  "Current Space, visible spaces, or all spaces with display-aware placement.",
  "Hide, minimize, close, or quit the selected item without leaving the switcher.",
  "Alternate right-side modifier triggers for one-handed sessions.",
  "Exclusions and ignored-title rules to keep noisy windows out of the way.",
  "Waitlist members get first access to the trial and founder launch price.",
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
    title: "Open, scan, release.",
    body: "Classic Grid is the fastest visual path. Hold the shortcut, skim the live previews, and release on the right window without opening the wrong app first.",
    screenshotId: "classicGrid",
  },
  {
    id: "palette-flow",
    eyebrow: "Command Palette",
    title: "Type the app name and go.",
    body: "If you already know what you want, open Command Palette, type a few letters, and jump directly to the result instead of cycling through everything else.",
    screenshotId: "commandPalette",
  },
  {
    id: "radial-flow",
    eyebrow: "Radial Menu",
    title: "Switch by direction and rhythm.",
    body: "Radial Menu gives you a stable ring for fast left-right movement when you want the selector to do more of the work than your eyes.",
    screenshotId: "radialMenu",
  },
  {
    id: "feature-flow",
    eyebrow: "Quick actions",
    title: "Act on the current selection without switching into it first.",
    body: "Hide, minimize, close, or quit directly from the switcher when you want to clean up windows instead of entering them.",
    screenshotId: "featureQuickActions",
  },
];

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
    answer: "CmdTab is private beta and waitlist-only right now.",
  },
];
