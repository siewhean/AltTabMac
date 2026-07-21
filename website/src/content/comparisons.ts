export type ComparisonFeature = {
  feature: string;
  cmdtab: string;
  competitor: string;
  isCmdtabSuperior: boolean;
};

export type ComparisonContent = {
  slug: string;
  competitorName: string;
  title: string;
  eyebrow: string;
  description: string;
  heroHeading: string;
  heroSubheading: string;
  features: ComparisonFeature[];
  keyDifferences: {
    title: string;
    description: string;
  }[];
  faq: {
    question: string;
    answer: string;
  }[];
};

export const altTabComparison: ComparisonContent = {
  slug: "alttab",
  competitorName: "AltTab",
  title: "CmdTab vs AltTab for macOS",
  eyebrow: "CmdTab vs AltTab",
  description:
    "Compare CmdTab and AltTab for daily macOS window switching and pick based on speed, modes, and workflow fit.",
  heroHeading: "A faster, multi-mode AltTab-style switcher.",
  heroSubheading:
    "AltTab gives you window-grid switching. CmdTab adds ScreenCaptureKit previews, search memory, and inline window actions.",
  features: [
    {
      feature: "Capture Engine & Performance",
      cmdtab: "ScreenCaptureKit primary, with first-frame render around 50ms",
      competitor: "Quartz WindowServer API capture",
      isCmdtabSuperior: true,
    },
    {
      feature: "Visual Switcher Modes",
      cmdtab: "Classic Grid, Command Palette, Radial Menu",
      competitor: "Grid thumbnail overlay only",
      isCmdtabSuperior: true,
    },
    {
      feature: "Fuzzy Search & Ranking",
      cmdtab: "Acronym search with query memory",
      competitor: "Title filtering only",
      isCmdtabSuperior: true,
    },
    {
      feature: "Inline Quick Actions",
      cmdtab: "Hide, minimize, close, or quit from the switcher",
      competitor: "Close/minimize shortcuts only",
      isCmdtabSuperior: true,
    },
    {
      feature: "Alternate Modifier Triggers",
      cmdtab: "Right-command and right-option single/double tap activation",
      competitor: "Primary shortcut customization",
      isCmdtabSuperior: true,
    },
    {
      feature: "Multi-Display & Space Awareness",
      cmdtab: "Current display, cursor display, or all-display mode",
      competitor: "Display and space controls",
      isCmdtabSuperior: true,
    },
    {
      feature: "Privacy & Data Safety",
      cmdtab: "100% local processing; zero screen/content telemetry",
      competitor: "100% local processing (Open Source)",
      isCmdtabSuperior: false,
    },
    {
      feature: "Licensing & Support",
      cmdtab: "14-day trial, then one-time purchase with direct support",
      competitor: "Free + open source",
      isCmdtabSuperior: false,
    },
  ],
  keyDifferences: [
    {
      title: "ScreenCaptureKit capture path",
      description:
        "CmdTab uses ScreenCaptureKit on modern macOS for first-frame previews before legacy retries begin.",
    },
    {
      title: "Learned Command Palette Search",
      description:
        "Search by app, title, or acronym. Recent picks are ranked higher over time.",
    },
    {
      title: "Radial Menu for direction-based switching",
      description:
        "Visible windows show in a ring around the center, so directional movement stays fast.",
    },
    {
      title: "Inline Window Management",
      description:
        "Hide, minimize, close, or quit from CmdTab without opening another control surface.",
    },
  ],
  faq: [
    {
      question: "Is CmdTab better than AltTab for macOS?",
      answer:
        "If you want a single-grid switcher, AltTab is fine. If you want multiple switcher styles and faster previews, CmdTab fits better.",
    },
    {
      question: "Can I try CmdTab for free if I currently use AltTab?",
      answer:
        "Yes. You can run CmdTab next to AltTab and use the trial for real workflow testing.",
    },
    {
      question: "Does CmdTab replace native macOS ⌘Tab like AltTab does?",
      answer:
        "Yes. CmdTab handles ⌘Tab and ⌥Tab with a global hotkey handler and live window previews.",
    },
  ],
};

export const contextsComparison: ComparisonContent = {
  slug: "contexts",
  competitorName: "Contexts",
  title: "CmdTab vs Contexts for macOS",
  eyebrow: "CmdTab vs Contexts",
  description:
    "Compare CmdTab and Contexts to choose the better fit for modern macOS windows and workflows.",
  heroHeading: "A modern Mac switcher built for current OS versions.",
  heroSubheading:
    "Contexts is a classic switcher. CmdTab adds ScreenCaptureKit-first previews and a few workflow shortcuts for speed.",
  features: [
    {
      feature: "Modern macOS Optimization",
      cmdtab: "Built natively for macOS 13, 14, and 15",
      competitor: "Older release cadence for recent macOS versions",
      isCmdtabSuperior: true,
    },
    {
      feature: "Capture Engine Latency",
      cmdtab: "ScreenCaptureKit primary path, warm render near 50ms",
      competitor: "Accessibility plus legacy WindowServer path",
      isCmdtabSuperior: true,
    },
    {
      feature: "Visual Modes",
      cmdtab: "Classic Grid, Command Palette, Radial Menu",
      competitor: "Sidebar panel, overlay grid, search panel",
      isCmdtabSuperior: true,
    },
    {
      feature: "Search & Acronym Ranking",
      cmdtab: "Learned search and acronym ranking",
      competitor: "Fast character matching & search panel",
      isCmdtabSuperior: true,
    },
    {
      feature: "Inline Quick Actions",
      cmdtab: "Direct hotkey actions (⌘H hide, ⌘M minimize, ⌘W close, ⌘Q quit)",
      competitor: "Basic window activation & closing",
      isCmdtabSuperior: true,
    },
    {
      feature: "Licensing Model",
      cmdtab: "14-day trial, then one-time purchase",
      competitor: "Paid license ($9.99 - $14.99)",
      isCmdtabSuperior: false,
    },
  ],
  keyDifferences: [
    {
      title: "Built for modern macOS",
      description:
        "CmdTab uses current Swift, AppKit, and ScreenCaptureKit foundations for faster launch and fewer capture edge cases.",
    },
    {
      title: "Three Flexible Visual Modes",
      description:
        "Pick from Classic Grid, Command Palette, or Radial Menu based on how you switch.",
    },
    {
      title: "Search Memory Store",
      description:
        "Search adapts over time; repeated windows move toward the top of your results.",
    },
  ],
  faq: [
    {
      question: "Why switch from Contexts to CmdTab?",
      answer:
        "If you want faster preview rendering on recent macOS versions and more switcher styles, CmdTab is usually the easier upgrade.",
    },
    {
      question: "Can I use CmdTab alongside my existing workflows?",
      answer:
        "Yes. Keep your current setups and add CmdTab with custom shortcut mapping and right-side modifier options.",
    },
  ],
};
