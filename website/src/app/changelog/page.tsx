import { JsonLd } from "@/components/seo/json-ld";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = createPageMetadata({
  title: "CmdTab changelog and development updates",
  description:
    "Review dated CmdTab development updates covering window previews, search, quick actions, display behavior, licensing, and the public website.",
  path: "/changelog",
  imageAlt: "CmdTab development changelog",
});

const updates = [
  {
    date: "27 March 2026",
    title: "Window enumeration and preview reliability",
    points: [
      "Deduplicated repeated WindowServer entries by exact process and window identity.",
      "Preferred the cleaner WindowServer hardware-capture path for window thumbnails.",
      "Kept selected-window backdrop presentation readable when captured images contain transparent edges.",
    ],
  },
  {
    date: "27 March 2026",
    title: "Product website and feature documentation",
    points: [
      "Published the Next.js product website, privacy and security pages, trial and purchase paths, and interactive switcher demonstration.",
      "Documented real window previews, search memory, quick actions, Space and display targeting, alternate triggers, and decluttering controls.",
      "Added website analytics, performance monitoring, security automation, and launch configuration documentation.",
    ],
  },
] as const;

export default function ChangelogPage() {
  return (
    <main>
      <JsonLd
        data={createBreadcrumbStructuredData([
          { name: "Home", path: "/" },
          { name: "Changelog", path: "/changelog" },
        ])}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        eyebrow="Changelog"
        title="CmdTab development updates"
        description="Dated public notes for meaningful product and website changes. Release-specific version notes will be added when public builds are versioned and distributed."
        className="pt-14"
      >
        <div className="space-y-6">
          {updates.map((update) => (
            <article key={`${update.date}-${update.title}`} className="surface-panel p-7">
              <p className="type-eyebrow text-cyan">{update.date}</p>
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
