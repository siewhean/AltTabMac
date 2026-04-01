import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
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
      return "Hosted checkout configured";
  }
}

type CommerceOfferGridProps = {
  context: string;
};

export function CommerceOfferGrid({ context }: CommerceOfferGridProps) {
  const commerce = getCommerceConfig();
  const providerNote = providerLabel(commerce.checkoutProvider);

  return (
    <div className="space-y-6">
      <MotionReveal direction="left" className="grid gap-6 md:grid-cols-3">
        <article className="surface-panel flex h-full flex-col p-6">
          <p className="type-eyebrow text-cyan">Trial</p>
          <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
            {commerceContent.trialLength}
          </p>
          <p className="mt-3 text-sm leading-6 text-muted">
            Use the full app in real work before you decide.
          </p>
          <ul className="mt-6 grow space-y-3">
            {commerceContent.standard.points.map((point) => (
              <li key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                <span className="mt-2 h-2 w-2 rounded-full bg-success" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
          <div className="mt-8">
            {commerce.trialDownloadUrl ? (
              <Button
                href={commerce.trialDownloadUrl}
                variant="secondary"
                className="w-full"
                target="_blank"
                rel="noreferrer"
                {...analyticsAttributes("commerce_trial_click", context)}
              >
                {commerceContent.standard.cta}
              </Button>
            ) : (
              <Button href="/trial" variant="secondary" className="w-full" {...analyticsAttributes("commerce_trial_page_click", context)}>
                Trial details
              </Button>
            )}
          </div>
        </article>

        <article className="rounded-[24px] border border-cyan/18 bg-cyan/[0.06] flex h-full flex-col p-6 shadow-panel">
          <p className="type-eyebrow text-cyan">Founder</p>
          <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
            {commerceContent.founder.price}
          </p>
          <p className="mt-3 text-sm leading-6 text-muted">{commerceContent.founder.note}</p>
          <ul className="mt-6 grow space-y-3">
            {commerceContent.founder.points.map((point) => (
              <li key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
          <div className="mt-8">
            {commerce.checkoutUrl ? (
              <Button
                href={commerce.checkoutUrl}
                className="w-full"
                target="_blank"
                rel="noreferrer"
                {...analyticsAttributes("commerce_founder_checkout_click", context)}
              >
                {commerceContent.founder.cta}
              </Button>
            ) : (
              <Button href="/help" variant="secondary" className="w-full" {...analyticsAttributes("commerce_founder_fallback_click", context)}>
                Ask about founder access
              </Button>
            )}
          </div>
        </article>

        <article className="surface-panel flex h-full flex-col p-6">
          <p className="type-eyebrow text-cyan">Standard</p>
          <p className="mt-5 text-2xl font-medium tracking-[-0.04em] text-text">
            After the trial
          </p>
          <p className="mt-3 text-sm leading-6 text-muted">
            Buy the one-time license after the trial if you want to keep it.
          </p>
          <ul className="mt-6 grow space-y-3">
            {[
              "One-time purchase after trial",
              "Separate from trial onboarding",
              "Use Help if you lose the receipt",
            ].map((point) => (
              <li key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
          <div className="mt-8">
            {commerce.standardCheckoutUrl ? (
              <Button
                href={commerce.standardCheckoutUrl}
                className="w-full"
                target="_blank"
                rel="noreferrer"
                {...analyticsAttributes("commerce_standard_checkout_click", context)}
              >
                Buy license
              </Button>
            ) : (
              <Button href="/help" variant="secondary" className="w-full" {...analyticsAttributes("commerce_standard_fallback_click", context)}>
                Buy path details
              </Button>
            )}
          </div>
        </article>
      </MotionReveal>

      <MotionReveal direction="up" delay={140} className="surface-panel p-6">
        <p className="type-eyebrow text-cyan">Commerce setup</p>
        <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
          <p className="text-sm leading-7 text-muted">
            {providerNote ?? "Hosted checkout is ready for a trial link, a founder checkout link, and a standard buy link."}
          </p>
          <div className="grid gap-3 md:grid-cols-2">
            <a
              href="/trial"
              className="surface-muted block p-4 transition duration-200 hover:-translate-y-0.5 hover:border-white/14"
            >
              <p className="text-sm font-medium text-text">Trial page</p>
              <p className="mt-1 text-sm leading-6 text-muted">
                Explain the 14-day evaluation and publish the build.
              </p>
            </a>
            <a
              href="/help"
              className="surface-muted block p-4 transition duration-200 hover:-translate-y-0.5 hover:border-white/14"
            >
              <p className="text-sm font-medium text-text">Help page</p>
              <p className="mt-1 text-sm leading-6 text-muted">
                Handle purchase recovery, activation questions, and billing help.
              </p>
            </a>
          </div>
        </div>
      </MotionReveal>
    </div>
  );
}
