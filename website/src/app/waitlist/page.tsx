import { JsonLd } from "@/components/seo/json-ld";
import { FooterSection } from "@/components/sections/footer-section";
import { TrialWaitlistForm } from "@/components/sections/trial-waitlist-form";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData, createWebPageStructuredData } from "@/lib/structured-data";

const title = "Join the CmdTab Waitlist — Mac Window Switcher";
const description = "Join the CmdTab waitlist for a macOS window switcher with previews, window search, and quick actions. Get early access updates. No payment required.";
const breadcrumbs = [{ name: "Home", path: "/" }, { name: "Waitlist", path: "/waitlist" }] as const;
export const metadata = createPageMetadata({ title, description, path: "/waitlist", imageAlt: "CmdTab macOS window switcher waitlist" });

export default function WaitlistPage() {
  return <main>
    <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
    <JsonLd data={createWebPageStructuredData({ name: title, description, path: "/waitlist" })} />
    <SiteHeader />
    <SectionShell headingAs="h1" breadcrumbs={breadcrumbs} eyebrow="Private preview" title="Find your next window. Join the waitlist." description="CmdTab brings previews, search, and quick actions to switching between individual Mac windows. Leave your email and we’ll let you know when early access opens." className="pt-14">
      <div className="grid gap-8 lg:grid-cols-2">
        <div className="space-y-5 text-sm leading-7 text-muted">
          <h2 className="text-2xl font-medium text-text">A better way through a busy desktop.</h2>
          <ul className="list-disc space-y-3 pl-5"><li>Choose individual windows, rather than guessing which app holds them.</li><li>Explore Classic Grid, Command Palette, and Radial Menu in the showcase.</li><li>Receive early access and launch updates without entering payment details.</li></ul>
          <p>Public downloads, purchases, and trials are closed for now. Joining does not guarantee a launch date or an invitation.</p>
          <p>CmdTab targets macOS 13 (Ventura) and later. Accessibility enables switching; Screen Recording enables previews. You can review permissions before deciding to use the app.</p>
        </div>
        <div className="surface-panel p-6 sm:p-8"><TrialWaitlistForm /></div>
      </div>
    </SectionShell>
    <FooterSection />
  </main>;
}
