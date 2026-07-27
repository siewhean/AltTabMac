import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { commerceContent } from "@/content/commerce";
import { analyticsAttributes } from "@/lib/analytics";
import { getCommerceConfig } from "@/lib/commerce";
import { getStableReleaseManifest } from "@/lib/stable-release";

type CommerceOfferGridProps = {
  context: string;
};

export function CommerceOfferGrid({ context }: CommerceOfferGridProps) {
  const commerce = getCommerceConfig();
  const release = getStableReleaseManifest();

  return (
    <div className="space-y-6">
      <MotionReveal direction="left" className="grid gap-6 md:grid-cols-2">
        <article className="surface-panel flex h-full flex-col p-6">
          <p className="type-eyebrow text-cyan">Trial</p>
          <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
            {commerceContent.trialLength}
          </p>
          <p className="mt-3 text-sm leading-6 text-muted">
            Use the full app in real work before you decide.
          </p>
          <ul className="mt-6 grow space-y-3">
            {commerceContent.trial.points.map((point) => (
              <li key={point} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                <span className="mt-2 h-2 w-2 rounded-full bg-success" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
          <div className="mt-8">
            {release ? (
              <Button
                href={release.dmgURL}
                variant="secondary"
                className="w-full"
                target="_blank"
                rel="noreferrer"
                {...analyticsAttributes("commerce_trial_click", context)}
              >
                {commerceContent.trial.cta}
              </Button>
            ) : (
              <Button href="/trial" variant="secondary" className="w-full" {...analyticsAttributes("commerce_trial_page_click", context)}>
                Trial details
              </Button>
            )}
          </div>
        </article>

        <article className="rounded-[24px] border border-cyan/18 bg-cyan/[0.06] flex h-full flex-col p-6 shadow-panel">
          <p className="type-eyebrow text-cyan">{commerceContent.license.title}</p>
          <p className="mt-5 text-4xl font-medium tracking-[-0.06em] text-text">
            {commerceContent.license.price}
          </p>
          <p className="mt-3 text-sm leading-6 text-muted">{commerceContent.license.note}</p>
          <ul className="mt-6 grow space-y-3">
            {commerceContent.license.points.map((point) => (
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
                {...analyticsAttributes("commerce_license_checkout_click", context)}
              >
                {commerceContent.license.cta}
              </Button>
            ) : (
              <Button href="/help" variant="secondary" className="w-full" {...analyticsAttributes("commerce_license_fallback_click", context)}>
                Ask about purchase access
              </Button>
            )}
          </div>
        </article>
      </MotionReveal>
    </div>
  );
}
