import Link from "next/link";

const mobileNavItems = [
  { href: "/features/window-switcher", label: "Features" },
  { href: "/showcase", label: "Showcase" },
  { href: "/compare/mac-window-switchers", label: "Compare" },
  { href: "/evidence", label: "Evidence" },
  { href: "/faq", label: "FAQ" },
  { href: "/help", label: "Help" },
  { href: "/waitlist", label: "Waitlist" },
] as const;

export function MobileNavigation() {
  return (
    <details className="group relative z-50 lg:hidden">
      <summary className="inline-flex min-h-12 min-w-12 cursor-pointer list-none items-center justify-center rounded-full border border-white/10 bg-white/[0.05] px-4 text-sm font-medium text-text transition-colors hover:bg-white/[0.09] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60 [&::-webkit-details-marker]:hidden">
        <span className="group-open:hidden">Menu</span>
        <span className="hidden group-open:inline">Close</span>
      </summary>
      <nav
        aria-label="Mobile navigation"
        className="absolute right-0 top-[calc(100%+0.75rem)] max-h-[min(70vh,32rem)] w-[min(88vw,21rem)] overflow-y-auto rounded-[24px] border border-white/15 bg-[#07101c] p-2 shadow-[0_24px_80px_rgba(0,0,0,0.7)]"
      >
        <div className="grid gap-1">
          {mobileNavItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex min-h-12 items-center rounded-[16px] px-4 text-sm text-muted transition-colors hover:bg-white/[0.07] hover:text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
            >
              {item.label}
            </Link>
          ))}
          <Link
            href="/waitlist"
            className="mt-1 flex min-h-12 items-center justify-center rounded-[16px] border border-cyan/25 bg-cyan/10 px-4 text-sm font-medium text-text transition-colors hover:bg-cyan/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
          >
            Join the waitlist
          </Link>
        </div>
      </nav>
    </details>
  );
}
