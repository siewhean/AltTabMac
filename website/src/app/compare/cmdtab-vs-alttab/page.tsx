import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { altTabComparison } from "@/content/alttab-comparison";
import { createPageMetadata } from "@/lib/seo";
import {
  createArticleStructuredData,
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab vs AltTab for macOS: window model, search, modes, and price";
const description =
  "A source-dated comparison of CmdTab and AltTab for macOS, covering window switching, search tiers, previews, quick actions, shortcuts, pricing, adoption signals, and public evidence.";
const path = "/compare/cmdtab-vs-alttab" as const;
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Switcher landscape", path: "/compare/mac-window-switchers" as const },
  { name: "CmdTab vs AltTab", path },
];
const citations = altTabComparison.sources.map((source) => source.href);

export const metadata = createPageMetadata({
  title,
  description,
  path,
  imageAlt: "Source-dated comparison of CmdTab and AltTab for macOS",
});

export default function CmdTabVsAltTabPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path,
          dateModified: altTabComparison.reviewedAt,
        })}
      />
      <JsonLd
        data={createArticleStructuredData({
          headline: title,
          description,
          path,
          about: ["CmdTab", "AltTab", "macOS window switchers", "Command-Tab alternatives"],
          citation: citations,
          datePublished: altTabComparison.reviewedAt,
          dateModified: altTabComparison.reviewedAt,
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Focused comparison"
        title="CmdTab versus AltTab: choose the window-switching model first"
        description="AltTab is the mature, broadly adopted choice with a free core. CmdTab is an active beta built around exact-window global recency and three presentation modes. The right answer depends on which workflow you value."
        className="pt-14"
      >
        <div className="mb-8 grid gap-3 border-b border-white/8 pb-8 sm:grid-cols-[auto_minmax(0,1fr)] sm:items-start sm:gap-8">
          <LastReviewed date={altTabComparison.reviewedAt} />
          <div className="space-y-3 text-sm leading-7 text-subdued">
            <p>{altTabComparison.methodology}</p>
            <p>{altTabComparison.adoptionNote}</p>
          </div>
        </div>
        <div
          role="region"
          aria-label="CmdTab and AltTab comparison"
          tabIndex={0}
          className="overflow-x-auto rounded-[26px] border border-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
        >
          <table className="w-full min-w-[920px] border-collapse text-left text-sm">
            <thead className="bg-white/[0.05] text-text">
              <tr>
                <th className="px-5 py-4 font-medium">Decision factor</th>
                <th className="px-5 py-4 font-medium">AltTab</th>
                <th className="px-5 py-4 font-medium">CmdTab</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/8 bg-white/[0.02]">
              {altTabComparison.rows.map(([factor, altTab, cmdTab]) => (
                <tr key={factor} className="align-top">
                  <th scope="row" className="px-5 py-5 font-medium text-text">
                    {factor}
                  </th>
                  <td className="max-w-[360px] px-5 py-5 leading-7 text-muted">{altTab}</td>
                  <td className="max-w-[360px] px-5 py-5 leading-7 text-muted">{cmdTab}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Decision guide"
        title="Neither product wins every workflow"
        description="A fair comparison identifies the conditions under which each option is the more sensible choice."
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-3">
          {altTabComparison.decisions.map((decision) => (
            <article key={decision.title} className="surface-panel p-7">
              <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">{decision.title}</h2>
              <p className="mt-4 text-base leading-8 text-muted">{decision.body}</p>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Sources"
        title="Every changing external claim is linked to AltTab’s own pages"
        description="Re-check the current pages before relying on prices, feature tiers, compatibility, download counts, or GitHub-star totals after the displayed review date."
        className="pt-0"
      >
        <ul className="grid gap-3 text-sm leading-7 text-muted md:grid-cols-2">
          {altTabComparison.sources.map((source) => (
            <li key={source.href}>
              <a
                href={source.href}
                target="_blank"
                rel="noreferrer"
                className="text-cyan underline underline-offset-4 hover:text-text"
              >
                {source.label}
              </a>
            </li>
          ))}
        </ul>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button href="/compare/mac-window-switchers">Review the wider landscape</Button>
          <Button href="/evidence" variant="secondary">
            Inspect CmdTab evidence
          </Button>
          <Button href="/waitlist" variant="ghost">
            Test CmdTab in your workflow
          </Button>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
