import { WaitlistForm } from "@/components/sections/waitlist-form";
import { SectionShell } from "@/components/ui/section-shell";
import { betaHonestyPoints } from "@/content/beta-honesty";

export function BetaCtaSection() {
  return (
    <SectionShell
      id="beta"
      eyebrow="Private beta"
      title="Be first when the next beta opens."
      description="Enter your email and you’re in. We’ll email you the moment a beta build is ready, in waves. Invite friends after you join to earn a free license."
    >
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div className="surface-panel p-6 sm:p-8">
          <WaitlistForm source="homepage_footer" variant="page" />
        </div>
        <dl className="grid gap-5 sm:grid-cols-3 lg:grid-cols-1">
          {betaHonestyPoints.map((point) => (
            <div key={point.title} className="border-t border-white/10 pt-4">
              <dt className="text-sm font-semibold text-text">{point.title}</dt>
              <dd className="mt-2 text-sm leading-6 text-muted">{point.body}</dd>
            </div>
          ))}
        </dl>
      </div>
    </SectionShell>
  );
}
