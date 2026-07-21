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
      eyebrow="Three modes"
      title="Pick the switcher style that matches how you already work."
      description="Every mode uses the same eligible-window set and exact-window recent-use sequence, then changes how you identify and select the target."
    >
      <div className="grid gap-8 xl:grid-cols-3">
        {styleVariants.map((variant, index) => (
          <MotionReveal key={variant.id} delay={index * 90} direction="up">
            <article className="surface-panel h-full overflow-hidden">
              <ScreenshotFrame assetId={variant.screenshotId as never} />
              <div className="space-y-3 p-6">
                <p className="type-eyebrow text-cyan">Mode</p>
                <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
                  {variant.name}
                </h3>
                <p className="type-body text-muted">{variant.summary}</p>
                <p className="text-sm leading-6 text-subdued">{variant.bestFor}</p>
                <Link
                  href={modeLinks[variant.id]}
                  className="inline-flex pt-2 text-sm font-medium text-cyan hover:text-text"
                >
                  Review current behavior →
                </Link>
              </div>
            </article>
          </MotionReveal>
        ))}
      </div>
    </SectionShell>
  );
}
