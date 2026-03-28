import { MotionReveal } from "@/components/ui/motion-reveal";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { styleVariants } from "@/content/home";

export function StylesSection() {
  return (
    <SectionShell
      id="modes"
      eyebrow="Three modes"
      title="Pick the switcher style that matches how you already work."
      description="Every mode solves the same problem: get to the right app or window faster."
    >
      <div className="grid gap-8 xl:grid-cols-3">
        {styleVariants.map((variant, index) => (
          <MotionReveal key={variant.id} delay={index * 90} direction="up">
            <article className="space-y-5">
            <ScreenshotFrame assetId={variant.screenshotId as never} />
            <div className="space-y-3">
              <div className="flex items-center justify-between gap-4">
                <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
                  {variant.name}
                </h3>
                <span className="rounded-full border border-white/10 px-3 py-1 text-[11px] uppercase tracking-[0.18em] text-cyan">
                  Mode
                </span>
              </div>
              <p className="text-base leading-7 text-muted">{variant.summary}</p>
              <p className="text-sm leading-6 text-subdued">{variant.bestFor}</p>
            </div>
            </article>
          </MotionReveal>
        ))}
      </div>
    </SectionShell>
  );
}
