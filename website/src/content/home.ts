export const heroContent = {
  eyebrow: "Private beta for macOS",
  title: "Find the right Mac window in one move.",
  summary:
    "CmdTab gives you instant app switching, real window previews, and three visual modes so you can move faster without guessing.",
  status: "Built for people who keep too many apps and windows open.",
};

export const proofPoints = [
  "Instant switching with no bloated dashboard layer.",
  "Real window previews before you commit.",
  "Classic Grid, Command Palette, and Radial Menu.",
  "Launch at login and stay ready all day.",
];

export const styleVariants = [
  {
    id: "classicGrid",
    name: "Classic Grid",
    summary: "Scan open apps and windows at a glance with a wide thumbnail layout.",
    bestFor: "Best for visual scanning and familiar, Expose-like switching.",
    screenshotId: "classicGrid",
  },
  {
    id: "commandPalette",
    name: "Command Palette",
    summary: "Type to filter the list live and land on the right result fast.",
    bestFor: "Best for keyboard-heavy workflows and fast narrowing.",
    screenshotId: "commandPalette",
  },
  {
    id: "radialMenu",
    name: "Radial Menu",
    summary: "Use a compact ring layout when you want position and muscle memory to do more of the work.",
    bestFor: "Best for directional switching and quick positional recall.",
    screenshotId: "radialMenu",
  },
];

export const walkthroughSteps = [
  {
    id: "invoke",
    eyebrow: "01",
    title: "Bring the switcher up instantly.",
    body: "CmdTab opens over the app you are already using, so you stay in context instead of breaking focus.",
    screenshotId: "walkthroughInvoke",
  },
  {
    id: "scan",
    eyebrow: "02",
    title: "See what is actually open before you switch.",
    body: "Real window previews help you choose the right target without guessing from icons alone.",
    screenshotId: "walkthroughScan",
  },
  {
    id: "commit",
    eyebrow: "03",
    title: "Commit with confidence.",
    body: "Selection states stay crisp and readable, whether you are cycling visually or typing directly to the result you want.",
    screenshotId: "walkthroughCommit",
  },
  {
    id: "keyboard",
    eyebrow: "04",
    title: "Keep the whole flow keyboard-first.",
    body: "Use the shortcut, skim the previews, and land on the right window without slowing down to think about the UI.",
    screenshotId: "walkthroughKeyboard",
  },
];

export const detailBands = [
  {
    id: "previews",
    eyebrow: "Real previews",
    title: "Confirm the right window before you leave the one you are in.",
    body: "CmdTab shows real window thumbnails so you can tell the difference between two browser windows, two editors, or three chat threads without trial and error.",
    screenshotId: "previewCloseup",
  },
  {
    id: "modes",
    eyebrow: "Three modes",
    title: "Use the switcher that fits how your brain already works.",
    body: "Some people want a strong visual grid. Some want a command-style list. Some want position and rhythm. CmdTab gives you all three without turning the app into a settings maze.",
    screenshotId: "modeTriptych",
  },
  {
    id: "launch",
    eyebrow: "Always ready",
    title: "Launch at login and keep the fast path available all day.",
    body: "CmdTab is designed to feel like part of your Mac, not a tool you need to remember to open before it becomes useful.",
    screenshotId: "heroMaster",
  },
];

export const permissionsContent = {
  eyebrow: "Why permissions are needed",
  title: "CmdTab uses the same macOS access you would expect from a serious switcher.",
  summary:
    "Accessibility lets CmdTab respond to the switcher shortcut. Screen Recording lets it show real window previews. Both are required for the full experience.",
  notes: [
    "Accessibility powers the keyboard interaction.",
    "Screen Recording powers live previews of your open windows.",
    "You can review both permissions any time in System Settings.",
  ],
  screenshotId: "permissions",
};

export const faqItems = [
  {
    question: "Is CmdTab available now?",
    answer: "CmdTab is private beta and waitlist-only right now.",
  },
  {
    question: "Do I need to pay to try it?",
    answer:
      "Not yet. A free trial and paid license are planned for a future release, but the beta site only collects interest today.",
  },
  {
    question: "Why does CmdTab need Accessibility and Screen Recording permissions?",
    answer:
      "Accessibility powers the switcher interaction, and Screen Recording enables real window previews.",
  },
  {
    question: "What are the three visual modes?",
    answer: "Classic Grid, Command Palette, and Radial Menu.",
  },
  {
    question: "Who is CmdTab for?",
    answer:
      "Anyone who uses a Mac and wants a faster, clearer way to switch apps and windows without relying on guesswork.",
  },
];

