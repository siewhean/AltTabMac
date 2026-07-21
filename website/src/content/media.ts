export type ScreenshotAsset = {
  id: string;
  src: string;
  kind?: "image" | "video";
  posterSrc?: string;
  alt: string;
  width: number;
  height: number;
  caption?: string;
  priority?: boolean;
};

export const screenshotAssets: Record<string, ScreenshotAsset> = {
  heroMaster: {
    id: "heroMaster",
    src: "/screenshots/captures/classic-grid.png",
    alt: "A CmdTab Classic Grid session with live demo windows and live window thumbnails.",
    width: 2688,
    height: 524,
    priority: true,
  },
  classicGrid: {
    id: "classicGrid",
    src: "/screenshots/captures/classic-grid.png",
    alt: "CmdTab Classic Grid showing four demo-window thumbnails with a highlighted selection.",
    width: 2688,
    height: 524,
    caption: "Classic Grid keeps visual scanning fast when many windows are open.",
  },
  commandPalette: {
    id: "commandPalette",
    src: "/screenshots/captures/command-palette.png",
    alt: "CmdTab Command Palette with the result list filtered to live demo windows.",
    width: 1040,
    height: 448,
    caption: "Command Palette is for typing directly to the window you need.",
  },
  radialMenu: {
    id: "radialMenu",
    src: "/screenshots/captures/radial-menu.png",
    alt: "CmdTab Radial Menu with privacy-safe demo apps and a highlighted selection.",
    width: 1120,
    height: 1120,
    caption: "Radial Menu works well for directional switching when you want less clutter.",
  },
  previewCloseup: {
    id: "previewCloseup",
    src: "/screenshots/captures/preview-closeup.png",
    alt: "A close-up of a selected CmdTab window preview before switching.",
    width: 720,
    height: 524,
    caption: "Live previews make sure you switch to the right window.",
  },
  featurePreviewReliability: {
    id: "featurePreviewReliability",
    src: "/screenshots/captures/preview-closeup.png",
    alt: "A selected CmdTab preview with a live thumbnail, app icon, and app name.",
    width: 720,
    height: 524,
    caption: "The preview layer stays stable and keeps you from dropping to icon-only views.",
  },
  featureSearchMemory: {
    id: "featureSearchMemory",
    src: "/screenshots/captures/command-palette-search.png",
    alt: "A CmdTab Command Palette narrowed to Performance by the query.",
    width: 1040,
    height: 448,
    caption: "Search is tuned for the queries you run repeatedly, not just one-off attempts.",
  },
  featureSpaceDisplay: {
    id: "featureSpaceDisplay",
    src: "/screenshots/captures/classic-grid.png",
    alt: "A CmdTab Classic Grid panel shown on the active display.",
    width: 2688,
    height: 524,
    caption: "CmdTab can stay in the current space and open where your workflow expects it.",
  },
  featureQuickActions: {
    id: "featureQuickActions",
    src: "/screenshots/captures/classic-grid-scan.png",
    alt: "A CmdTab Classic Grid session with a selected demo window ready for a keyboard action.",
    width: 2688,
    height: 524,
    caption: "Quick actions let you clean up the selected item without opening it first.",
  },
  featureDeclutter: {
    id: "featureDeclutter",
    src: "/screenshots/captures/classic-grid.png",
    alt: "A CmdTab window list scoped to four privacy-safe demo applications.",
    width: 2688,
    height: 524,
    caption: "Exclusions and ignored titles keep noisy windows out of your view.",
  },
  featureTriggers: {
    id: "featureTriggers",
    src: "/screenshots/captures/command-palette-search.png",
    alt: "A keyboard-driven CmdTab Command Palette search session.",
    width: 1040,
    height: 448,
    caption: "Optional right-side modifier triggers add a second fast path without replacing Cmd+Tab.",
  },
  featureRadialClarity: {
    id: "featureRadialClarity",
    src: "/screenshots/captures/radial-menu.png",
    alt: "A CmdTab Radial Menu session with a selected item and readable center label.",
    width: 1120,
    height: 1120,
    caption: "The selected item is emphasized so the active target stays clear.",
  },
  walkthroughInvoke: {
    id: "walkthroughInvoke",
    src: "/screenshots/captures/classic-grid.png",
    alt: "A CmdTab Classic Grid panel after invocation with live demo-window previews.",
    width: 2688,
    height: 524,
  },
  walkthroughScan: {
    id: "walkthroughScan",
    src: "/screenshots/captures/classic-grid-scan.png",
    alt: "A CmdTab Classic Grid panel while scanning live previews with a moved selection.",
    width: 2688,
    height: 524,
  },
  walkthroughCommit: {
    id: "walkthroughCommit",
    src: "/screenshots/captures/classic-grid-commit.png",
    alt: "A CmdTab Classic Grid panel with the target demo window selected before commit.",
    width: 2688,
    height: 524,
  },
  walkthroughKeyboard: {
    id: "walkthroughKeyboard",
    src: "/screenshots/captures/command-palette-search.png",
    alt: "A CmdTab keyboard search narrowed to one demo application.",
    width: 1040,
    height: 448,
  },
  permissions: {
    id: "permissions",
    src: "/screenshots/permissions/settings.svg",
    alt: "CmdTab next to macOS privacy settings for Accessibility and Screen Recording.",
    width: 1600,
    height: 1000,
  },
};
