import type { CSSProperties } from "react";
import Image from "next/image";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { heroContent } from "@/content/home";
import { siteConfig } from "@/content/site";
import { analyticsAttributes } from "@/lib/analytics";

export function HeroSection() {
  const primaryHref = "/trial";

  return (
    <section className="relative isolate min-h-[100svh] overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(105,214,255,0.08),transparent_24%),linear-gradient(180deg,#05070C_0%,#08111D_52%,#060913_100%)]" />

      <div className="relative mx-auto flex min-h-[100svh] max-w-[1380px] flex-col px-5 pb-12 pt-5 sm:px-8 lg:px-10">
        <header
          className="hero-enter flex items-center justify-between gap-6 rounded-full border border-white/10 bg-white/[0.05] px-4 py-3 backdrop-blur-xl"
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
              <p className="text-xs text-subdued">macOS window switching</p>
            </div>
          </a>

          <nav aria-label="Primary navigation" className="hidden items-center gap-6 text-sm text-muted lg:flex">
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
            <p className="mt-8 text-[clamp(2.6rem,7vw,5.6rem)] font-medium leading-[0.9] tracking-[-0.07em] text-text">
              CmdTab
            </p>
            <h1 className="mt-5 max-w-[12ch] text-balance text-[clamp(2.25rem,5vw,4.6rem)] font-medium leading-[0.95] tracking-[-0.06em] text-text">
              {heroContent.title}
            </h1>
            <p className="mt-6 max-w-[38rem] text-pretty text-base font-medium leading-7 text-text sm:text-lg">
              CmdTab is a native macOS window switcher that replaces an app-only view with individual window previews, global recent-use ordering, search, and quick actions.
            </p>
            <p className="type-body-lg mt-4 max-w-[34rem] text-pretty text-muted sm:text-[1.125rem]">
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
            <div className="space-y-4">
              <ScreenshotFrame assetId="heroMaster" className="relative z-10" priority />
              <div className="grid gap-4 md:grid-cols-2">
                <div className="surface-muted p-5">
                  <p className="type-eyebrow text-cyan">Visual switching</p>
                  <h2 className="mt-3 text-lg font-medium tracking-[-0.03em] text-text">
                    Real previews before you commit
                  </h2>
                  <p className="mt-2 text-sm leading-7 text-muted">
                    Scan the actual window, not just the app icon.
                  </p>
                </div>
                <div className="surface-muted p-5">
                  <p className="type-eyebrow text-cyan">Fast fallback</p>
                  <h2 className="mt-3 text-lg font-medium tracking-[-0.03em] text-text">
                    Search or hot swap when you already know
                  </h2>
                  <p className="mt-2 text-sm leading-7 text-muted">
                    Jump directly without opening the wrong thing first.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
