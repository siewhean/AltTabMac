import { Button } from "@/components/ui/button";
import { analyticsAttributes } from "@/lib/analytics";

export function CommerceOfferGrid({ context }: { context: string }) {
  return <article className="surface-panel p-6">
    <h2 className="text-2xl font-medium text-text">Join the CmdTab waitlist</h2>
    <p className="mt-3 text-sm leading-7 text-muted">CmdTab is in private preview. Sign up for access updates; no purchase or download is available yet.</p>
    <Button href="/waitlist" className="mt-6" {...analyticsAttributes("waitlist_cta_click", context)}>Join the waitlist</Button>
  </article>;
}
