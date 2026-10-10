import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { marketLandscape } from "@/content/market-landscape";
import { createPageMetadata } from "@/lib/seo";
import {
  createArticleStructuredData,
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "Mac window switchers compared: macOS, AltTab, BetterCmdTab, Contexts, CmdTab, and Scopo";
const description =
  "Compare macOS switching, AltTab, BetterCmdTab, Contexts, CmdTab, and Scopo using source-dated first-party facts about window model, search, previews, pricing, and requirements.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Compare", path: "/compare/mac-window-switchers" as const },
];
const citations = marketLandscape.options.flatMap((option) => [
  option.sourceUrl,
  ...("secondarySourceUrl" in option ? [option.secondarySourceUrl] : []),
]);

export const metadata = createPageMetadata({
  title,
  description,
  path: "/compare/mac-window-switchers",
  imageAlt: "Source-dated comparison of Mac window switchers",
});

export default function MacWindowSwitchersPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/compare/mac-window-switchers",
          dateModified: marketLandscape.reviewedAt,
        })}
      />
      <JsonLd
        data={createArticleStructuredData({
          headline: title,
          description,
          path: "/compare/mac-window-switchers",
          datePublished: marketLandscape.reviewedAt,
          dateModified: marketLandscape.reviewedAt,
          about: [
            "macOS window switchers",
            "Command-Tab alternatives",
            "AltTab",
            "BetterCmdTab",
            "Contexts",
            "CmdTab",
            "Scopo",
          ],
          citation: citations,
        })}
      />

      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Source-dated landscape"
        title="Mac window switchers compared without pretending one fits everyone"
        description="This is a decision guide, not a winner's podium. It uses Apple Support and each product's own current pages, labels commercial terms explicitly, and treats missing information as unknown rather than as a missing feature."
        className="pt-14"
      >
        <div className="mb-10 flex flex-col gap-4 border-b border-white/8 pb-8 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={marketLandscape.reviewedAt} />
          <p className="max-w-2xl text-sm leading-6 text-subdued">{marketLandscape.methodology}</p>
        </div>

        <section aria-labelledby="quick-comparison">
          <p className="type-eyebrow text-cyan">Quick comparison</p>
          <h2
            id="quick-comparison"
            className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
          >
            Start with the switching model, not the screenshot
          </h2>
          <p className="mt-4 max-w-3xl text-base leading-8 text-muted">
            The biggest difference is what each tool treats as the unit of work: an application,
            every eligible window, a searchable set, a persistent sidebar, the windows in the
            current Space, or a launcher-plus-switcher workflow. Pricing and search tiers matter
            only after that model fits how you organize your Mac.
          </p>

          <p className="mt-7 text-sm leading-7 text-subdued">
            The table can be scrolled horizontally on narrow screens. Blank cells are avoided;
            every summary is tied to the official source linked in the detailed cards below.
          </p>
          <div
            role="region"
            tabIndex={0}
            aria-label="Mac window switcher comparison table"
            className="mt-4 overflow-x-auto rounded-[28px] border border-white/10 bg-white/[0.04] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-cyan/60"
          >
            <table className="min-w-[1040px] w-full border-collapse text-left">
              <thead>
                <tr className="border-b border-white/10 text-xs uppercase tracking-[0.16em] text-subdued">
                  <th className="px-5 py-4 font-semibold">Option</th>
                  <th className="px-5 py-4 font-semibold">Switching model</th>
                  <th className="px-5 py-4 font-semibold">Search</th>
                  <th className="px-5 py-4 font-semibold">Commercial model</th>
                  <th className="px-5 py-4 font-semibold">Distinctive fit</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/8">
                {marketLandscape.options.map((option) => (
                  <tr key={option.id} className="align-top">
                    <th className="px-5 py-5 text-sm font-medium text-text">
                      {option.name}
                      <span className="mt-1 block text-xs font-normal text-subdued">
                        {option.operator}
                      </span>
                    </th>
                    <td className="max-w-[300px] px-5 py-5 text-sm leading-7 text-muted">
                      {option.switchingModel}
                    </td>
                    <td className="max-w-[220px] px-5 py-5 text-sm leading-7 text-muted">
                      {option.search}
                    </td>
                    <td className="max-w-[260px] px-5 py-5 text-sm leading-7 text-muted">
                      {option.commercialModel}
                    </td>
                    <td className="max-w-[300px] px-5 py-5 text-sm leading-7 text-muted">
                      {option.distinctiveFit}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section aria-labelledby="source-notes" className="mt-16 border-t border-white/8 pt-12">
          <p className="type-eyebrow text-cyan">Source notes</p>
          <h2
            id="source-notes"
            className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
          >
            What each official source currently says
          </h2>
          <div className="mt-8 grid gap-6">
            {marketLandscape.options.map((option) => (
              <article key={option.id} className="surface-panel p-7">
                <div className="grid gap-6 lg:grid-cols-[220px_minmax(0,1fr)]">
                  <div>
                    <h3 className="text-2xl font-medium tracking-[-0.04em] text-text">
                      {option.name}
                    </h3>
                    <p className="mt-2 text-sm text-subdued">{option.minimumSystem}</p>
                  </div>
                  <div className="grid gap-5 sm:grid-cols-2">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
                        Previews and presentation
                      </p>
                      <p className="mt-3 text-sm leading-7 text-muted">{option.previews}</p>
                    </div>
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
                        Who it may suit
                      </p>
                      <p className="mt-3 text-sm leading-7 text-muted">{option.distinctiveFit}</p>
                    </div>
                  </div>
                </div>

                <div className="mt-6 flex flex-wrap gap-3 border-t border-white/8 pt-5">
                  <a
                    href={option.sourceUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="text-sm font-medium text-cyan hover:text-text"
                  >
                    {option.sourceLabel} ↗
                  </a>
                  {"secondarySourceUrl" in option ? (
                    <a
                      href={option.secondarySourceUrl}
                      target={option.secondarySourceUrl.startsWith("https://cmdtab.net") ? undefined : "_blank"}
                      rel={option.secondarySourceUrl.startsWith("https://cmdtab.net") ? undefined : "noreferrer"}
                      className="text-sm font-medium text-cyan hover:text-text"
                    >
                      {option.secondarySourceLabel}
                      {option.secondarySourceUrl.startsWith("https://cmdtab.net") ? " →" : " ↗"}
                    </a>
                  ) : null}
                </div>
              </article>
            ))}
          </div>
        </section>

        <section aria-labelledby="decision-guide" className="mt-16 border-t border-white/8 pt-12">
          <p className="type-eyebrow text-cyan">Decision guide</p>
          <h2
            id="decision-guide"
            className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
          >
            Questions worth answering before installing another switcher
          </h2>
          <ol className="mt-8 grid gap-4 md:grid-cols-2">
            {[
              "Do you want to switch applications, individual windows, or only the windows in the current project or Space?",
              "Must text search be included in the free tier, or is a paid search feature acceptable?",
              "Do minimized, hidden, fullscreen, and off-Space windows need to be included in your workflow?",
              "Are Accessibility and Screen Recording permissions acceptable for exact focus and live previews?",
              "Do you need launch capabilities, a persistent sidebar, tiling, profiles, quick actions, or multiple independent shortcuts?",
              "Do you prefer free/open-source software, a one-time purchase, or an ongoing subscription?",
              "Which macOS versions and processor architectures must be supported on every machine you use?",
              "What telemetry, update checks, and network behavior does the current product explicitly disclose?",
            ].map((question, index) => (
              <li
                key={question}
                className="rounded-[22px] border border-white/10 bg-white/[0.03] px-5 py-5 text-sm leading-7 text-muted"
              >
                <span className="mr-3 font-mono text-cyan">{String(index + 1).padStart(2, "0")}</span>
                {question}
              </li>
            ))}
          </ol>
        </section>

        <section aria-labelledby="comparison-limits" className="mt-16 border-t border-white/8 pt-12">
          <p className="type-eyebrow text-cyan">Comparison limits</p>
          <h2
            id="comparison-limits"
            className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
          >
            This page does not replace hands-on testing
          </h2>
          <p className="mt-4 max-w-3xl text-base leading-8 text-muted">
            Product pages describe intended and current marketed behavior. They do not prove
            reliability on your exact macOS build, display topology, permission state, app mix, or
            shortcut conflicts. Install the current release, verify its permissions and privacy
            behavior, and test the window sequences that matter to you before committing to a
            workflow or purchase.
          </p>
        </section>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
