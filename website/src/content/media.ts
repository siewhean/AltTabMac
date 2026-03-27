export type ScreenshotAsset = {
  id: string;
  src: string;
  alt: string;
  width: number;
  height: number;
  caption?: string;
  priority?: boolean;
};

export const screenshotAssets: Record<string, ScreenshotAsset> = {
  heroMaster: {
    id: "heroMaster",
    src: "/screenshots/hero/master.svg",
    alt: "CmdTab floating over a macOS desktop with a large selected window preview and supporting switcher views.",
    width: 1600,
    height: 1000,
    priority: true,
  },
  classicGrid: {
    id: "classicGrid",
    src: "/screenshots/styles/classic-grid.svg",
    alt: "Classic Grid mode showing multiple app windows with a highlighted selection state.",
    width: 1600,
    height: 1000,
    caption: "Classic Grid keeps visual scanning fast when many windows are open.",
  },
  commandPalette: {
    id: "commandPalette",
    src: "/screenshots/styles/command-palette.svg",
    alt: "Command Palette mode showing live search and filtered app results.",
    width: 1600,
    height: 1000,
    caption: "Command Palette is built for typing straight to the window you need.",
  },
  radialMenu: {
    id: "radialMenu",
    src: "/screenshots/styles/radial-menu.svg",
    alt: "Radial Menu mode with a highlighted selection around a circular switcher.",
    width: 1600,
    height: 1000,
    caption: "Radial Menu favors quick, positional switching with minimal clutter.",
  },
  previewCloseup: {
    id: "previewCloseup",
    src: "/screenshots/styles/preview-closeup.svg",
    alt: "Close-up of a CmdTab preview showing a selected app window before switching.",
    width: 1600,
    height: 1000,
    caption: "Real previews help you confirm the right target before you commit.",
  },
  featurePreviewReliability: {
    id: "featurePreviewReliability",
    src: "/screenshots/styles/preview-closeup.svg",
    alt: "CmdTab showing a stable selected window preview with the switcher remaining readable during refresh.",
    width: 1600,
    height: 1000,
    caption: "The preview layer is designed to stay stable instead of flashing back to blind icon guesses.",
  },
  featureSearchMemory: {
    id: "featureSearchMemory",
    src: "/screenshots/styles/command-palette.svg",
    alt: "CmdTab Command Palette showing a narrowed set of learned search results.",
    width: 1600,
    height: 1000,
    caption: "Command Palette search is built for repeated real-world queries, not just one-off filtering.",
  },
  featureSpaceDisplay: {
    id: "featureSpaceDisplay",
    src: "/screenshots/hero/master.svg",
    alt: "CmdTab spanning a broader desktop context to represent space and display-aware placement.",
    width: 1600,
    height: 1000,
    caption: "CmdTab can stay scoped to the right space and appear on the display that best matches your workflow.",
  },
  featureQuickActions: {
    id: "featureQuickActions",
    src: "/screenshots/styles/classic-grid.svg",
    alt: "CmdTab with a selected window ready for keyboard-driven actions like hide, minimize, close, or quit.",
    width: 1600,
    height: 1000,
    caption: "Workflow actions let you clean up or dismiss the selected item without switching into it first.",
  },
  featureDeclutter: {
    id: "featureDeclutter",
    src: "/screenshots/styles/classic-grid.svg",
    alt: "CmdTab showing a cleaner list of windows after exclusions and ignored-title rules reduce noise.",
    width: 1600,
    height: 1000,
    caption: "Exclusions and ignored-title rules keep floating clutter from stealing attention.",
  },
  featureTriggers: {
    id: "featureTriggers",
    src: "/screenshots/walkthrough/04-keyboard.svg",
    alt: "Keyboard-driven CmdTab flow illustrating alternate modifier-based trigger options.",
    width: 1600,
    height: 1000,
    caption: "Optional right-side modifier triggers add a second fast path without replacing Cmd+Tab.",
  },
  featureRadialClarity: {
    id: "featureRadialClarity",
    src: "/screenshots/styles/radial-menu.svg",
    alt: "Radial Menu mode with a clearly emphasized selected item and readable center label.",
    width: 1600,
    height: 1000,
    caption: "Radial Menu stays readable because the selected item is pushed harder than the rest of the ring.",
  },
  modeTriptych: {
    id: "modeTriptych",
    src: "/screenshots/styles/triptych.svg",
    alt: "Comparison strip showing Classic Grid, Command Palette, and Radial Menu side by side.",
    width: 1600,
    height: 1000,
    caption: "Three modes let CmdTab match the way you already think and move.",
  },
  walkthroughInvoke: {
    id: "walkthroughInvoke",
    src: "/screenshots/walkthrough/01-invoke.svg",
    alt: "CmdTab appearing instantly over the current Mac desktop after the switcher shortcut is pressed.",
    width: 1600,
    height: 1000,
  },
  walkthroughScan: {
    id: "walkthroughScan",
    src: "/screenshots/walkthrough/02-scan.svg",
    alt: "CmdTab showing several windows while the user scans previews and moves selection.",
    width: 1600,
    height: 1000,
  },
  walkthroughCommit: {
    id: "walkthroughCommit",
    src: "/screenshots/walkthrough/03-commit.svg",
    alt: "CmdTab collapsing after a window is selected and brought forward.",
    width: 1600,
    height: 1000,
  },
  walkthroughKeyboard: {
    id: "walkthroughKeyboard",
    src: "/screenshots/walkthrough/04-keyboard.svg",
    alt: "Keyboard-first view showing shortcut hints and command-driven navigation through CmdTab.",
    width: 1600,
    height: 1000,
  },
  permissions: {
    id: "permissions",
    src: "/screenshots/permissions/settings.svg",
    alt: "CmdTab next to macOS privacy settings for Accessibility and Screen Recording permissions.",
    width: 1600,
    height: 1000,
  },
};
