import { JsonLd } from "@/components/seo/json-ld";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts, publicProductFactRows } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = createPageMetadata({
  title: "CmdTab compatibility and system requirements",
  description:
    "Review CmdTab macOS requirements, permissions, switcher modes, Space scope, display placement, trial, and license model.",
  path: "/compatibility",
  imageAlt: "CmdTab compatibility and macOS system requirements",
});

export default function CompatibilityPage() {
  return (
    <main>
      <JsonLd
        data={createBreadcrumbStructuredData([
          { name: "Home", path: "/" },
          { name: "Compatibility", path: "/compatibility" },
        ])}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        eyebrow="Compatibility"
        title="CmdTab compatibility and product facts"
        description="A concise reference for the current public requirements and behavior of CmdTab."
        className="pt-14"
      >
        <div className="overflow-hidden rounded-[28px] border border-white/10 bg-white/[0.04]">
          <dl className="divide-y divide-white/8">
            {publicProductFactRows.map((fact) => (
              <div key={fact.label} className="grid gap-2 px-6 py-5 sm:grid-cols-[220px_minmax(0,1fr)]">
                <dt className="text-sm font-medium text-text">{fact.label}</dt>
                <dd className="text-sm leading-7 text-muted">{fact.value}</dd>
              </div>
            ))}
          </dl>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Permissions"
        title="Why CmdTab asks for macOS access"
        description="The permissions are tied to specific switcher functions rather than unrelated data collection."
        className="pt-0"
      >
        <div className="grid gap-5 md:grid-cols-2">
          {productFacts.permissions.map((permission) => (
            <article key={permission.name} className="surface-panel p-6">
              <h2 className="text-xl font-medium tracking-[-0.03em] text-text">
                {permission.name}
              </h2>
              <p className="mt-3 text-sm leading-7 text-muted">{permission.reason}</p>
            </article>
          ))}
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
