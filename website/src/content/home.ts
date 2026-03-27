export const heroContent = {
  eyebrow: "Private beta for macOS",
  title: "Find the right Mac window in one move.",
  summary:
    "CmdTab gives you instant app switching, real window previews, learned search, quick actions, and three visual modes so you can move faster without guessing. Waitlist members get first access to the 14-day trial and founder pricing.",
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
    summary: "Scan open apps and windows at a glance with a wide thumbnail layout.",
    bestFor: "Best for visual scanning and familiar, Expose-like switching.",
    screenshotId: "classicGrid",
  },
  {
    id: "commandPalette",
    name: "Command Palette",
    summary: "Type to filter the list live, reuse learned searches, and land on the right result fast.",
    bestFor: "Best for keyboard-heavy workflows, acronym matching, and fast narrowing.",
    screenshotId: "commandPalette",
  },
  {
    id: "radialMenu",
    name: "Radial Menu",
    summary: "Use a compact ring layout when you want position and muscle memory to do more of the work without losing the selected target.",
    bestFor: "Best for directional switching, quick positional recall, and a louder selected state.",
    screenshotId: "radialMenu",
  },
];

export const walkthroughSteps = [
  {
    id: "invoke",
    eyebrow: "01",
    title: "Bring the switcher up instantly.",
    body: "CmdTab opens over the app you are already using, and it can stay on the active display, the cursor display, or every display when your setup gets wider.",
    screenshotId: "walkthroughInvoke",
  },
  {
    id: "scan",
    eyebrow: "02",
    title: "See what is actually open before you switch.",
    body: "Real window previews help you choose the right target without guessing from icons alone, and the preview path stays warm so the first frame lands faster.",
    screenshotId: "walkthroughScan",
  },
  {
    id: "commit",
    eyebrow: "03",
    title: "Commit with confidence.",
    body: "Selection states stay crisp and readable, whether you are cycling visually, using the louder Radial selection treatment, or typing directly to the result you want.",
    screenshotId: "walkthroughCommit",
  },
  {
    id: "keyboard",
    eyebrow: "04",
    title: "Keep the whole flow keyboard-first.",
    body: "Use the shortcut, skim the previews, hide or close the selected item, and let remembered palette searches take you back to the right window without slowing down to think about the UI.",
    screenshotId: "walkthroughKeyboard",
  },
];

export const detailBands = [
  {
    id: "previews",
    eyebrow: "Preview reliability",
    title: "Real previews matter most when the first frame is the one you can trust.",
    body: "CmdTab keeps a warm preview path so the switcher can appear quickly, preserve previously captured thumbnails, and avoid collapsing back to icon-only guessing every time the list refreshes.",
    points: [
      "Fast provisional paint on the first reveal.",
      "Preserved thumbnails instead of flickering back to icons.",
      "Window-level targeting tuned to reduce wrong-window commits.",
    ],
    screenshotId: "featurePreviewReliability",
  },
  {
    id: "search",
    eyebrow: "Learned narrowing",
    title: "Command Palette gets sharper the more you use it.",
    body: "Palette search does not just filter raw strings. It supports acronym matching, stable ranking, and remembered short queries so repeated searches become faster over time.",
    points: [
      "Match app names, window titles, and acronyms.",
      "Remember which result you picked for short recurring queries.",
      "Keep ranking deterministic instead of reshuffling the list every time.",
    ],
    screenshotId: "featureSearchMemory",
  },
  {
    id: "spaces",
    eyebrow: "Space and display awareness",
    title: "Switch on the right display and at the right scope for the way your Mac is set up.",
    body: "CmdTab can stay focused on the current space, visible spaces, or all spaces, and it can appear on the active-window display, the cursor display, or mirror to every display when that is what your setup needs.",
    points: [
      "Current Space, visible spaces, or all spaces.",
      "Active display, cursor display, or all displays.",
      "Built for multi-window and multi-monitor workflows instead of assuming a single laptop screen.",
    ],
    screenshotId: "featureSpaceDisplay",
  },
  {
    id: "actions",
    eyebrow: "Workflow actions",
    title: "Act on the selected item without switching into it first.",
    body: "CmdTab moves beyond being a viewer. While the switcher is open, you can hide an app, minimize a window, close a window, or quit an app directly from the current selection.",
    points: [
      "Hide app.",
      "Minimize window.",
      "Close window.",
      "Quit app.",
    ],
    screenshotId: "featureQuickActions",
  },
  {
    id: "declutter",
    eyebrow: "Window hygiene",
    title: "Keep noisy utility windows and apps out of the switcher.",
    body: "CmdTab lets you exclude entire apps or ignore title fragments so menulets, floating palettes, picture-in-picture windows, and other distractions do not compete with the windows you actually care about.",
    points: [
      "Exclude by app name or bundle identifier.",
      "Ignore recurring title fragments for utility windows.",
      "Turn a messy desktop into a shorter, more profitable selection list.",
    ],
    screenshotId: "featureDeclutter",
  },
  {
    id: "triggers",
    eyebrow: "Trigger flexibility",
    title: "Keep ⌘Tab as the headline and add a second path when you want one-handed access.",
    body: "CmdTab now supports optional right-side modifier triggers, including tap and double-tap flows, so heavy users can open the switcher without always holding Tab.",
    points: [
      "Right Command tap or double tap.",
      "Right Option tap or double tap.",
      "Secondary access path without compromising the main shortcut.",
    ],
    screenshotId: "featureTriggers",
  },
  {
    id: "radial",
    eyebrow: "Selection clarity",
    title: "Radial Menu stays readable when position matters most.",
    body: "The Radial mode does not just look different. The selected result is pushed harder with a louder node treatment and a center readout so you keep track of the active target even when the ring gets dense.",
    points: [
      "Stronger selected-state emphasis.",
      "Clearer center labeling for the active item.",
      "A radial layout that stays legible instead of collapsing into icon soup.",
    ],
    screenshotId: "featureRadialClarity",
  },
  {
    id: "modes",
    eyebrow: "Three modes",
    title: "Use the switcher that fits how your brain already works.",
    body: "Some people want a strong visual grid. Some want a command-style list. Some want position and rhythm. CmdTab gives you all three without turning the app into a settings maze.",
    points: [
      "Classic Grid for visual scanning.",
      "Command Palette for direct narrowing.",
      "Radial Menu for positional recall.",
    ],
    screenshotId: "modeTriptych",
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
  {
    question: "Do I need to pay to try it?",
    answer:
      "Not during the private beta. The public launch is planned as a 14-day free trial, with founder pricing at US$14.99 for early adopters and a standard one-time license at US$24.99 after launch.",
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
    question: "Can CmdTab do more than just switch windows?",
    answer:
      "Yes. While the switcher is open, CmdTab can hide the selected app, minimize the selected window, close the selected window, or quit the selected app.",
  },
  {
    question: "Does CmdTab support alternate triggers?",
    answer:
      "Yes. The app keeps ⌘Tab as the main path, and it can also use optional right-side modifier tap or double-tap triggers for one-handed access.",
  },
  {
    question: "Who is CmdTab for?",
    answer:
      "Anyone who uses a Mac and wants a faster, clearer way to switch apps and windows without relying on guesswork.",
  },
  {
    question: "Will CmdTab be a subscription?",
    answer:
      "No. CmdTab is being positioned as a direct-sold Mac utility with a one-time license, not a recurring subscription.",
  },
];
