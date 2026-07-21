import Link from "next/link";

import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import {
  showcaseAssets,
  showcaseBoundary,
  showcaseDisclosure,
  showcaseReviewedAt,
} from "@/content/showcase";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createVideoStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab app switcher showcase: real UI images and short videos";
const description =
  "Watch real production renders of CmdTab Classic Grid, Command Palette, Radial Menu, and Quick Actions in short privacy-safe MP4 loops with controlled fixture windows.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Showcase", path: "/showcase" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/showcase",
  image: "/showcase/overview-poster.png",
  imageAlt: "CmdTab production app switcher showcase with controlled fixture windows",
});

export default function ShowcasePage() {
  const [overview, ...clips] = showcaseAssets;

  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/showcase",
          dateModified: showcaseReviewedAt,
        })}
      />
      <JsonLd data={createVideoStructuredData(showcaseAssets)} />

      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Real product showcase"
        title="See the CmdTab switcher move, search, and reflow"
        description="These images and short silent videos are rendered from the production SwiftUI/AppKit switcher views. Controlled fixture windows keep the media reproducible and prevent private desktop content from entering the website."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-4 border-b border-white/8 pb-8 sm:flex-row sm:items-start sm:justify-between">
          <LastReviewed date={showcaseReviewedAt} />
          <p className="max-w-2xl text-sm leading-7 text-subdued">{showcaseDisclosure}</p>
        </div>

        <ShowcaseVideo asset={overview} priority />

        <div className="mt-8 grid gap-4 rounded-[24px] border border-cyan/15 bg-cyan/[0.055] p-6 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-center">
          <div>
            <p className="type-eyebrow text-cyan">Evidence boundary</p>
            <p className="mt-3 max-w-4xl text-sm leading-7 text-muted">{showcaseBoundary}</p>
          </div>
          <Link
            href="/evidence"
            className="inline-flex min-h-11 items-center justify-center rounded-full border border-white/12 bg-white/[0.05] px-5 text-sm font-medium text-text hover:bg-white/[0.09] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
          >
            Review test evidence
          </Link>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Mode clips"
        title="One short demonstration for each production surface"
        description="Each loop has its own stable MP4 and poster URL, visible explanation, and text transcript. Playback pauses by default for people who prefer reduced motion."
        className="pt-0"
      >
        <div className="grid gap-12">
          {clips.map((asset, index) => (
            <article
              key={asset.id}
              id={asset.id}
              className="grid scroll-mt-24 gap-7 border-t border-white/8 pt-10 lg:grid-cols-[minmax(0,1.15fr)_minmax(280px,0.65fr)] lg:items-start"
            >
              <ShowcaseVideo asset={asset} />
              <div className="lg:pt-4">
                <p className="type-eyebrow text-cyan">Clip {String(index + 1).padStart(2, "0")}</p>
                <h2 className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text">{asset.title}</h2>
                <p className="mt-4 text-base leading-8 text-muted">{asset.description}</p>
                <dl className="mt-7 grid gap-3 text-sm">
                  <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                    <dt className="text-subdued">Resolution</dt>
                    <dd className="font-medium text-text">{asset.width} × {asset.height}</dd>
                  </div>
                  <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                    <dt className="text-subdued">Duration</dt>
                    <dd className="font-medium text-text">{asset.durationSeconds.toFixed(1)} seconds</dd>
                  </div>
                  <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                    <dt className="text-subdued">Audio</dt>
                    <dd className="font-medium text-text">None</dd>
                  </div>
                  <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                    <dt className="text-subdued">Source</dt>
                    <dd className="text-right font-medium text-text">Production UI + fixtures</dd>
                  </div>
                </dl>
              </div>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Continue"
        title="Inspect the behavior behind the footage"
        description="The showcase explains presentation. The feature and evidence pages document the exact current contract, limits, and validation boundary."
        className="pt-0"
      >
        <div className="grid gap-5 md:grid-cols-3">
          {[
            {
              href: "/features/window-switcher",
              title: "Switcher behavior",
              body: "Review exact-window membership, MRU ordering, preview fallback, Spaces, displays, and activation.",
            },
            {
              href: "/features/command-palette",
              title: "Command Palette",
              body: "Review local matching, remembered selections, stable ties, and query privacy boundaries.",
            },
            {
              href: "/evidence",
              title: "Testing and evidence",
              body: "Separate automated regression proof from the remaining signed-app desktop acceptance work.",
            },
          ].map((item) => (
            <Link key={item.href} href={item.href} className="surface-panel group block p-6 hover:-translate-y-0.5">
              <h2 className="text-xl font-medium tracking-[-0.03em] text-text">{item.title}</h2>
              <p className="mt-3 text-sm leading-7 text-muted">{item.body}</p>
              <p className="mt-5 text-sm font-medium text-cyan group-hover:text-text">Open resource →</p>
            </Link>
          ))}
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
