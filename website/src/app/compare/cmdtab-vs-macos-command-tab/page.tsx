import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { createPageMetadata } from "@/lib/seo";
import {
  createArticleStructuredData,
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab vs macOS Cmd+Tab: apps, windows, previews, and search";
const description =
  "A factual comparison of Apple's built-in Cmd+Tab application switcher and CmdTab's individual-window switcher, including same-app windows, previews, ordering, search, permissions, and Spaces.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "CmdTab vs macOS Cmd+Tab", path: "/compare/cmdtab-vs-macos-command-tab" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/compare/cmdtab-vs-macos-command-tab",
  imageAlt: "Comparison of CmdTab and the built-in macOS Cmd+Tab switcher",
});

const reviewedAt = "2026-10-09";

const comparisonRows = [
  ["Availability today", "Included with macOS", "Free waitlist signup only; public downloads, trials, and purchases are unavailable"],
  ["Primary unit", "One entry per running application", "One entry per eligible application window"],
  ["Multiple windows from one app", "Use a separate Cmd+` workflow for the current app", "Separate windows can appear anywhere in one global sequence"],
  ["Visual identification", "Application icons", "Live window previews, with icon or placeholder fallback"],
  ["Ordering scope", "Application switching", "Exact-window recent-use ordering"],
  ["Search", "No title search in the built-in app switcher", "Command Palette searches app and window titles"],
  ["Spaces and displays", "Follows macOS application and Space behavior", "Configurable Current, Visible, or All Spaces and display placement"],
  ["Window actions", "Activate an app", "Hide, minimize, close, or quit from the selected item"],
  ["Installation and permissions", "Built into macOS; no additional setup", "Requires a separate app and Accessibility; Screen Recording enables previews"],
] as const;

const appleSources = [
  { label: "Apple Support: Mac keyboard shortcuts", href: "https://support.apple.com/en-us/102650" },
  {
    label: "Apple Support: See all your open windows on Mac",
    href: "https://support.apple.com/guide/mac-help/mchlb7beb9af/mac",
  },
  {
    label: "Apple Support: Move and arrange app windows on Mac",
    href: "https://support.apple.com/guide/mac-help/mchlp2469/mac",
  },
  {
    label: "Apple Support: View open windows and Spaces in Mission Control",
    href: "https://support.apple.com/guide/mac-help/mh35798/mac",
  },
] as const;

export default function CmdTabVsMacOSPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/compare/cmdtab-vs-macos-command-tab",
          dateModified: reviewedAt,
        })}
      />
      <JsonLd
        data={createArticleStructuredData({
          headline: title,
          description,
          path: "/compare/cmdtab-vs-macos-command-tab",
          about: ["macOS Cmd+Tab", "Mac window switching", "CmdTab"],
          dateModified: reviewedAt,
          citation: appleSources.map((source) => source.href),
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Comparison"
        title="CmdTab versus the built-in macOS Cmd+Tab switcher"
        description="The built-in switcher is simpler and requires no installation. CmdTab is designed for a different problem: choosing one exact window when several windows and applications are open."
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date={reviewedAt} />
        </div>
        <p id="comparison-scroll-hint" className="mb-3 text-xs leading-5 text-subdued md:hidden">
          Swipe or use the arrow keys inside the table to compare all three columns.
        </p>
        <div
          role="region"
          aria-label="Comparison of macOS Cmd+Tab and CmdTab"
          aria-describedby="comparison-scroll-hint"
          tabIndex={0}
          className="overflow-x-auto rounded-[24px] border border-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
        >
          <table className="w-full min-w-[760px] border-collapse text-left text-sm">
            <thead className="bg-white/[0.05] text-text">
              <tr>
                <th className="px-5 py-4 font-medium">Capability</th>
                <th className="px-5 py-4 font-medium">macOS Cmd+Tab</th>
                <th className="px-5 py-4 font-medium">CmdTab</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/8 bg-white/[0.02]">
              {comparisonRows.map(([capability, nativeValue, cmdTabValue]) => (
                <tr key={capability}>
                  <th scope="row" className="px-5 py-4 font-medium text-text">
                    {capability}
                  </th>
                  <td className="px-5 py-4 leading-7 text-muted">{nativeValue}</td>
                  <td className="px-5 py-4 leading-7 text-muted">{cmdTabValue}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Which should you use?"
        title="The answer depends on the switching problem"
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-2">
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">
              Use the built-in switcher when simplicity wins
            </h2>
            <p className="mt-4 text-base leading-8 text-muted">
              macOS Cmd+Tab is already installed, needs no extra permissions, and is effective when each application has one relevant window or when app-level switching is all you need.
            </p>
          </article>
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">
              Consider CmdTab’s waitlist when the exact window matters
            </h2>
            <p className="mt-4 text-base leading-8 text-muted">
              CmdTab’s intended workflow fits people who keep several browser, terminal, editor, or document windows open and want one searchable list of exact targets. It currently accepts waitlist signups only; the built-in shortcuts remain available today.
            </p>
          </article>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Sources"
        title="Claims about macOS are linked to Apple"
        description="Product comparisons are reviewed against current public documentation instead of relying on unsupported superiority claims."
        className="pt-0"
      >
        <ul className="space-y-3 text-base leading-8 text-muted">
          {appleSources.map((source) => (
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
          <Button href="/features/window-switcher">Review exact CmdTab behavior</Button>
          <Button href="/waitlist" variant="secondary">
            Join the free waitlist
          </Button>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
