import Link from "next/link";

import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import {
  showcaseAsset,
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

const title = "CmdTab HD app switcher showcase: sharp images and 30 fps videos";
const description =
  "Explore privacy-safe 1920 × 1200 CmdTab interface posters and silent H.264 videos at 30 fps, generated from vector source with controlled fixture windows.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Showcase", path: "/showcase" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/showcase",
  image: "/showcase/overview-poster.webp",
  imageAlt: "Sharp 1920 by 1200 CmdTab HD product showcase with controlled fixture windows",
  imageWidth: 1920,
  imageHeight: 1200,
});

export default function ShowcasePage() {
  const overview = showcaseAsset("overview");
  const assets = showcaseAssets.filter((asset) => asset.id !== "overview");

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
        eyebrow="HD product showcase"
        title="See CmdTab move, search, and reflow in HD"
        description="Every maintained poster and video is generated at 1920 × 1200 from vector source. The three silent H.264 clips run at 30 fps, while controlled fixture windows keep the showcase privacy-safe and reproducible."
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
        eyebrow="Mode media"
        title="A sharp demonstration for every production surface"
        description="Animated clips are used where reviewed motion is available; HD posters are used where a static view communicates the current interface more honestly. Every item has a stable URL, explicit dimensions, and a visible source label."
        className="pt-0"
      >
        <div className="grid gap-12">
          {assets.map((asset, index) => (
            <article
              key={asset.id}
              id={asset.id}
              className="grid scroll-mt-24 gap-7 border-t border-white/8 pt-10 lg:grid-cols-[minmax(0,1.15fr)_minmax(280px,0.65fr)] lg:items-start"
            >
              <ShowcaseVideo asset={asset} />
              <div className="lg:pt-4">
                <p className="type-eyebrow text-cyan">Item {String(index + 1).padStart(2, "0")}</p>
                <h2 className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text">{asset.title}</h2>
                <p className="mt-4 text-base leading-8 text-muted">{asset.description}</p>
                <dl className="mt-7 grid gap-3 text-sm">
                  <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                    <dt className="text-subdued">Resolution</dt>
                    <dd className="font-medium text-text">{asset.posterWidth} × {asset.posterHeight}</dd>
                  </div>
                  <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                    <dt className="text-subdued">Format</dt>
                    <dd className="font-medium text-text">{asset.video ? "Silent H.264 MP4 + WebP" : "WebP poster"}</dd>
                  </div>
                  {asset.videoFrameRate ? (
                    <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                      <dt className="text-subdued">Frame rate</dt>
                      <dd className="font-medium text-text">{asset.videoFrameRate} fps</dd>
                    </div>
                  ) : null}
                  {asset.durationSeconds ? (
                    <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                      <dt className="text-subdued">Duration</dt>
                      <dd className="font-medium text-text">{asset.durationSeconds.toFixed(1)} seconds</dd>
                    </div>
                  ) : null}
                  <div className="flex justify-between gap-4 border-b border-white/8 pb-3">
                    <dt className="text-subdued">Source</dt>
                    <dd className="text-right font-medium text-text">{asset.sourceLabel}</dd>
                  </div>
                </dl>
              </div>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Continue"
        title="Inspect the behavior behind the media"
        description="The HD showcase explains presentation. The feature and evidence pages document the exact current contract, limitations, and remaining signed-app validation boundary."
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
