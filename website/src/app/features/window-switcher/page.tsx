import Link from "next/link";

import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { showcaseAsset } from "@/content/showcase";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab macOS window switcher with live previews and global MRU";
const description =
  "CmdTab is a standalone macOS window-switcher app that replaces an app-only Command-Tab view with individual windows, exact-window recent-use ordering, previews, search, and quick actions.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Window switcher", path: "/features/window-switcher" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/features/window-switcher",
  image: "/showcase/overview-poster.webp",
  imageAlt: "CmdTab window-switcher product overview using controlled fixture windows",
  imageWidth: 720,
  imageHeight: 450,
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

const featureReferences = [
  {
    href: "/features/classic-grid",
    title: "Classic Grid",
    body: "Review the thumbnail-oriented mode, exact-window tile contract, preview fallback, and visual-scanning tradeoffs.",
  },
  {
    href: "/features/command-palette",
    title: "Command Palette",
    body: "Inspect local app and window text matching, acronym signals, stable ties, and bounded remembered-choice promotion.",
  },
  {
    href: "/features/radial-menu",
    title: "Radial Menu",
    body: "Understand the circular positional presentation, shared target sequence, and directional-selection limits.",
  },
  {
    href: "/features/quick-actions",
    title: "Quick Actions",
    body: "See which operations apply to an exact window or an application and how unavailable controls fail safely.",
  },
] as const;

export default function WindowSwitcherFeaturePage() {
  const overview = showcaseAsset("overview");

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
        title="A standalone CmdTab app that shows individual Mac windows"
        description="CmdTab is separate from Apple’s built-in Command-Tab shortcut. It is built for people who need to reach a specific window, not merely activate an application and search again."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date="2026-07-21" />
          <p className="text-sm text-subdued">Current project version: {productFacts.currentVersion}</p>
        </div>
        <ShowcaseVideo asset={overview} priority />
        <p className="mt-4 text-sm leading-7 text-subdued">
          The overview is a deterministic, non-AI product composite based on the current interface geometry and documented behavior contract. Controlled fixtures replace private desktop content.
        </p>
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
        description="These rules are also protected by automated regression tests."
        className="pt-0"
      >
        <div
          role="region"
          aria-label="CmdTab exact-window behavior reference"
          tabIndex={0}
          className="overflow-x-auto rounded-[24px] border border-white/10 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-cyan/60"
        >
          <table className="w-full min-w-[620px] border-collapse text-left text-sm">
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
      </SectionShell>

      <SectionShell
        eyebrow="Mode and action references"
        title="Go deeper without repeating the same landing page"
        description="Each page below answers a different user decision: visual scanning, text search, positional selection, or contextual window management."
        className="pt-0"
      >
        <div className="grid gap-5 md:grid-cols-2">
          {featureReferences.map((reference) => (
            <Link
              key={reference.href}
              href={reference.href}
              className="surface-panel group block h-full p-7 transition-transform duration-200 hover:-translate-y-0.5"
            >
              <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">{reference.title}</h2>
              <p className="mt-4 text-sm leading-7 text-muted">{reference.body}</p>
              <p className="mt-6 text-sm font-medium text-cyan group-hover:text-text">Open reference →</p>
            </Link>
          ))}
        </div>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button href="/showcase">Watch the full showcase</Button>
          <Button href="/waitlist" variant="secondary">Join the waitlist</Button>
          <Button href="/compare/cmdtab-vs-alttab" variant="secondary">
            Compare CmdTab with AltTab
          </Button>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
