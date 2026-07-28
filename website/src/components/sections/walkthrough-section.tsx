import { MotionReveal } from "@/components/ui/motion-reveal";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { SwitcherLiveDemo } from "@/components/ui/switcher-live-demo";
import { walkthroughSteps } from "@/content/home";

export function WalkthroughSection() {
  return (
    <SectionShell
      id="walkthrough"
      eyebrow="Live walkthroughs"
      title="Learn CmdTab in four practical steps."
      description="Each mode solves a different switching moment. Try one step at a time, in this order, to get the first week of use right."
    >
      <div className="space-y-12">
        <div className="grid gap-6 lg:grid-cols-2">
          {walkthroughSteps.map((step, index) => (
            <MotionReveal
              key={step.id}
              delay={index * 80}
              direction={index % 2 === 0 ? "left" : "right"}
              className="h-full"
            >
              <article className="surface-panel h-full p-6 transition-transform duration-300 ease-[cubic-bezier(0.23,1,0.32,1)] hover:-translate-y-0.5">
                <div className="space-y-4">
                  <div className="flex items-start gap-4">
                    <p className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-cyan/30 bg-cyan/10 text-xs font-semibold tracking-[0.16em] text-cyan">
                      {String(index + 1).padStart(2, "0")}
                    </p>
                    <div className="space-y-2">
                      <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                        {step.eyebrow}
                      </p>
                      <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
                        {step.title}
                      </h3>
                    </div>
                  </div>
                  <p className="max-w-xl text-base leading-7 text-muted">
                    {step.body}
                  </p>
                </div>
                <ScreenshotFrame assetId={step.screenshotId as never} />
              </article>
            </MotionReveal>
          ))}
        </div>

        <MotionReveal direction="up" delay={140}>
          <SwitcherLiveDemo />
        </MotionReveal>
      </div>
    </SectionShell>
  );
}
