export const betaRoutes = [
  "/beta",
  "/beta/installation",
  "/beta/limitations",
  "/beta/permissions",
  "/beta/updates",
  "/beta/support",
  "/beta/security",
  "/beta/license-recovery",
] as const;

export const betaNavigation = [
  { href: "/beta", label: "Download" },
  { href: "/beta/installation", label: "Install" },
  { href: "/beta/limitations", label: "Limitations" },
  { href: "/beta/permissions", label: "Permissions" },
  { href: "/beta/updates", label: "Updates" },
  { href: "/beta/support", label: "Support" },
] as const;
