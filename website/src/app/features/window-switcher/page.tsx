import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "Mac window switcher with live previews and global MRU";
const description =
  "CmdTab replaces an app-only Cmd+Tab view with individual Mac windows, exact-window recent-use ordering, live previews, search, quick actions, and Space-aware filtering.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Window switcher", path: "/features/window-switcher" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/features/window-switcher",
  imageAlt: "CmdTab showing individual Mac windows with live previews",
});

const steps = [
  {
    title: "Press Cmd+Tab or the configured trigger",
    body: "CmdTab intercepts the switcher shortcut and opens the current exact-window sequence instead of presenting one icon for each application.",
  },
  {
    title: "See individual eligible windows",
    body: "Two windows from the same app remain separate entries. They can appear in different positions because ordering follows window focus history rather than an app group.",
  },
  {
    title: "Choose by preview, search, or position",
    body: "Use Classic Grid for visual scanning, Command Palette for title and app search, or Radial Menu for directional selection.",
  },
  {
    title: "Release or confirm to focus the target",
    body: "CmdTab attempts to focus the selected exact window. Permanent recent-use history is updated only after activation is confirmed.",
  },
] as const;

const behaviorRows = [
  ["Multiple windows from one app", "Separate exact-window entries"],
  ["Ordering", "One global recent-use sequence, not PID or bundle grouping"],
  ["Current window", "Remains visible at the end of the cycling order"],
  ["Preview failure", "Window stays visible with an icon or placeholder"],
  ["Spaces", "Current Space, Visible Spaces, or All Spaces"],
  ["Displays", "Active-window display, cursor display, or all displays"],
  ["Actions", "Hide, minimize, close, or quit the selected item"],
] as const;

export default function WindowSwitcherFeaturePage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/features/window-switcher",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Window switcher"
        title="A Cmd+Tab switcher that shows individual Mac windows"
        description="CmdTab is a native macOS window switcher built for people who need to reach a specific window, not merely activate an application and then search again."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} />
          <p className="text-sm text-subdued">Current project version: {productFacts.currentVersion}</p>
        </div>
        <ScreenshotFrame assetId="classicGrid" caption="Classic Grid keeps each eligible window visible as its own target." priority />
      </SectionShell>

      <SectionShell
        eyebrow="How it works"
        title="One sequence from shortcut to exact window"
        description="The behavior below describes the current implementation rather than an aspirational marketing flow."
        className="pt-0"
      >
        <ol className="grid gap-5 lg:grid-cols-2">
          {steps.map((step, index) => (
            <li key={step.title} className="surface-panel p-7">
              <p className="type-eyebrow text-cyan">Step {index + 1}</p>
              <h2 className="mt-4 text-2xl font-medium tracking-[-0.04em] text-text">
                {step.title}
              </h2>
              <p className="mt-4 text-base leading-8 text-muted">{step.body}</p>
            </li>
          ))}
        </ol>
      </SectionShell>

      <SectionShell
        eyebrow="Behavior reference"
        title="The important details are explicit"
        description="These rules are also protected by automated regression tests in the public repository."
        className="pt-0"
      >
        <div className="overflow-hidden rounded-[24px] border border-white/10">
          <table className="w-full border-collapse text-left text-sm">
            <thead className="bg-white/[0.05] text-text">
              <tr>
                <th className="px-5 py-4 font-medium">Question</th>
                <th className="px-5 py-4 font-medium">CmdTab behavior</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/8 bg-white/[0.02]">
              {behaviorRows.map(([label, value]) => (
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
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button href="/trial">Start the 14-day trial</Button>
          <Button href="/compare/cmdtab-vs-macos-command-tab" variant="secondary">
            Compare with macOS Cmd+Tab
          </Button>
          <Button href={productFacts.sourceRepository} target="_blank" rel="noreferrer" variant="ghost">
            Review the source
          </Button>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
