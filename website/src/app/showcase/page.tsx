import Link from "next/link";

import { JsonLd } from "@/components/seo/json-ld";
import { FooterSection } from "@/components/sections/footer-section";
import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { showcaseAsset, showcaseAssets, showcaseReviewedAt } from "@/content/showcase";
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

const detailLinks: Record<string, string> = {
  "classic-grid": "/features/classic-grid",
  "command-palette": "/features/command-palette",
  "radial-menu": "/features/radial-menu",
  "quick-actions": "/features/quick-actions",
};

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
        title="CmdTab in motion."
        description="Short HD loops show the switcher styles and Quick Actions without recording a private desktop."
        className="pt-12 sm:pt-14"
      >
        <ShowcaseVideo asset={overview} priority showCaption={false} />
      </SectionShell>

      <SectionShell
        title="Modes and actions."
        description="Swipe on mobile or open a card for the detailed behavior."
        className="pt-4 sm:pt-6"
      >
        <div
          role="region"
          aria-label="CmdTab showcase modes and actions"
          tabIndex={0}
          className="-mx-5 flex snap-x snap-mandatory gap-5 overflow-x-auto px-5 pb-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:-mx-8 sm:px-8 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 md:pb-0"
        >
          {assets.map((asset) => (
            <article
              key={asset.id}
              id={asset.id}
              className="min-w-[86vw] snap-center scroll-mt-24 sm:min-w-[62vw] md:min-w-0"
            >
              <ShowcaseVideo asset={asset} showCaption={false} />
              <div className="pt-4 sm:pt-5">
                <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">{asset.title}</h2>
                <p className="mt-2 max-w-xl text-sm leading-6 text-muted">{asset.description}</p>
                <Link
                  href={detailLinks[asset.id]}
                  className="mt-3 inline-flex min-h-11 items-center text-sm font-medium text-cyan transition-colors hover:text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
                >
                  View details →
                </Link>
              </div>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell className="pt-4 sm:pt-6">
        <div className="flex flex-col gap-5 border-t border-white/8 pt-8 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-3xl font-medium tracking-[-0.05em] text-text">Try it on your own desktop.</h2>
            <p className="mt-2 text-sm leading-6 text-muted">The full behavior is easiest to judge with your real windows.</p>
          </div>
          <div className="flex w-full flex-col gap-3 sm:w-auto sm:flex-row">
            <Button href="/trial" className="w-full sm:w-auto">
              Start the trial
            </Button>
            <Button href="/evidence" variant="secondary" className="w-full sm:w-auto">
              Review evidence
            </Button>
          </div>
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
