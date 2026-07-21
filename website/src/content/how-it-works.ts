export const howItWorksContent = {
  eyebrow: "Guide",
  title: "How CmdTab works in practice",
  description:
    "A short walkthrough from install to daily switching.",
  whatIs: {
    heading: "What this is",
    text:
      "CmdTab is a macOS switcher that shows live window previews before each switch.",
  },
  whoIsItFor: {
    heading: "Who it is for",
    text:
      "Anyone who switches frequently and keeps multiple windows open.",
  },
  howToStart: {
    heading: "How to get started",
    text:
      "Download the trial, grant permissions, and test in real work before deciding.",
  },
  steps: [
    {
      title: "Install and first launch",
      body:
        "Install and launch CmdTab once, then confirm permissions in System Settings.",
    },
    {
      title: "Grant permissions",
      body:
        "Grant Accessibility and Screen Recording so shortcut input and previews both work.",
    },
    {
      title: "Trial and switching",
      body:
        "Open CmdTab, scan previews or use Command Palette, then switch.",
    },
    {
      title: "Buy or continue trial",
      body: "Buy when the trial proves useful, or continue trialing while you work.",
    },
    {
      title: "Keep it healthy",
      body:
        "Recheck Settings after macOS privacy changes. Use Help for delivery or license issues.",
    },
  ],
} as const;
