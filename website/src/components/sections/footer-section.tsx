import Image from "next/image";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { siteConfig } from "@/content/site";

const productLinks = [
  { href: "/features/window-switcher", label: "Window switcher" },
  { href: "/showcase", label: "Showcase" },
  { href: "/compare/mac-window-switchers", label: "Compare" },
  { href: "/compatibility", label: "Compatibility" },
  { href: "/permissions", label: "Permissions" },
  { href: "/faq", label: "FAQ" },
  { href: "/buy", label: "Buy" },
] as const;

const companyLinks = [
  { href: "/about", label: "About" },
  { href: "/changelog", label: "Changelog" },
  { href: "/help", label: "Help" },
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "/security", label: "Security" },
] as const;

function FooterLinks({
  label,
  links,
}: {
  label: string;
  links: ReadonlyArray<{ href: string; label: string }>;
}) {
  return (
    <nav aria-label={label} className="mt-3 flex flex-col text-sm text-subdued">
      {links.map((item) => (
        <Link key={item.href} className="flex min-h-11 items-center hover:text-text" href={item.href}>
          {item.label}
        </Link>
      ))}
    </nav>
  );
}

export function FooterSection() {
  return (
    <footer className="border-t border-white/8 px-5 py-8 sm:px-8 sm:py-10 lg:px-10">
      <div className="mx-auto grid max-w-[1200px] gap-8 lg:grid-cols-[minmax(0,1.25fr)_minmax(180px,0.75fr)_minmax(160px,0.65fr)] lg:gap-10">
        <MotionReveal className="space-y-4" direction="left">
          <div className="flex items-center gap-3">
            <Image
              src="/brand/cmdtab.png"
              alt="CmdTab app icon"
              width={40}
              height={40}
              loading="eager"
              className="rounded-[12px]"
            />
            <div>
              <p className="text-lg font-medium tracking-[-0.03em] text-text">CmdTab</p>
              <p className="text-sm text-subdued">Switch between individual Mac windows.</p>
            </div>
          </div>
          <p className="max-w-xl text-sm leading-6 text-subdued">
            Previews, search, quick actions, and exact-window recency in one native macOS switcher.
          </p>
          <div className="flex w-full flex-col gap-3 pt-1 sm:w-auto sm:flex-row">
            <Button href="/trial" className="w-full sm:w-auto">
              {siteConfig.ctas.primary}
            </Button>
            <Button href="/showcase" variant="secondary" className="w-full sm:w-auto">
              Watch CmdTab
            </Button>
          </div>
        </MotionReveal>

        <div className="grid gap-2 lg:hidden">
          <details className="rounded-[18px] border border-white/8 bg-white/[0.025] px-4">
            <summary className="flex min-h-12 cursor-pointer list-none items-center justify-between text-sm font-medium text-text [&::-webkit-details-marker]:hidden">
              Product
              <span aria-hidden="true" className="text-cyan">+</span>
            </summary>
            <FooterLinks label="Product information" links={productLinks} />
          </details>
          <details className="rounded-[18px] border border-white/8 bg-white/[0.025] px-4">
            <summary className="flex min-h-12 cursor-pointer list-none items-center justify-between text-sm font-medium text-text [&::-webkit-details-marker]:hidden">
              Company and support
              <span aria-hidden="true" className="text-cyan">+</span>
            </summary>
            <FooterLinks label="Company and support" links={companyLinks} />
          </details>
        </div>

        <MotionReveal direction="up" delay={80} className="hidden lg:block">
          <p className="type-eyebrow text-cyan">Product</p>
          <FooterLinks label="Product information" links={productLinks} />
        </MotionReveal>

        <MotionReveal direction="right" delay={120} className="hidden lg:block">
          <p className="type-eyebrow text-cyan">Company and support</p>
          <FooterLinks label="Company and support" links={companyLinks} />
        </MotionReveal>
      </div>
    </footer>
  );
}
