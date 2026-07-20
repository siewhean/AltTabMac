import { JsonLd } from "@/components/seo/json-ld";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = createPageMetadata({
  title: "Why CmdTab needs Accessibility and Screen Recording",
  description:
    "Learn why CmdTab requests macOS Accessibility and Screen Recording permissions and what happens when preview capture is unavailable.",
  path: "/permissions",
  imageAlt: "CmdTab Accessibility and Screen Recording permissions",
});

export default function PermissionsPage() {
  return (
    <main>
      <JsonLd
        data={createBreadcrumbStructuredData([
          { name: "Home", path: "/" },
          { name: "Permissions", path: "/permissions" },
        ])}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        eyebrow="Permissions"
        title="Why CmdTab needs Accessibility and Screen Recording"
        description="CmdTab uses each permission for a specific macOS switching capability. This page explains the relationship directly."
        className="pt-14"
      >
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
            Accessibility is still required for shortcut handling and exact focus operations. CmdTab surfaces permission health in Settings so a missing permission can be diagnosed without guessing.
          </p>
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
