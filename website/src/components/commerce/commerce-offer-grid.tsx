"use client";

import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { commerceContent } from "@/content/commerce";
import { analyticsAttributes } from "@/lib/analytics";
import { getCommerceConfig } from "@/lib/commerce";

type CommerceOfferGridProps = {
  context: string;
};

export function CommerceOfferGrid({ context }: CommerceOfferGridProps) {
  const commerce = getCommerceConfig();

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
          <p className="mt-3 text-sm leading-6 text-muted">{commerceContent.founder.note}
          </p>
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
            Buy the one-time license after trial if you want to keep using it.
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
    </div>
  );
}
