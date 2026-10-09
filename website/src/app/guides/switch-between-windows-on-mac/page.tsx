import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createArticleStructuredData,
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "How to switch between windows on a Mac";
const description =
  "A practical guide to Command-Tab, Command-`, Mission Control, and CmdTab, explaining which Mac window-switching method fits applications, same-app windows, previews, Spaces, and search.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Switch between windows on Mac", path: "/guides/switch-between-windows-on-mac" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/guides/switch-between-windows-on-mac",
  imageAlt: "Guide to switching between applications and individual windows on a Mac",
});

const methods = [
  {
    shortcut: "Command-Tab",
    title: "Switch between open applications",
    body: "Hold Command and press Tab to move through open applications. Release Command when the application you want is selected. This is the quickest built-in method when app-level switching is enough.",
  },
  {
    shortcut: "Command-`",
    title: "Cycle windows in the current application",
    body: "Hold Command and press the grave-accent key repeatedly to cycle through windows belonging to the current application. This is useful after the correct app is already active.",
  },
  {
    shortcut: "Control-Up Arrow",
    title: "Use Mission Control for a visual overview",
    body: "Mission Control displays open windows and Spaces so you can choose visually. It is useful for orientation, but it temporarily takes over the screen rather than acting like a compact keyboard switcher.",
  },
  {
    shortcut: "CmdTab",
    title: "Use one list of individual windows",
    body: "CmdTab replaces the app-only switcher with separate eligible windows, exact-window recent-use ordering, previews, search, and configurable Space and display scope.",
  },
] as const;

const decisionRows = [
  ["I only need to move to another app", "Use macOS Command-Tab"],
  ["I am already in the right app and need its next window", "Use Command-`"],
  ["I need to inspect all visible windows and Spaces", "Use Mission Control"],
  ["I want one ordered list of exact windows across apps", "Use CmdTab"],
  ["I know part of the app or window title", "Use CmdTab Command Palette"],
] as const;

export default function SwitchWindowsGuidePage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/guides/switch-between-windows-on-mac",
        })}
      />
      <JsonLd
        data={createArticleStructuredData({
          headline: title,
          description,
          path: "/guides/switch-between-windows-on-mac",
          about: ["macOS keyboard shortcuts", "Mac windows", "Mission Control", "CmdTab"],
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Mac guide"
        title="How to switch between windows on a Mac"
        description="The right method depends on whether you are choosing an application, another window in the current app, a visual Space, or one exact window from everything open."
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date={productFacts.reviewedAt} />
        </div>
        <div className="surface-panel p-7">
          <p className="text-lg leading-8 text-text">
            The built-in Command-Tab shortcut cycles applications, while Command-` cycles windows in the current application. Mission Control provides a visual overview. CmdTab is an optional third-party path when you want individual windows from different apps in one searchable recent-use sequence.
          </p>
        </div>
        <div className="surface-panel mt-6 flex flex-col gap-5 p-7 sm:flex-row sm:items-center sm:justify-between">
          <div className="max-w-2xl">
            <h2 className="text-xl font-medium tracking-[-0.03em] text-text">
              Need to find one exact window?
            </h2>
            <p className="mt-2 text-sm leading-7 text-muted">
              CmdTab puts eligible windows in a searchable, recent-use list. It is in private preview; request access and we’ll email you when it opens.
            </p>
          </div>
          <Button
            href="/trial?utm_source=switch_guide&utm_medium=organic_search&utm_campaign=waitlist_1000_30d&utm_content=guide_intro_cta"
            className="shrink-0"
          >
            Join the private-preview waitlist
          </Button>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Four methods"
        title="Choose the smallest tool that solves the problem"
        className="pt-0"
      >
        <div className="grid gap-5 lg:grid-cols-2">
          {methods.map((method) => (
            <article key={method.shortcut} className="surface-panel p-7">
              <p className="type-eyebrow text-cyan">{method.shortcut}</p>
              <h2 className="mt-4 text-2xl font-medium tracking-[-0.04em] text-text">
                {method.title}
              </h2>
              <p className="mt-4 text-base leading-8 text-muted">{method.body}</p>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Decision table"
        title="Match the shortcut to your intent"
        className="pt-0"
      >
        <div className="overflow-hidden rounded-[24px] border border-white/10">
          <table className="w-full border-collapse text-left text-sm">
            <thead className="bg-white/[0.05] text-text">
              <tr>
                <th className="px-5 py-4 font-medium">What you need</th>
                <th className="px-5 py-4 font-medium">Best starting method</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/8 bg-white/[0.02]">
              {decisionRows.map(([need, method]) => (
                <tr key={need}>
                  <th scope="row" className="px-5 py-4 font-medium text-text">
                    {need}
                  </th>
                  <td className="px-5 py-4 leading-7 text-muted">{method}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button href="/compare/cmdtab-vs-macos-command-tab">See the detailed comparison</Button>
          <Button href="/features/window-switcher" variant="secondary">
            Review CmdTab behavior
          </Button>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Primary sources"
        title="Apple documentation used for native behavior"
        className="pt-0"
      >
        <ul className="space-y-3 text-base leading-8 text-muted">
          <li>
            <a
              className="text-cyan underline underline-offset-4 hover:text-text"
              href="https://support.apple.com/guide/mac-help/mchlb7beb9af/mac"
              target="_blank"
              rel="noreferrer"
            >
              Apple Support: See all your open windows on Mac
            </a>
          </li>
          <li>
            <a
              className="text-cyan underline underline-offset-4 hover:text-text"
              href="https://support.apple.com/guide/mac-help/mh35798/mac"
              target="_blank"
              rel="noreferrer"
            >
              Apple Support: View open windows and Spaces in Mission Control
            </a>
          </li>
          <li>
            <a
              className="text-cyan underline underline-offset-4 hover:text-text"
              href="https://support.apple.com/guide/mac-help/mh14112/mac"
              target="_blank"
              rel="noreferrer"
            >
              Apple Support: Work in multiple Spaces on Mac
            </a>
          </li>
        </ul>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
