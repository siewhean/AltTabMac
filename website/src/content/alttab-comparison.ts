export const altTabComparison = {
  reviewedAt: "2026-10-09",
  methodology:
    "This comparison uses AltTab’s official product, pricing, and terms pages plus CmdTab’s canonical product and evidence pages. Feature tiers, prices, download counts, and compatibility can change after the review date.",
  adoptionNote:
    "AltTab’s official pricing page displayed 9.2 million downloads and 16,000 GitHub stars on the review date. Those are adoption signals, not a controlled reliability benchmark.",
  whyPay:
    "CmdTab currently accepts free waitlist signups only. Its intended focus is a global exact-window recent-use sequence, three switcher modes, remembered search choices, and Quick Actions. If you need an installable switcher today, evaluate AltTab’s available core or Apple’s built-in shortcuts; a CmdTab signup does not grant immediate access.",
  sources: [
    {
      label: "AltTab official product page",
      href: "https://alt-tab.app/",
    },
    {
      label: "AltTab official pricing",
      href: "https://alt-tab.app/pricing",
    },
    {
      label: "AltTab official terms",
      href: "https://alt-tab.app/terms",
    },
    {
      label: "CmdTab window-switcher behavior",
      href: "https://cmdtab.net/features/window-switcher",
    },
    {
      label: "CmdTab testing and evidence",
      href: "https://cmdtab.net/evidence",
    },
  ],
  rows: [
    [
      "Primary switching unit",
      "Window-oriented switcher with high-quality thumbnails in the free core.",
      "Each eligible top-level window is a separate exact target in one global recent-use sequence.",
    ],
    [
      "Search",
      "Typing to search windows is listed as an AltTab Pro feature.",
      "Command Palette searches application and window text, supports acronym-style matching, and can remember repeated selections.",
    ],
    [
      "Presentation",
      "The free core includes thumbnails and live preview. Additional appearance styles are listed in Pro.",
      "Classic Grid, Command Palette, and Radial Menu are three separate presentation modes over the same eligible-window set.",
    ],
    [
      "Window controls",
      "The official pricing page lists window controls among free features.",
      "Quick Actions can hide an app, minimize or close an exact window, or quit an app when the target exposes the required control.",
    ],
    [
      "Shortcut breadth",
      "AltTab Pro lists up to nine keyboard shortcuts.",
      "CmdTab supports Cmd+Tab and Option+Tab plus optional right-side modifier tap or double-tap triggers.",
    ],
    [
      "Commercial model",
      "Free open-source core. Pro is US$9.99 once; Pro Lifetime is US$24.99 once; new users receive a 14-day Pro trial.",
      "Free waitlist signup only. Public downloads, trials, and purchases are not available.",
    ],
    [
      "Public evidence",
      "The official site publishes large adoption figures and product documentation. This page does not convert adoption into a reliability score.",
      "CmdTab publishes its exact-window regression model, 136-case matrix, implementation review, and explicit real-macOS manual-test boundary.",
    ],
    [
      "Current product stage",
      "Mature, broadly adopted product with a free core and optional paid tier.",
      "CmdTab is accepting waitlist signups. Public release qualification is separate from its published implementation and automated tests.",
    ],
  ] as const,
  decisions: [
    {
      title: "Choose AltTab when its free core and maturity matter most",
      body:
        "AltTab is the stronger default for users who want a widely adopted Windows-style switcher, a free open-source core, high-quality thumbnails, and an optional paid power-user tier.",
    },
    {
      title: "Join the CmdTab waitlist when its planned workflow fits",
      body:
        "CmdTab’s intended workflow combines one global exact-window recent-use sequence, three presentation modes, remembered Command Palette choices, and Quick Actions. Join its free waitlist if those capabilities fit your needs, while continuing to use an available switcher today.",
    },
    {
      title: "Keep the built-in switcher when simplicity wins",
      body:
        "Neither third-party app is automatically the right answer. Apple’s built-in switcher requires no installation or additional permissions and remains appropriate for app-level switching.",
    },
  ] as const,
} as const;
