import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import { getStableReleaseManifest } from "@/lib/stable-release";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab changelog and development updates";
const description =
  "Review dated CmdTab development updates covering exact-window MRU, preview reliability, permissions, search, quick actions, licensing, security, SEO, GEO, and the public website.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Changelog", path: "/changelog" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/changelog",
  imageAlt: "CmdTab version and development changelog",
});

const updates = [
  {
    date: "20 July 2026",
    version: "Website discovery hardening",
    title: "Search, GEO, privacy, and evidence architecture",
    points: [
      "Added dedicated window-switcher, Mac guide, native comparison, FAQ, compatibility, permissions, privacy, About, and changelog resources with visible review dates and source links.",
      "Expanded the CmdTab entity graph and software structured data with current version, requirements, features, screenshots, offers, publisher, source repository, and release-note relationships.",
      "Published the exact native-app telemetry fields and explicit exclusions instead of relying on a vague analytics statement.",
      "Added first-party AI-referral classification, a private discovery dashboard, a canonical route registry, IndexNow support, and deterministic SEO verification.",
    ],
  },
  {
    date: "17 July 2026",
    version: productFacts.currentVersion,
    title: "Complete membership and strict exact-window MRU",
    points: [
      "Kept eligible windows represented when preview capture fails instead of letting screenshot availability change switcher membership.",
      "Removed PID-based selection skipping so windows from the same app remain interleaved in one global exact-window recent-use sequence.",
      "Added focused-window observation, ambiguous-frontmost resolution, provisional rapid-repress state, and verified-only permanent history updates.",
      "Validated focused regressions and the complete Swift package suite on macOS 14 and macOS 15 CI.",
    ],
  },
  {
    date: "27 March 2026",
    version: "Preview and enumeration pass",
    title: "Window enumeration and preview reliability",
    points: [
      "Deduplicated repeated WindowServer entries by exact process and window identity.",
      "Preferred the cleaner WindowServer hardware-capture path for window thumbnails.",
      "Kept selected-window backdrop presentation readable when captured images contain transparent edges.",
    ],
  },
  {
    date: "27 March 2026",
    version: "Website launch pass",
    title: "Product website and feature documentation",
    points: [
      "Published the Next.js product website, privacy and security pages, trial and purchase paths, and interactive switcher demonstration.",
      "Documented real window previews, search memory, quick actions, Space and display targeting, alternate triggers, and decluttering controls.",
      "Added website analytics, performance monitoring, security automation, and launch configuration documentation.",
    ],
  },
] as const;

export default function ChangelogPage() {
  const release = getStableReleaseManifest();

  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/changelog",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Changelog"
        title="CmdTab development updates"
        description="Dated public notes for meaningful product, release, security, and website changes. Version claims are tied to current project metadata rather than invented marketing milestones."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} />
          <Button href={productFacts.sourceRepository} target="_blank" rel="noreferrer" variant="ghost">
            Review commit history
          </Button>
        </div>
        <section className="surface-panel mb-6 p-7" aria-labelledby="stable-release-heading">
          <p className="type-eyebrow text-cyan">Stable release</p>
          <h2 id="stable-release-heading" className="mt-4 text-2xl font-medium tracking-[-0.04em] text-text">
            {release ? `CmdTab ${release.version} (build ${release.build})` : "No distributable build published"}
          </h2>
          {release ? (
            <>
              <p className="mt-3 max-w-3xl text-sm leading-7 text-muted">
                Published {release.releaseDate} for macOS {release.minimumMacOS} or later. The DMG,
                checksum, source commit, and update feed are bound by the stable release manifest.
              </p>
              <div className="mt-5 flex flex-col gap-3 sm:flex-row">
                <Button href="/waitlist">
                  Join the waitlist
                </Button>
                <Button href="/releases/stable.json" variant="secondary">
                  Review release manifest
                </Button>
              </div>
            </>
          ) : (
            <p className="mt-3 max-w-3xl text-sm leading-7 text-muted">
              Development notes do not constitute a signed public release. Download links remain
              unavailable until a notarized immutable DMG passes the release gate.
            </p>
          )}
        </section>
        <div className="space-y-6">
          {updates.map((update) => (
            <article key={`${update.date}-${update.title}`} className="surface-panel p-7">
              <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <p className="type-eyebrow text-cyan">{update.date}</p>
                <p className="text-sm text-subdued">{update.version}</p>
              </div>
              <h2 className="mt-4 text-2xl font-medium tracking-[-0.04em] text-text">
                {update.title}
              </h2>
              <ul className="mt-5 space-y-3 text-sm leading-7 text-muted">
                {update.points.map((point) => (
                  <li key={point} className="flex gap-3">
                    <span aria-hidden="true" className="mt-2 h-2 w-2 shrink-0 rounded-full bg-cyan" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
