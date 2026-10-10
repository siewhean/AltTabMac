import { WaitlistForm } from "@/components/sections/waitlist-form";
import { SectionShell } from "@/components/ui/section-shell";

const honestyPoints = [
  { title: "What it asks for", body: "Accessibility (to detect your shortcut and focus the window you pick) and Screen Recording (to draw previews). Without Screen Recording, windows still appear with icons." },
  { title: "What it never collects", body: "Optional telemetry is off by default. It never includes window titles, previews, screenshots, keystrokes, clipboard contents, or search queries." },
  { title: "What it will cost", body: "Planned: a 14-day trial, then a one-time US$12 license for up to three of your Macs and all 1.x updates. No subscription. 14-day refund." },
] as const;

export function BetaCtaSection() {
  return (
    <SectionShell
      id="beta"
      eyebrow="Private beta"
      title="Be first when the next beta opens."
      description="Invitations go out in waves, in queue order. Invite friends after you join to move up the list."
    >
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div className="surface-panel p-6 sm:p-8">
          <WaitlistForm source="homepage_footer" variant="page" />
        </div>
        <dl className="grid gap-5 sm:grid-cols-3 lg:grid-cols-1">
          {honestyPoints.map((point) => (
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
