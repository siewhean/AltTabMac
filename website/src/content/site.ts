// Keep the landing page concise; detailed evidence and technical material live on dedicated routes.
export const siteConfig = {
  name: "CmdTab",
  tagline: "Choose the exact Mac window, not just the app.",
  description:
    "CmdTab is a standalone macOS window-switcher app, separate from Apple’s built-in Command-Tab shortcut, with individual window previews, search, quick actions, and exact-window recency.",
  defaultSiteUrl: "https://cmdtab.net",
  socialImagePath: "/showcase/overview-poster.webp",
  nav: [
    { label: "Modes", href: "#modes" },
    { label: "Showcase", href: "/showcase" },
    { label: "Features", href: "#details" },
    { label: "Waitlist", href: "/waitlist" },
  ],
  ctas: {
    primary: "Join the waitlist",
    secondary: "Watch the app",
    tertiary: "Read the privacy policy",
  },
  keywords: [
    "CmdTab",
    "CmdTab macOS app switcher",
    "CmdTab window switcher",
    "Mac app switcher",
    "custom macOS app switcher",
    "Cmd+Tab alternative",
    "window previews for Mac",
    "app switcher with thumbnails",
    "Mac window switcher with quick actions",
    "Mac app switcher with search memory",
    "display-aware app switcher for Mac",
    "Mac app beta waitlist",
    "macOS productivity beta",
    "Mac window switcher waitlist",
  ],
  contactPath: "/help",
} as const;
