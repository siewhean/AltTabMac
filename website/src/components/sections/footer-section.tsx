import Image from "next/image";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { siteConfig } from "@/content/site";

const productLinks = [
  { href: "/features/window-switcher", label: "Window switcher" },
  { href: "/evidence", label: "Testing and evidence" },
  { href: "/guides/switch-between-windows-on-mac", label: "Mac window guide" },
  { href: "/compare/mac-window-switchers", label: "Switcher landscape" },
  { href: "/compare/cmdtab-vs-macos-command-tab", label: "CmdTab vs macOS" },
  { href: "/compatibility", label: "Compatibility" },
  { href: "/permissions", label: "Permissions" },
  { href: "/faq", label: "FAQ" },
] as const;

const companyLinks = [
  { href: "/about", label: "About" },
  { href: "/changelog", label: "Changelog" },
  { href: "/help", label: "Help" },
  { href: "/privacy", label: "Privacy" },
  { href: "/security", label: "Security" },
] as const;

export function FooterSection() {
  return (
    <footer className="border-t border-white/8 px-5 py-10 sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-[1200px] gap-10 lg:grid-cols-[minmax(0,1.25fr)_minmax(180px,0.75fr)_minmax(160px,0.65fr)]">
        <MotionReveal className="space-y-4" direction="left">
          <div className="flex items-center gap-3">
            <Image
              src="/brand/cmdtab.png"
              alt="CmdTab app icon"
              width={40}
              height={40}
              className="rounded-[12px]"
            />
            <div>
              <p className="text-lg font-medium tracking-[-0.03em] text-text">CmdTab</p>
              <p className="text-sm text-subdued">Individual window switching for macOS.</p>
            </div>
          </div>
          <p className="max-w-xl text-sm leading-7 text-subdued">
            CmdTab shows eligible Mac windows as separate recent-use targets with previews, search, quick actions, and configurable Space and display scope.
          </p>
          <div className="flex flex-col gap-3 pt-2 sm:flex-row">
            <Button href="/trial">{siteConfig.ctas.primary}</Button>
            <Button href="/buy" variant="secondary">
              Review pricing
            </Button>
          </div>
        </MotionReveal>

        <MotionReveal direction="up" delay={80}>
          <p className="type-eyebrow text-cyan">Product</p>
          <nav aria-label="Product information" className="mt-4 flex flex-col gap-3 text-sm text-subdued">
            {productLinks.map((item) => (
              <Link key={item.href} className="hover:text-text" href={item.href}>
                {item.label}
              </Link>
            ))}
          </nav>
        </MotionReveal>

        <MotionReveal direction="right" delay={120}>
          <p className="type-eyebrow text-cyan">Company and support</p>
          <nav aria-label="Company and support" className="mt-4 flex flex-col gap-3 text-sm text-subdued">
            {companyLinks.map((item) => (
              <Link key={item.href} className="hover:text-text" href={item.href}>
                {item.label}
              </Link>
            ))}
          </nav>
        </MotionReveal>
      </div>
    </footer>
  );
}
