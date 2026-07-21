import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { publicProductFactRows } from "@/content/product-facts";

export function ProductFactsSection() {
  return (
    <SectionShell
      id="product-facts"
      eyebrow="Product facts"
      title="The current requirements and commercial terms at a glance"
      description="A factual summary for users comparing compatibility, permissions, switcher scope, trial length, and license model."
      className="pt-8"
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
      <div className="mt-6 flex flex-col gap-3 sm:flex-row">
        <Button href="/compatibility">Review compatibility</Button>
        <Button href="/permissions" variant="secondary">
          Understand permissions
        </Button>
        <Button href="/changelog" variant="ghost">
          Read the changelog
        </Button>
      </div>
    </SectionShell>
  );
}
