export const howItWorksContent = {
  eyebrow: "Guide",
  title: "How CmdTab works in practice",
  description:
    "A practical walkthrough of how CmdTab gets you from install to a stable switching routine, including permissions and trial setup.",
  whatIs: {
    heading: "What this is",
    text:
      "CmdTab is a macOS utility for window-level switching. It shows live previews so you can pick the right window before switching, even in crowded desktops.",
  },
  whoIsItFor: {
    heading: "Who it is for",
    text:
      "Anyone who switches often, keeps many windows open, and wants confidence before every switch.",
  },
  howToStart: {
    heading: "How to get started",
    text:
      "Download the trial, grant Accessibility and Screen Recording permissions, then try a few real workflow switches before purchasing.",
  },
  steps: [
    {
      title: "Install and first launch",
      body:
        "Install CmdTab and launch it once. Then confirm menu and overlay permissions in System Settings so switching works on the first attempt.",
    },
    {
      title: "Grant permissions",
      body:
        "Grant Accessibility for shortcut handling and Screen Recording for live preview content before your first switch.",
    },
    {
      title: "Trial and switching",
      body:
        "Open the switcher, scan previews or use Command Palette, and commit only when the target feels clear.",
    },
    {
      title: "Buy or continue trial",
      body: "Move to one-time purchase once the trial proves useful. Keep the Help page handy for activation and receipt questions.",
    },
    {
      title: "Keep it healthy",
      body:
        "Revisit CmdTab Settings when privacy settings change, and use Help for delivery or license questions.",
    },
  ],
} as const;
