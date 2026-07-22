import type { CSSProperties } from "react";
import Image from "next/image";

import { ShowcaseVideo } from "@/components/showcase/showcase-video";
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
            href="/trial"
            variant="secondary"
            className="hidden lg:inline-flex"
            {...analyticsAttributes("hero_nav_primary", "header")}
          >
            {siteConfig.ctas.primary}
          </Button>
          <MobileNavigation />
        </header>

        <div className="grid items-center gap-10 py-12 sm:py-16 lg:grid-cols-[minmax(0,0.86fr)_minmax(0,1.14fr)] lg:gap-16 lg:py-20">
          <div
            className="hero-enter max-w-[600px]"
            style={{ "--enter-delay": "150ms" } as CSSProperties}
          >
            <h1 className="max-w-[11ch] text-balance text-[clamp(2.75rem,7vw,5.4rem)] font-medium leading-[0.92] tracking-[-0.065em] text-text">
              {heroContent.title}
            </h1>
            <p className="mt-6 max-w-[34rem] text-pretty text-lg leading-8 text-muted sm:text-xl sm:leading-9">
              CmdTab is a standalone macOS window switcher, separate from Apple’s built-in Command-Tab. See real window previews, search, and quick actions at a glance.
            </p>

            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Button
                href="/trial"
                className="w-full sm:w-auto"
                {...analyticsAttributes("hero_primary_cta", "hero")}
              >
                {siteConfig.ctas.primary}
              </Button>
              <Button
                href="/showcase"
                variant="secondary"
                className="w-full sm:w-auto"
                {...analyticsAttributes("hero_secondary_cta", "hero")}
              >
                Watch CmdTab
              </Button>
            </div>
          </div>

          <div
            className="hero-enter relative ml-auto w-full max-w-[820px]"
            style={{ "--enter-delay": "240ms" } as CSSProperties}
          >
            <ShowcaseVideo asset={overview} priority showCaption={false} />
          </div>
        </div>
      </div>
    </section>
  );
}
