import type { CSSProperties } from "react";
import Image from "next/image";

import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { WaitlistForm } from "@/components/sections/waitlist-form";
import { Button } from "@/components/ui/button";
import { MobileNavigation } from "@/components/ui/mobile-navigation";
import { heroContent } from "@/content/home";
import { showcaseAsset } from "@/content/showcase";
import { siteConfig } from "@/content/site";
import { analyticsAttributes } from "@/lib/analytics";

export function HeroSection() {
  const overview = showcaseAsset("overview");

  return (
    <section className="relative isolate overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(105,214,255,0.08),transparent_24%),linear-gradient(180deg,#05070C_0%,#08111D_52%,#060913_100%)]" />

      <div className="relative mx-auto max-w-[1380px] px-5 pb-10 pt-5 sm:px-8 lg:px-10">
        <header
          className="hero-enter relative z-40 flex items-center justify-between gap-4 rounded-full border border-white/10 bg-white/[0.05] px-4 py-3 backdrop-blur-xl lg:gap-6"
          style={{ "--enter-delay": "60ms" } as CSSProperties}
        >
          <a aria-label="CmdTab homepage" className="inline-flex min-h-12 min-w-12 items-center gap-3" href="/">
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
          </a>

          <nav aria-label="Primary navigation" className="hidden items-center gap-2 text-sm text-muted lg:flex">
            {siteConfig.nav.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full px-3 transition-colors duration-200 hover:bg-white/[0.05] hover:text-text"
              >
                {item.label}
              </a>
            ))}
          </nav>

          <Button
            href="#join"
            variant="secondary"
            className="hidden lg:inline-flex"
            {...analyticsAttributes("hero_nav_primary", "header")}
          >
            {siteConfig.ctas.primary}
          </Button>
          <MobileNavigation />
        </header>

        <div className="grid items-center gap-8 py-8 sm:gap-10 sm:py-16 lg:grid-cols-[minmax(0,0.86fr)_minmax(0,1.14fr)] lg:gap-16 lg:py-20">
          <div
            className="hero-enter max-w-[600px]"
            style={{ "--enter-delay": "150ms" } as CSSProperties}
          >
            <p className="mb-5 inline-flex items-center rounded-full border border-cyan/30 bg-cyan/[0.08] px-4 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
              {heroContent.eyebrow}
            </p>
            <h1 className="max-w-[15ch] text-balance text-[clamp(2.1rem,5.6vw,4.6rem)] font-medium leading-[0.98] tracking-[-0.06em] text-text">
              {heroContent.title}
            </h1>
            <p className="mt-5 max-w-[34rem] text-pretty text-base leading-7 text-muted sm:mt-6 sm:text-xl sm:leading-9">
              CmdTab is a standalone native macOS window-switcher app, separate from Apple’s built-in Command-Tab shortcut. Every window gets its own preview, so you can search for it, jump to it, or close it without guessing.
            </p>

            <div id="join" className="mt-8 scroll-mt-24">
              <WaitlistForm source="homepage_hero" variant="hero" />
              <a
                href="#demo"
                className="mt-3 inline-flex min-h-11 items-center text-sm font-medium text-cyan underline decoration-cyan/40 underline-offset-4 hover:decoration-cyan focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60"
                {...analyticsAttributes("hero_secondary_cta", "hero")}
              >
                {heroContent.secondaryCta} →
              </a>
            </div>
          </div>

          <div
            className="hero-enter relative ml-auto w-full max-w-[820px]"
            style={{ "--enter-delay": "240ms" } as CSSProperties}
          >
            <ShowcaseVideo
              asset={overview}
              priority
              showCaption={false}
              showOverlay={false}
              loopPlayback
            />
          </div>
        </div>
      </div>
    </section>
  );
}
