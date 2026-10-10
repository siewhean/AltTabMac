import Image from "next/image";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { MobileNavigation } from "@/components/ui/mobile-navigation";

const marketingNav = [
  { href: "/features/window-switcher", label: "Features" },
  { href: "/showcase", label: "Showcase" },
  { href: "/evidence", label: "Evidence" },
  { href: "/guides/switch-between-windows-on-mac", label: "Guide" },
  { href: "/compare/mac-window-switchers", label: "Compare" },
] as const;

export function SiteHeader() {
  return (
    <header className="relative z-40 mx-auto flex max-w-[1200px] items-center justify-between gap-4 px-5 pt-5 sm:px-8 lg:gap-6 lg:px-10">
      <Link
        href="/"
        aria-label="CmdTab homepage"
        className="inline-flex min-w-0 items-center gap-3 rounded-full border border-white/10 bg-white/[0.05] px-4 py-3 backdrop-blur-xl"
      >
        <Image
          src="/brand/cmdtab.png"
          alt="CmdTab app icon"
          width={40}
          height={40}
          className="shrink-0 rounded-[12px]"
          priority
        />
        <div className="min-w-0">
          <p className="truncate text-sm font-semibold tracking-[-0.03em] text-text">CmdTab</p>
          <p className="truncate text-xs text-subdued">macOS window switching</p>
        </div>
      </Link>

      <nav aria-label="Primary navigation" className="hidden items-center gap-5 text-sm text-muted lg:flex">
        {marketingNav.map((item) => (
          <Link key={item.href} href={item.href} className="transition-colors duration-200 hover:text-text">
            {item.label}
          </Link>
        ))}
      </nav>

      <Button href="/waitlist" variant="secondary" className="max-lg:hidden">
        Join the private beta
      </Button>
      <MobileNavigation />
    </header>
  );
}
