import { MotionReveal } from "@/components/ui/motion-reveal";
import { commercePageContent } from "@/content/commerce-pages";

export function HelpJourney() {
  return (
    <div className="surface-panel p-6">
      <p className="type-eyebrow text-cyan">Step by step</p>
      <div className="relative mt-6 flex flex-col gap-4">
        <div className="absolute left-[17px] top-3 bottom-3 w-px bg-white/10" />
        {commercePageContent.help.journey.map((step, index) => (
          <MotionReveal
            key={step.title}
            direction="up"
            delay={index * 80}
            className="relative grid grid-cols-[36px_minmax(0,1fr)] gap-4"
          >
            <div className="relative z-10 flex h-9 w-9 items-center justify-center rounded-full border border-cyan/30 bg-[#0B1422] text-sm font-semibold text-cyan">
              {index + 1}
            </div>
            <div className="surface-muted p-4">
              <h2 className="text-base font-medium tracking-[-0.02em] text-text">
                {step.title}
              </h2>
              <p className="mt-2 text-sm leading-7 text-muted">{step.body}</p>
            </div>
          </MotionReveal>
        ))}
      </div>
    </div>
  );
}
