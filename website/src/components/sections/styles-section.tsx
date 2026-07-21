import { MotionReveal } from "@/components/ui/motion-reveal";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { styleVariants } from "@/content/home";

export function StylesSection() {
  return (
    <SectionShell
      id="modes"
      eyebrow="Three modes"
      title="Pick the switcher style that matches your workflow."
      description="Each mode does the same job: getting you to the right app or window quickly."
    >
      <div className="grid gap-8 xl:grid-cols-3">
        {styleVariants.map((variant, index) => (
          <MotionReveal key={variant.id} delay={index * 90} direction="up">
            <article className="surface-panel overflow-hidden">
              <ScreenshotFrame assetId={variant.screenshotId as never} />
              <div className="space-y-3 p-6">
                <p className="type-eyebrow text-cyan">Mode</p>
                <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
                  {variant.name}
                </h3>
                <p className="type-body text-muted">{variant.summary}</p>
                <p className="text-sm leading-6 text-subdued">{variant.bestFor}</p>
              </div>
            </article>
          </MotionReveal>
        ))}
      </div>
    </SectionShell>
  );
}
