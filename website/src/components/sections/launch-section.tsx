import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { commerceContent } from "@/content/commerce";
import { analyticsAttributes } from "@/lib/analytics";
import { getCommerceConfig } from "@/lib/commerce";

function providerLabel(provider?: string) {
  if (!provider) return null;
  switch (provider) {
    case "lemonsqueezy":
      return "Hosted checkout via Lemon Squeezy";
    case "paddle":
      return "Hosted checkout via Paddle";
    case "stripe":
      return "Hosted checkout via Stripe";
    default:
      return "Hosted checkout provider configured";
  }
}

export function LaunchSection() {
  const commerce = getCommerceConfig();
  const providerNote = providerLabel(commerce.checkoutProvider);
  const checkoutReady = Boolean(commerce.checkoutUrl);
  const trialReady = Boolean(commerce.trialDownloadUrl);
  const statusNote = checkoutReady && !trialReady
    ? "Founder checkout is live. The trial button will activate after the notarized trial build is published."
    : checkoutReady || trialReady
      ? "Launch section is configured from environment variables, and the site shows your hosted checkout plus trial links."
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
              {commerceContent.founder.title}
            </p>
            <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
              {commerceContent.founder.price}
            </p>
            <p className="mt-3 text-sm leading-6 text-muted">{commerceContent.founder.note}</p>
            <div className="mt-6 space-y-3">
              {commerceContent.founder.points.map((point) => (
                <div key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                  <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                  <span>{point}</span>
                </div>
              ))}
            </div>
            <div className="mt-8">
              {commerce.checkoutUrl ? (
                <Button
                  href={commerce.checkoutUrl}
                  target="_blank"
                  rel="noreferrer"
                  {...analyticsAttributes("launch_checkout_click", "launch")}
                >
                  {commerceContent.founder.cta}
                </Button>
              ) : (
                <Button
                  href="#top"
                  variant="secondary"
                  {...analyticsAttributes("launch_checkout_fallback", "launch")}
                >
                  Buy link coming soon
                </Button>
              )}
            </div>
          </article>

          <article className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl">
            <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              {commerceContent.standard.title}
            </p>
            <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
              {commerceContent.standard.price}
            </p>
            <p className="mt-3 text-sm leading-6 text-muted">{commerceContent.standard.note}</p>
            <div className="mt-6 space-y-3">
              {commerceContent.standard.points.map((point) => (
                <div key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                  <span className="mt-2 h-2 w-2 rounded-full bg-success" />
                  <span>{point}</span>
                </div>
              ))}
            </div>
            <div className="mt-8">
              {commerce.trialDownloadUrl ? (
                <Button
                  href={commerce.trialDownloadUrl}
                  variant="secondary"
                  target="_blank"
                  rel="noreferrer"
                  {...analyticsAttributes("launch_trial_click", "launch")}
                >
                  {commerceContent.standard.cta}
                </Button>
              ) : (
                <Button
                  href="#launch"
                  variant="secondary"
                  {...analyticsAttributes("launch_trial_fallback", "launch")}
                >
                  Trial build coming soon
                </Button>
              )}
            </div>
          </article>
        </MotionReveal>

        <MotionReveal direction="right" delay={120} className="space-y-5 rounded-[28px] border border-white/10 bg-white/[0.03] p-6 shadow-panel backdrop-blur-xl">
          <div className="space-y-3">
            <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              Checkout integration
            </p>
            <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
              Hosted checkout is wired and ready for your provider URLs.
            </h3>
            <p className="text-base leading-7 text-muted">
              The site shows a provider checkout flow and a separate trial link. Add your hosted URLs in env when they are ready.
            </p>
          </div>

          <div className="space-y-3 border-t border-white/8 pt-5">
            <div className="flex items-start gap-3 text-sm leading-6 text-subdued">
              <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
              <span>
                {providerNote ??
                  "Use Lemon Squeezy, Paddle, Stripe, or your own hosted checkout and set a public checkout URL."}
              </span>
            </div>
            <div className="flex items-start gap-3 text-sm leading-6 text-subdued">
              <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
              <span>
                Add a separate trial URL so visitors can test first.
              </span>
            </div>
            <div className="flex items-start gap-3 text-sm leading-6 text-subdued">
              <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
              <span>
                If a URL is missing, the section shows a neutral fallback instead of a dead button.
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
