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

