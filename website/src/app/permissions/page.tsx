import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "Why CmdTab needs Accessibility and Screen Recording";
const description =
  "Learn exactly why CmdTab requests macOS Accessibility and Screen Recording, what each permission enables, which local window data is not sent in telemetry, and what happens when preview capture is unavailable.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Permissions", path: "/permissions" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/permissions",
  imageAlt: "CmdTab Accessibility and Screen Recording permissions",
});

export default function PermissionsPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/permissions",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Permissions"
        title="Why CmdTab needs Accessibility and Screen Recording"
        description="CmdTab uses each permission for a specific macOS switching capability. This page separates local window access from the small operational telemetry the app sends."
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date={productFacts.reviewedAt} />
        </div>
        <div className="grid gap-6 lg:grid-cols-2">
          {productFacts.permissions.map((permission) => (
            <article key={permission.name} className="surface-panel p-7">
              <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">
                {permission.name}
              </h2>
              <p className="mt-4 text-base leading-8 text-muted">{permission.reason}</p>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Graceful fallback"
        title="A missing preview should not mean a missing window"
        description="When Screen Recording is denied or a capture fails, CmdTab keeps eligible window entries available using the app icon or placeholder presentation."
        className="pt-0"
      >
        <div className="surface-panel p-7 text-base leading-8 text-muted">
          <p>
            Accessibility remains necessary for shortcut handling, window inspection, and exact focus operations. CmdTab surfaces permission health in Settings so a missing permission can be diagnosed without guessing.
          </p>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Data boundary"
        title="Permission does not mean window content is uploaded"
        description="The current telemetry contract is narrower than the local macOS access used to render and focus windows."
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-2">
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Sent by the current app</h2>
            <ul className="mt-4 space-y-3 text-sm leading-7 text-muted">
              {productFacts.appTelemetry.fields.map((field) => (
                <li key={field} className="flex gap-3">
                  <span aria-hidden="true" className="mt-2 h-2 w-2 shrink-0 rounded-full bg-cyan" />
                  <span>{field}</span>
                </li>
              ))}
            </ul>
          </article>
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Not in the current telemetry payload</h2>
            <p className="mt-4 text-base leading-8 text-muted">{productFacts.appTelemetry.excluded}</p>
          </article>
        </div>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button href="/privacy">Read the complete privacy disclosure</Button>
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
