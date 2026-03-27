import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { styleVariants } from "@/content/home";

export function StylesSection() {
  return (
    <SectionShell
      id="modes"
      eyebrow="Three ways to switch"
      title="CmdTab is one product with three distinct visual modes."
      description="Instead of forcing everyone into one mental model, CmdTab lets you choose the interaction style that feels most natural."
    >
      <div className="grid gap-8 xl:grid-cols-3">
        {styleVariants.map((variant) => (
          <article key={variant.id} className="space-y-5">
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
        ))}
      </div>
    </SectionShell>
  );
}

