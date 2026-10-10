import Link from "next/link";

import { MotionReveal } from "@/components/ui/motion-reveal";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { styleVariants } from "@/content/home";

const modeLinks: Record<string, string> = {
  classicGrid: "/features/classic-grid",
  commandPalette: "/features/command-palette",
  radialMenu: "/features/radial-menu",
};

export function StylesSection() {
  return (
    <SectionShell
      id="modes"
      title="Three ways to switch."
      description="Scan with thumbnails, search by name, or move by position."
    >
      <div
        role="region"
        aria-label="CmdTab switcher modes"
        tabIndex={0}
        className="-mx-5 flex snap-x snap-mandatory gap-4 overflow-x-auto px-5 pb-3 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-cyan/60 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:-mx-8 sm:px-8 lg:mx-0 lg:grid lg:grid-cols-3 lg:overflow-visible lg:px-0 lg:pb-0"
      >
        {styleVariants.map((variant, index) => (
          <MotionReveal
            key={variant.id}
            delay={index * 70}
            direction="up"
            className="min-w-[84vw] snap-center sm:min-w-[58vw] lg:min-w-0"
          >
            <Link
              href={modeLinks[variant.id]}
              className="surface-panel group block h-full overflow-hidden focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-cyan/70"
            >
              <ScreenshotFrame assetId={variant.screenshotId as never} showCaption={false} />
              <div className="p-5 sm:p-6">
                <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">{variant.name}</h2>
                <p className="mt-3 text-sm leading-6 text-muted">{variant.summary}</p>
                <span className="mt-5 inline-flex min-h-11 items-center text-sm font-medium text-cyan transition-colors group-hover:text-text">
                  Explore mode →
                </span>
              </div>
            </Link>
          </MotionReveal>
        ))}
      </div>
    </SectionShell>
  );
}
