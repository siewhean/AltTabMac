import { screenshotAssets } from "@/content/media";

export type FeatureDepthContent = {
  slug: "classic-grid" | "command-palette" | "radial-menu" | "quick-actions";
  metadataTitle: string;
  metadataDescription: string;
  eyebrow: string;
  title: string;
  description: string;
  definition: string;
  reviewedAt: string;
  screenshotId: keyof typeof screenshotAssets;
  screenshotCaption: string;
  behaviorRows: ReadonlyArray<readonly [string, string]>;
  bestFit: ReadonlyArray<string>;
  tradeoffs: ReadonlyArray<string>;
  adjacentLinks: ReadonlyArray<{
    href: string;
    label: string;
    description: string;
  }>;
};

export const featureDepthSectionLabels = {
  bestFit: "Best fit",
  tradeoffs: "Tradeoffs and limits",
} as const;

export const featureDepth = {
  classicGrid: {
    slug: "classic-grid",
    metadataTitle: "Classic Grid Mac window switcher with individual previews",
    metadataDescription:
      "See how CmdTab Classic Grid displays eligible Mac windows as separate recent-use targets, preserves membership when previews fail, and supports visual exact-window selection.",
    eyebrow: "Classic Grid",
    title: "A visual Mac window switcher for choosing one exact window",
    description:
      "Classic Grid presents eligible windows as separate tiles in the same global exact-window sequence used by every CmdTab mode. It is designed for people who identify work visually before they identify it by title.",
    definition:
      "Classic Grid is CmdTab’s thumbnail-oriented presentation mode. It does not group every window from one application into one tile: each eligible window remains its own target and can appear anywhere in the global recent-use order.",
    reviewedAt: "2026-07-21",
    screenshotId: "classicGrid",
    screenshotCaption:
      "Classic Grid shows each eligible window as a separate target; a missing capture changes the tile presentation, not membership.",
    behaviorRows: [
      ["Unit of selection", "One eligible top-level window per target"],
      ["Ordering", "One exact-window recent-use sequence across applications"],
      ["Same-app windows", "Remain separate and may be interleaved with other applications"],
      ["Current exact window", "Remains visible at the end of the cycling sequence"],
      ["Preview failure", "Uses an icon or placeholder without removing the eligible window"],
      ["Selection movement", "Follows adjacent targets in the displayed sequence"],
    ],
    bestFit: [
      "You recognize the right document, terminal, browser, or chat window faster from its appearance than its title.",
      "Several applications have multiple windows and an app icon alone is not enough to identify the target.",
      "You want the current exact-window recency order to remain visible while scanning.",
    ],
    tradeoffs: [
      "A dense visual grid requires more scanning than a text query when you already know the app or window title.",
      "Live previews depend on Screen Recording access, although eligible windows remain represented when capture is unavailable.",
      "The page does not claim a fixed reveal latency or thumbnail-render benchmark; those require real-machine measurement.",
    ],
    adjacentLinks: [
      {
        href: "/features/command-palette",
        label: "Command Palette",
        description: "Type when the title or app name is faster than visual scanning.",
      },
      {
        href: "/features/radial-menu",
        label: "Radial Menu",
        description: "Use a circular positional selector for directional switching.",
      },
      {
        href: "/evidence",
        label: "Testing and evidence",
        description: "Inspect the membership, ordering, and manual-validation boundaries.",
      },
    ],
  },
  commandPalette: {
    slug: "command-palette",
    metadataTitle: "Command Palette window search for macOS",
    metadataDescription:
      "Review CmdTab Command Palette search across app and window text, acronym matching, stable exact-window order, remembered repeated selections, and privacy boundaries.",
    eyebrow: "Command Palette",
    title: "Search open Mac windows by app name or window text",
    description:
      "Command Palette uses the same eligible-window set and exact-window recency sequence as Classic Grid, then narrows it with deterministic local matching when you type.",
    definition:
      "CmdTab Command Palette is a keyboard-first window-search mode. It matches application and window text, supports acronym-style queries, and can promote a previously chosen result when its relevance remains close to the strongest match.",
    reviewedAt: "2026-07-21",
    screenshotId: "commandPalette",
    screenshotCaption:
      "Command Palette narrows the current exact-window sequence by application and window text without sending the raw query in the current telemetry payload.",
    behaviorRows: [
      ["Search fields", "Application name and window title"],
      ["Matching", "Space-insensitive local similarity plus acronym and word-start signals"],
      ["Empty query", "Preserves the current exact-window sequence"],
      ["Ties", "Stable source order is preserved when relevance scores are equal"],
      ["Remembered choice", "May promote a prior stable target when its relevance remains close to the best match"],
      ["Current telemetry", "Does not include raw search queries"],
    ],
    bestFit: [
      "You already know part of an application name, document title, project name, or acronym.",
      "You repeatedly return to similarly named windows and want the selected result to remain predictable.",
      "Your desktop has too many visually similar windows for thumbnail scanning alone.",
    ],
    tradeoffs: [
      "Search quality depends on the window titles and application names exposed by macOS and the running app.",
      "Remembered selection is a bounded tie-break signal, not an opaque model that overrides clearly stronger text matches.",
      "The current product does not claim cloud semantic search or AI query interpretation.",
    ],
    adjacentLinks: [
      {
        href: "/features/classic-grid",
        label: "Classic Grid",
        description: "Scan individual previews when appearance is the fastest identifier.",
      },
      {
        href: "/features/radial-menu",
        label: "Radial Menu",
        description: "Switch by position when you prefer directional movement.",
      },
      {
        href: "/privacy",
        label: "Privacy contract",
        description: "Review the exact telemetry fields and excluded local window content.",
      },
    ],
  },
  radialMenu: {
    slug: "radial-menu",
    metadataTitle: "Radial Menu app and window switcher for macOS",
    metadataDescription:
      "See how CmdTab Radial Menu presents the shared exact-window sequence in a circular selector for directional movement, visible selection state, and positional recall.",
    eyebrow: "Radial Menu",
    title: "A circular Mac window switcher for directional selection",
    description:
      "Radial Menu changes the presentation, not the membership or recency contract. The same eligible exact-window targets are arranged around a circular selector with a clear current selection and center detail.",
    definition:
      "CmdTab Radial Menu is a positional presentation mode for the exact-window switcher. It is intended for users who prefer moving around a ring and remembering direction instead of scanning a long row or typing a query.",
    reviewedAt: "2026-07-21",
    screenshotId: "radialMenu",
    screenshotCaption:
      "Radial Menu uses the shared exact-window target sequence while emphasizing the selected position and its current detail.",
    behaviorRows: [
      ["Target set", "The same eligible exact-window items used by the other CmdTab modes"],
      ["Ordering", "The shared global exact-window recent-use sequence"],
      ["Presentation", "Circular positions around a selected center detail"],
      ["Same-app windows", "Remain separate targets rather than an application group"],
      ["Preview fallback", "Eligible targets remain available when a live capture is unavailable"],
      ["Commit behavior", "The selected exact target is activated and history changes only after confirmation"],
    ],
    bestFit: [
      "You use a relatively stable working set and remember targets by direction or position.",
      "You prefer a compact selector over a wide grid.",
      "You want the same exact-window recency behavior without relying on text search.",
    ],
    tradeoffs: [
      "Circular placement is less text-dense than Command Palette and can be less efficient for large, unfamiliar target sets.",
      "Positional recall changes when the eligible-window set changes, so it should not be described as a permanent app shortcut map.",
      "No fixed reaction-time advantage is claimed without controlled real-machine testing.",
    ],
    adjacentLinks: [
      {
        href: "/features/classic-grid",
        label: "Classic Grid",
        description: "Use a thumbnail grid for dense visual comparison.",
      },
      {
        href: "/features/command-palette",
        label: "Command Palette",
        description: "Search by app or window text when you know the name.",
      },
      {
        href: "/evidence",
        label: "Testing and evidence",
        description: "Review what automation proves and what still needs real-desktop testing.",
      },
    ],
  },
  quickActions: {
    slug: "quick-actions",
    metadataTitle: "Mac window switcher quick actions for hide, minimize, close, and quit",
    metadataDescription:
      "Review CmdTab quick actions for hiding apps, minimizing or closing windows, and quitting apps from the selected switcher target, including scope and failure behavior.",
    eyebrow: "Quick Actions",
    title: "Manage the selected Mac window without switching into it first",
    description:
      "CmdTab can dispatch item-appropriate actions from the current switcher selection. Window actions operate on an exact window target; app actions operate on the selected running application.",
    definition:
      "CmdTab Quick Actions are contextual operations attached to the current switcher target: hide the selected app, minimize the selected window, close the selected window, or quit the selected app.",
    reviewedAt: "2026-07-21",
    screenshotId: "featureQuickActions",
    screenshotCaption:
      "Quick Actions operate on the current selected target and refresh the visible switcher state only after an action is dispatched successfully.",
    behaviorRows: [
      ["Hide", "Hides the selected running application"],
      ["Minimize", "Sets the selected exact window’s minimized state through Accessibility"],
      ["Close", "Presses the selected exact window’s Accessibility close control when available"],
      ["Quit", "Requests termination of the selected running application"],
      ["Failure handling", "Returns without claiming success when the required app, window, or control is unavailable"],
      ["List refresh", "Refreshes the switcher after a successfully dispatched action"],
    ],
    bestFit: [
      "You want to clean up a busy desktop while remaining inside the switcher.",
      "You need to distinguish an app-wide action such as hide or quit from an exact-window action such as minimize or close.",
      "You want the visible target list to update after a successful state-changing action.",
    ],
    tradeoffs: [
      "Availability depends on the selected item type and the Accessibility controls exposed by the target application.",
      "Close and quit can discard unsaved work; CmdTab cannot replace the target app’s own confirmation or recovery behavior.",
      "Cross-app consistency requires live desktop validation because individual applications expose Accessibility controls differently.",
    ],
    adjacentLinks: [
      {
        href: "/features/window-switcher",
        label: "Window-switcher behavior",
        description: "Review membership, exact-window ordering, and activation flow.",
      },
      {
        href: "/permissions",
        label: "Permissions",
        description: "Understand why Accessibility is required for exact-window actions.",
      },
      {
        href: "/evidence",
        label: "Testing and evidence",
        description: "See the automated contract and the remaining application-by-application checks.",
      },
    ],
  },
} satisfies Record<string, FeatureDepthContent>;
