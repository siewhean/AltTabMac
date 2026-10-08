import { TrialWaitlistForm } from "@/components/sections/trial-waitlist-form";
import { SectionShell } from "@/components/ui/section-shell";

export function LaunchSection() {
  return (
    <SectionShell id="launch" eyebrow="Private preview" title="Your next window is one shortcut away." description="Join the CmdTab waitlist. We’ll email you when early access opens. No payment, download, or trial enrollment is available yet.">
      <div className="surface-panel mx-auto max-w-2xl p-6 sm:p-8">
        <TrialWaitlistForm />
      </div>
    </SectionShell>
  );
}
