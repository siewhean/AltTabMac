import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { featureHighlights } from "@/content/home";

export function FeatureBandsSection() {
  return (
    <SectionShell
      id="details"
      title="Built for busy desktops."
      description="Fast switching, cleaner lists, and display-aware placement."
      className="pt-8"
    >
      <div
        role="region"
        aria-label="CmdTab feature highlights"
        tabIndex={0}
        className="-mx-5 flex snap-x snap-mandatory gap-4 overflow-x-auto px-5 pb-3 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-cyan/60 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:-mx-8 sm:px-8 lg:mx-0 lg:grid lg:grid-cols-3 lg:overflow-visible lg:px-0 lg:pb-0"
      >
        {featureHighlights.map((item, index) => (
          <MotionReveal
            key={item.title}
            delay={index * 60}
            direction="up"
            className="surface-muted min-w-[82vw] snap-center p-5 sm:min-w-[52vw] sm:p-6 lg:min-w-0"
          >
            <h2 className="text-xl font-medium tracking-[-0.03em] text-text">{item.title}</h2>
            <p className="mt-3 text-sm leading-6 text-muted">{item.body}</p>
          </MotionReveal>
        ))}
      </div>

      <div className="mt-8 flex flex-col gap-5 border-t border-white/8 pt-8 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Be first to try CmdTab.</h2>
          <p className="mt-2 text-sm leading-6 text-muted">It’s in private preview. Join the waitlist for an email when trial access is ready.</p>
        </div>
        <div className="flex w-full flex-col gap-3 sm:w-auto sm:flex-row">
          <Button href="/trial" className="w-full sm:w-auto">
            Join the waitlist
          </Button>
          <Button href="/features/window-switcher" variant="secondary" className="w-full sm:w-auto">
            See all features
          </Button>
        </div>
      </div>
    </SectionShell>
  );
}
