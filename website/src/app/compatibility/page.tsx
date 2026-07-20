import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts, publicProductFactRows } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab compatibility and system requirements";
const description =
  "Review the current CmdTab version, macOS minimum, permissions, switcher modes, Space scope, display placement, trial, license model, and validation limits.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Compatibility", path: "/compatibility" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/compatibility",
  imageAlt: "CmdTab compatibility and macOS system requirements",
});

export default function CompatibilityPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/compatibility",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Compatibility"
        title="CmdTab compatibility and product facts"
        description="A concise reference for the current packaged version, declared macOS requirement, permissions, switching scope, and facts that still require release-machine validation."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} />
          <Button href={productFacts.sourceRepository} target="_blank" rel="noreferrer" variant="ghost">
            Verify project metadata
          </Button>
        </div>
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
        eyebrow="Validation status"
        title="Declared support is not the same as release proof"
        description="This page separates facts encoded in the project from compatibility claims that should only be published after repeatable clean-machine testing."
        className="pt-0"
      >
        <div className="grid gap-5 lg:grid-cols-3">
          <article className="surface-panel p-6">
            <h2 className="text-xl font-medium tracking-[-0.03em] text-text">Declared today</h2>
            <p className="mt-3 text-sm leading-7 text-muted">
              The packaged app records version {productFacts.currentVersion}, build {productFacts.buildNumber}, and a minimum system of {productFacts.minimumMacOS}.
            </p>
          </article>
          <article className="surface-panel p-6">
            <h2 className="text-xl font-medium tracking-[-0.03em] text-text">Not claimed without proof</h2>
            <p className="mt-3 text-sm leading-7 text-muted">
              Processor coverage, every later macOS release, Stage Manager edge cases, and private window-focus APIs require release validation on representative Macs before they should become broad marketing claims.
            </p>
          </article>
          <article className="surface-panel p-6">
            <h2 className="text-xl font-medium tracking-[-0.03em] text-text">What to test</h2>
            <p className="mt-3 text-sm leading-7 text-muted">
              Validate permissions, multiple windows per app, fullscreen Spaces, multi-display placement, exact-window activation, secure input, sleep and wake, and the signed packaged build.
            </p>
          </article>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Permissions"
        title="Why CmdTab asks for macOS access"
        description="The permissions are tied to specific switcher functions rather than unrelated window-content collection."
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
