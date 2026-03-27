import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { walkthroughSteps } from "@/content/home";

export function WalkthroughSection() {
  return (
    <SectionShell
      id="walkthrough"
      eyebrow="See the flow"
      title="A better switcher should explain itself in seconds."
      description="CmdTab keeps the interaction short: invoke it, see what is open, choose the right window, and keep moving."
    >
      <div className="grid gap-10 lg:grid-cols-2">
        {walkthroughSteps.map((step) => (
          <article
            key={step.id}
            className="grid gap-5 border-t border-white/8 pt-6 lg:grid-cols-[92px_minmax(0,1fr)]"
          >
            <div>
              <p className="text-[12px] font-semibold uppercase tracking-[0.28em] text-cyan">
                {step.eyebrow}
              </p>
            </div>
            <div className="space-y-4">
              <div className="space-y-2">
                <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
                  {step.title}
                </h3>
                <p className="max-w-xl text-base leading-7 text-muted">{step.body}</p>
              </div>
              <ScreenshotFrame assetId={step.screenshotId as never} />
            </div>
          </article>
        ))}
      </div>
    </SectionShell>
  );
}

