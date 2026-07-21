import { MotionReveal } from "@/components/ui/motion-reveal";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { detailBands, featureHighlights } from "@/content/home";

export function FeatureBandsSection() {
  return (
    <SectionShell
      id="details"
      eyebrow="Key features"
      title="Useful features for daily switching."
      description="Keep the same shortcut, but with clearer context."
      className="pt-12"
    >
      <div className="mb-10 grid gap-4 lg:grid-cols-3">
        {featureHighlights.map((item, index) => (
          <MotionReveal
            key={item.title}
            delay={index * 70}
            direction="up"
            className="surface-muted p-5"
          >
            <h3 className="text-lg font-medium tracking-[-0.03em] text-text">{item.title}</h3>
            <p className="mt-2 text-sm leading-7 text-muted">{item.body}</p>
          </MotionReveal>
        ))}
      </div>

      <div className="space-y-20">
        {detailBands.map((band, index) => (
          <MotionReveal
            key={band.id}
            delay={index * 90}
            direction={index % 2 === 0 ? "up" : "scale"}
            className={`grid items-center gap-8 border-t border-white/8 pt-10 lg:grid-cols-2 ${
              index % 2 === 1 ? "lg:[&>*:first-child]:order-2" : ""
            }`}
          >
            <div className="max-w-xl space-y-5">
              <p className="type-eyebrow text-cyan">
                {band.eyebrow}
              </p>
              <h3 className="text-3xl font-medium tracking-[-0.05em] text-text">
                {band.title}
              </h3>
              <p className="type-body text-muted">{band.body}</p>
              {band.points?.length ? (
                <div className="space-y-3 border-t border-white/8 pt-4">
                  {band.points.map((point) => (
                    <div key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                      <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                      <span>{point}</span>
                    </div>
                  ))}
                </div>
              ) : null}
            </div>
            <ScreenshotFrame assetId={band.screenshotId as never} />
          </MotionReveal>
        ))}
      </div>
    </SectionShell>
  );
}
