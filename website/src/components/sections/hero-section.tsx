import type { CSSProperties } from "react";
import Image from "next/image";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { heroContent } from "@/content/home";
import { siteConfig } from "@/content/site";
import { analyticsAttributes } from "@/lib/analytics";

export function HeroSection() {
  const primaryHref = "#waitlist";

  return (
    <section className="relative isolate min-h-[100svh] overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(105,214,255,0.14),transparent_30%),radial-gradient(circle_at_left,rgba(78,161,255,0.18),transparent_32%),linear-gradient(180deg,#05070C_0%,#08101C_44%,#05070C_100%)]" />
      <div className="motion-grid-drift absolute inset-0 bg-grid-fade bg-[size:120px_120px] opacity-[0.08]" />

      <div className="relative mx-auto flex min-h-[100svh] max-w-[1380px] flex-col px-5 pb-12 pt-5 sm:px-8 lg:px-10">
        <header
          className="hero-enter flex items-center justify-between gap-6 rounded-full border border-white/10 bg-white/[0.04] px-4 py-3 backdrop-blur-xl"
          style={{ "--enter-delay": "60ms" } as CSSProperties}
        >
          <a className="inline-flex items-center gap-3" href="/">
            <Image
              src="/brand/cmdtab.png"
              alt="CmdTab app icon"
              width={40}
              height={40}
              className="rounded-[12px]"
              priority
            />
            <div>
              <p className="text-sm font-semibold tracking-[-0.03em] text-text">CmdTab</p>
              <p className="text-xs text-subdued">macOS private beta waitlist</p>
            </div>
          </a>

          <nav className="hidden items-center gap-6 text-sm text-muted lg:flex">
            {siteConfig.nav.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="transition-colors duration-200 hover:text-text"
              >
                {item.label}
              </a>
            ))}
          </nav>

          <Button
            href={primaryHref}
            variant="secondary"
            className="hidden lg:inline-flex"
            {...analyticsAttributes("hero_nav_primary", "header")}
          >
            {siteConfig.ctas.primary}
          </Button>
        </header>

        <div className="grid flex-1 items-center gap-14 py-14 lg:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)] lg:py-20">
          <div
            className="hero-enter max-w-[560px]"
            style={{ "--enter-delay": "150ms" } as CSSProperties}
          >
            <Badge tone="success">{heroContent.eyebrow}</Badge>
            <p className="mt-8 text-[clamp(2.75rem,7vw,5.8rem)] font-medium leading-[0.9] tracking-[-0.07em] text-text">
              CmdTab
            </p>
            <h1 className="mt-5 max-w-[12ch] text-balance text-[clamp(2.4rem,5vw,4.9rem)] font-medium leading-[0.95] tracking-[-0.06em] text-text">
              {heroContent.title}
            </h1>
            <p className="mt-6 max-w-[34rem] text-pretty text-lg leading-8 text-muted sm:text-xl">
              {heroContent.summary}
            </p>
            <p className="mt-4 max-w-[34rem] text-sm leading-6 text-subdued">{heroContent.status}</p>

            <div className="mt-10 flex flex-col gap-3 sm:flex-row">
              <Button
                href={primaryHref}
                {...analyticsAttributes("hero_primary_cta", "hero")}
              >
                {siteConfig.ctas.primary}
              </Button>
              <Button
                href="#walkthrough"
                variant="secondary"
                {...analyticsAttributes("hero_secondary_cta", "hero")}
              >
                {siteConfig.ctas.secondary}
              </Button>
            </div>
          </div>

          <div
            className="hero-enter relative ml-auto w-full max-w-[820px]"
            style={{ "--enter-delay": "240ms" } as CSSProperties}
          >
            <ScreenshotFrame assetId="heroMaster" className="relative z-10 motion-drift-subtle" priority />
            <div className="pointer-events-none absolute -left-6 top-[12%] hidden w-[32%] lg:block">
              <ScreenshotFrame assetId="commandPalette" className="motion-drift-slow rotate-[-4deg]" />
            </div>
            <div className="pointer-events-none absolute -bottom-8 right-[-4%] hidden w-[34%] lg:block">
              <ScreenshotFrame assetId="radialMenu" className="motion-drift-reverse rotate-[5deg]" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
