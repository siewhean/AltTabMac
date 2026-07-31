import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { commerceContent } from "@/content/commerce";
import { analyticsAttributes } from "@/lib/analytics";
import { getBetaReleaseManifest } from "@/lib/stable-release";

export function LaunchSection() {
  const release = getBetaReleaseManifest();
  const trialReady = Boolean(release);
  const statusNote = trialReady
    ? "A signed CmdTab public beta is available. Stable releases and all payment paths remain unavailable."
    : commerceContent.fallback;

  return (
    <SectionShell
      id="launch"
      eyebrow={commerceContent.eyebrow}
      title={commerceContent.title}
      description={commerceContent.summary}
    >
      <div className="grid gap-8 xl:grid-cols-[minmax(0,1.05fr)_minmax(0,0.95fr)]">
        <MotionReveal direction="left" className="grid gap-6 md:grid-cols-2">
          <article className="rounded-[28px] border border-cyan/20 bg-cyan/[0.07] p-6 shadow-panel">
            <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              {commerceContent.license.title}
            </p>
            <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
              {commerceContent.license.price}
            </p>
            <p className="mt-3 text-sm leading-6 text-muted">{commerceContent.license.note}</p>
            <div className="mt-6 space-y-3">
              {commerceContent.license.points.map((point) => (
                <div key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                  <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                  <span>{point}</span>
                </div>
              ))}
            </div>
            <div className="mt-8">
              <Button href="/buy" variant="secondary">Pricing plan</Button>
            </div>
          </article>

          <article className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl">
            <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              {commerceContent.trial.title}
            </p>
            <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
              {commerceContent.trialLength}
            </p>
            <p className="mt-3 text-sm leading-6 text-muted">{commerceContent.trial.note}</p>
            <div className="mt-6 space-y-3">
              {commerceContent.trial.points.map((point) => (
                <div key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                  <span className="mt-2 h-2 w-2 rounded-full bg-success" />
                  <span>{point}</span>
                </div>
              ))}
            </div>
            <div className="mt-8">
              {release ? (
                <Button
                  href={release.dmgURL}
                  variant="secondary"
                  target="_blank"
                  rel="noreferrer"
                  {...analyticsAttributes("launch_trial_click", "launch")}
                >
                  Download beta
                </Button>
              ) : (
                <Button
                  href="/trial"
                  variant="secondary"
                  {...analyticsAttributes("launch_trial_fallback", "launch")}
                >
                  Trial details
                </Button>
              )}
            </div>
          </article>
        </MotionReveal>

        <MotionReveal direction="right" delay={120} className="space-y-5 rounded-[28px] border border-white/10 bg-white/[0.03] p-6 shadow-panel backdrop-blur-xl">
          <div className="space-y-3">
            <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              Beta release boundary
            </p>
            <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
              No purchase during public beta.
            </h3>
            <p className="text-base leading-7 text-muted">
              CmdTab’s US$12 personal licence is planned for general availability. The public beta
              has no checkout, payment CTA, or structured offer.
            </p>
          </div>

          <div className="space-y-3 border-t border-white/8 pt-5">
            <div className="flex items-start gap-3 text-sm leading-6 text-subdued">
              <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
              <span>
                The beta is distributed only through a signed, immutable beta release manifest.
              </span>
            </div>
            <div className="flex items-start gap-3 text-sm leading-6 text-subdued">
              <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
              <span>
                The stable download and stable appcast return unavailable until general availability.
              </span>
            </div>
            <div className="flex items-start gap-3 text-sm leading-6 text-subdued">
              <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
              <span>
                Payment, fulfilment, and outbox processing remain disabled while commerce is not ready.
              </span>
            </div>
          </div>

          <p className="rounded-[22px] border border-dashed border-white/10 bg-white/[0.03] px-4 py-4 text-sm leading-6 text-muted">
            {statusNote}
          </p>
        </MotionReveal>
      </div>
    </SectionShell>
  );
}
