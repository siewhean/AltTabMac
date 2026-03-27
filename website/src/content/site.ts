export const siteConfig = {
  name: "CmdTab",
  tagline: "Find the right Mac window in one move.",
  description:
    "CmdTab is a faster Mac app switcher with real window previews, three visual modes, and a private beta waitlist for the upcoming 14-day trial and one-time license launch.",
  defaultSiteUrl: "https://cmdtab.app",
  socialImagePath: "/og/cover.png",
  nav: [
    { label: "Modes", href: "#modes" },
    { label: "Walkthrough", href: "#walkthrough" },
    { label: "Why it feels better", href: "#details" },
    { label: "Privacy", href: "/privacy" },
  ],
  ctas: {
    primary: "Join the private beta",
    secondary: "See the walkthrough",
    tertiary: "Read the privacy policy",
  },
  keywords: [
    "CmdTab",
    "Mac app switcher",
    "custom macOS app switcher",
    "Cmd+Tab alternative",
    "window previews for Mac",
    "app switcher with thumbnails",
    "private beta Mac app",
  ],
  contactEmail: "privacy@cmdtab.app",
} as const;
