import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { detailBands } from "@/content/home";

export function FeatureBandsSection() {
  return (
    <SectionShell
      id="details"
      eyebrow="Why it feels better"
      title="The details that stay invisible are the ones that make the switcher feel right."
      description="CmdTab is designed to help you land on the right window without second-guessing the interface."
      className="pt-12"
    >
      <div className="space-y-20">
        {detailBands.map((band, index) => (
          <article
            key={band.id}
            className={`grid items-center gap-8 border-t border-white/8 pt-10 lg:grid-cols-2 ${
              index % 2 === 1 ? "lg:[&>*:first-child]:order-2" : ""
            }`}
          >
            <div className="max-w-xl space-y-5">
              <p className="text-[11px] font-semibold uppercase tracking-[0.24em] text-cyan">
                {band.eyebrow}
              </p>
              <h3 className="text-3xl font-medium tracking-[-0.05em] text-text">
                {band.title}
              </h3>
              <p className="text-base leading-8 text-muted">{band.body}</p>
            </div>
            <ScreenshotFrame assetId={band.screenshotId as never} />
          </article>
        ))}
      </div>
    </SectionShell>
  );
}

