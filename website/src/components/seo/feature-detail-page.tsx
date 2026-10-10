import Link from "next/link";

import type { BreadcrumbItem } from "@/components/seo/breadcrumbs";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import {
  featureDepthSectionLabels,
  type FeatureDepthContent,
} from "@/content/feature-depth";
import { showcaseAsset } from "@/content/showcase";

export function FeatureDetailPage({
  content,
  breadcrumbs,
  headingAs,
}: {
  content: FeatureDepthContent;
  breadcrumbs: ReadonlyArray<BreadcrumbItem>;
  headingAs: "h1";
}) {
  const showcase = showcaseAsset(content.slug);

  return (
    <>
      <SiteHeader />
      <SectionShell
        headingAs={headingAs}
        breadcrumbs={breadcrumbs}
        eyebrow={content.eyebrow}
        title={content.title}
        description={content.description}
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={content.reviewedAt} />
          <Link href={`/showcase#${showcase.id}`} className="text-sm font-medium text-cyan hover:text-text">
            Open in the full showcase →
          </Link>
        </div>
        <div className="surface-muted mb-8 p-6 sm:p-7">
          <p className="type-eyebrow text-cyan">Definition</p>
          <p className="mt-4 max-w-4xl text-base leading-8 text-muted">{content.definition}</p>
        </div>
        <ShowcaseVideo asset={showcase} priority />
        <p className="mt-4 text-sm leading-7 text-subdued">
          {content.screenshotCaption} Source: {showcase.sourceLabel}. Controlled fixture windows protect private desktop content; the Evidence page records the separate signed-app acceptance boundary.
        </p>
      </SectionShell>

      <SectionShell
        eyebrow="Current behavior"
        title="What this feature does today"
        description="These statements describe the current implementation and are intentionally narrower than an unmeasured performance claim."
        className="pt-0"
      >
        <div
          role="region"
          aria-label={`${content.eyebrow} behavior reference`}
          tabIndex={0}
          className="overflow-x-auto rounded-[24px] border border-white/10 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-cyan/60"
        >
          <table className="w-full min-w-[680px] border-collapse text-left text-sm">
            <thead className="bg-white/[0.05] text-text">
              <tr>
                <th className="px-5 py-4 font-medium">Behavior</th>
                <th className="px-5 py-4 font-medium">Current CmdTab contract</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/8 bg-white/[0.02]">
              {content.behaviorRows.map(([label, value]) => (
                <tr key={label}>
                  <th scope="row" className="px-5 py-4 font-medium text-text">
                    {label}
                  </th>
                  <td className="px-5 py-4 leading-7 text-muted">{value}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Decision guide"
        title="Where it fits, and where another mode is better"
        description="A useful feature page should state the tradeoff instead of treating every workflow as proof of superiority."
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-2">
          <article aria-label="Best fit" className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">
              {featureDepthSectionLabels.bestFit}
            </h2>
            <ul className="mt-5 space-y-4 text-sm leading-7 text-muted">
              {content.bestFit.map((item) => (
                <li key={item} className="border-l border-cyan/35 pl-4">
                  {item}
                </li>
              ))}
            </ul>
          </article>
          <article aria-label="Tradeoffs and limits" className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">
              {featureDepthSectionLabels.tradeoffs}
            </h2>
            <ul className="mt-5 space-y-4 text-sm leading-7 text-muted">
              {content.tradeoffs.map((item) => (
                <li key={item} className="border-l border-white/15 pl-4">
                  {item}
                </li>
              ))}
            </ul>
          </article>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Continue"
        title="Choose the next source by the problem you need to solve"
        className="pt-0"
      >
        <div className="grid gap-5 md:grid-cols-3">
          {content.adjacentLinks.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="surface-panel group block h-full p-6 transition-transform duration-200 hover:-translate-y-0.5"
            >
              <h2 className="text-xl font-medium tracking-[-0.03em] text-text">{item.label}</h2>
              <p className="mt-3 text-sm leading-7 text-muted">{item.description}</p>
              <p className="mt-5 text-sm font-medium text-cyan group-hover:text-text">Open resource →</p>
            </Link>
          ))}
        </div>
      </SectionShell>
      <FooterSection />
    </>
  );
}
