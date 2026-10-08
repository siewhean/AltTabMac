import { productFacts } from "@/content/product-facts";

export const marketLandscape = {
  reviewedAt: "2026-07-21",
  methodology:
    "This comparison uses first-party product pages and Apple Support only. A missing claim is treated as unknown, not as a missing feature. Prices, download counts, platform support, and feature tiers can change after the review date.",
  options: [
    {
      id: "macos",
      name: "Built-in macOS switching",
      operator: "Apple",
      commercialModel: "Included with macOS",
      minimumSystem: "The behavior depends on the installed macOS release.",
      switchingModel:
        "Command-Tab cycles open applications. Command–grave accent cycles windows belonging to the application currently in use.",
      search:
        "No text search inside the built-in Command-Tab application switcher.",
      previews:
        "The Command-Tab switcher is app-oriented. Mission Control is the separate built-in overview for open windows and Spaces.",
      distinctiveFit:
        "Best for people who want no installation, no extra permissions, and are comfortable combining app switching with a separate same-app window shortcut.",
      sourceLabel: "Apple Support: Mac keyboard shortcuts",
      sourceUrl: "https://support.apple.com/en-sg/102650",
      secondarySourceLabel: "Apple Support: See all your open windows",
      secondarySourceUrl: "https://support.apple.com/en-ae/guide/mac-help/mchlb7beb9af/mac",
    },
    {
      id: "alttab",
      name: "AltTab",
      operator: "AltTab",
      commercialModel:
        "Free open-source core. The official pricing page lists Pro at US$9.99 and Pro Lifetime at US$24.99, with a 14-day Pro trial.",
      minimumSystem:
        "Check the current download page and release notes before installing; platform support can change.",
      switchingModel:
        "A window-oriented switcher with thumbnails. The official site presents the free tier as the core window-switching experience.",
      search:
        "Typing to search windows is listed as a Pro feature.",
      previews:
        "The free tier includes high-quality thumbnails and live-preview capabilities according to the official feature comparison.",
      distinctiveFit:
        "A mature, broadly adopted choice for users who want Windows-style window switching, an open-source core, and an optional paid power-user tier.",
      sourceLabel: "AltTab official product page",
      sourceUrl: "https://alt-tab.app/",
      secondarySourceLabel: "AltTab official pricing",
      secondarySourceUrl: "https://alt-tab.app/pricing",
    },
    {
      id: "bettercmdtab",
      name: "BetterCmdTab",
      operator: "BetterCmdTab",
      commercialModel:
        "The official site describes it as free forever, open source under GPL v3, with no subscription.",
      minimumSystem:
        "The official site lists macOS 13.0 or later and support for Apple Silicon and Intel.",
      switchingModel:
        "A native app launcher and switcher with list, grid, live-preview, current-app window cycling, and scoped shortcuts.",
      search:
        "Fuzzy search can filter open items and launch installed applications.",
      previews:
        "The official site lists live window previews as a built-in layout.",
      distinctiveFit:
        "Strong fit for users prioritizing free/open-source distribution, deep shortcut configuration, launch features, and an explicit zero-telemetry claim.",
      sourceLabel: "BetterCmdTab official product and FAQ",
      sourceUrl: "https://bettercmdtab.app/",
    },
    {
      id: "contexts",
      name: "Contexts",
      operator: "Contexts",
      commercialModel:
        "The official site offers a free trial and a US$9.99 license.",
      minimumSystem:
        "The official page lists Contexts 3.9 for macOS Ventura, Sonoma, and Sequoia.",
      switchingModel:
        "A window switcher combining Fast Search, an enhanced Command-Tab flow, a persistent Sidebar, and a trackpad gesture workflow.",
      search:
        "Fast Search filters by application name or window title and is designed to make frequently used windows reachable with a small number of keystrokes.",
      previews:
        "The current first-party page emphasizes search, the Sidebar, gestures, Spaces, and multi-display behavior. It does not provide enough detail on the page to compare thumbnail behavior here, so that point remains unknown.",
      distinctiveFit:
        "Strong fit for users who want deterministic window search, an always-available Sidebar, trackpad gestures, and explicit multiple-Space and multiple-display workflows.",
      sourceLabel: "Contexts official product page",
      sourceUrl: "https://contexts.co/",
    },
    {
      id: "cmdtab",
      name: "CmdTab",
      operator: "CmdTab",
      commercialModel:
        "Waitlist only. Free signup; public downloads, trials, and purchases are not available. Final pricing will be published at launch.",
      minimumSystem: productFacts.minimumMacOS,
      switchingModel:
        "Each eligible top-level window is a separate target in one exact-window recent-use sequence, including multiple windows from the same app.",
      search:
        "Command Palette searches by app and window text, with remembered repeated selections.",
      previews:
        "Live previews are used when available. Capture failure changes the visual fallback, not whether an eligible window remains represented.",
      distinctiveFit:
        "Strong fit for users who want three presentation modes, exact-window global recency, search, quick actions, configurable Space scope, and configurable display placement.",
      sourceLabel: "CmdTab window-switcher behavior",
      sourceUrl: "https://cmdtab.net/features/window-switcher",
      secondarySourceLabel: "CmdTab testing and evidence",
      secondarySourceUrl: "https://cmdtab.net/evidence",
    },
    {
      id: "scopo",
      name: "Scopo",
      operator: "Scopo",
      commercialModel:
        "The window switcher is free. The official pricing page lists Pro at US$1.99 per month or US$15 per year, with an optional 30-day Pro trial.",
      minimumSystem: "The official window-switcher page lists macOS 13 or later.",
      switchingModel:
        "A project-aware window switcher focused on showing windows from the current macOS Space, with cross-Space search when needed.",
      search:
        "The official site describes window search across Spaces.",
      previews:
        "The free switcher includes a live preview deck according to the official pricing table.",
      distinctiveFit:
        "Strong fit for people who organize projects by macOS Space and want the switcher, tiling, profiles, and workspace organization to share that mental model.",
      sourceLabel: "Scopo window-switcher feature page",
      sourceUrl: "https://scopo.app/features/window-switcher",
      secondarySourceLabel: "Scopo official pricing",
      secondarySourceUrl: "https://scopo.app/pricing",
    },
  ],
} as const;

export type MarketLandscapeOption = (typeof marketLandscape.options)[number];
