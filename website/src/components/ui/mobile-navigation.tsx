import Link from "next/link";

const mobileNavItems = [
  { href: "/features/window-switcher", label: "Switcher and modes" },
  { href: "/showcase", label: "Real app showcase" },
  { href: "/evidence", label: "Testing and evidence" },
  { href: "/guides/switch-between-windows-on-mac", label: "Mac window guide" },
  { href: "/compare/mac-window-switchers", label: "Switcher landscape" },
  { href: "/compare/cmdtab-vs-alttab", label: "CmdTab vs AltTab" },
  { href: "/compare/cmdtab-vs-macos-command-tab", label: "Compare with macOS" },
  { href: "/compatibility", label: "Compatibility" },
  { href: "/permissions", label: "Permissions" },
  { href: "/faq", label: "FAQ" },
  { href: "/buy", label: "Buy" },
  { href: "/help", label: "Help" },
] as const;

export function MobileNavigation() {
  return (
    <details className="group relative z-50 lg:hidden">
      <summary className="inline-flex min-h-10 cursor-pointer list-none items-center justify-center rounded-full border border-white/10 bg-white/[0.05] px-4 text-sm font-medium text-text transition-colors hover:bg-white/[0.09] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60 [&::-webkit-details-marker]:hidden">
        <span className="group-open:hidden">Menu</span>
        <span className="hidden group-open:inline">Close</span>
      </summary>
      <nav
        aria-label="Mobile navigation"
        className="absolute right-0 top-[calc(100%+0.75rem)] max-h-[min(72vh,38rem)] w-[min(86vw,21rem)] overflow-y-auto rounded-[24px] border border-white/15 bg-[#07101c] p-2 shadow-[0_24px_80px_rgba(0,0,0,0.7)]"
      >
        <div className="grid gap-1">
          {mobileNavItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-[16px] px-4 py-3 text-sm text-muted transition-colors hover:bg-white/[0.07] hover:text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
            >
              {item.label}
            </Link>
          ))}
          <Link
            href="/trial"
            className="mt-1 rounded-[16px] border border-cyan/25 bg-cyan/10 px-4 py-3 text-sm font-medium text-text transition-colors hover:bg-cyan/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
          >
            Start the 14-day trial
          </Link>
        </div>
      </nav>
    </details>
  );
}
