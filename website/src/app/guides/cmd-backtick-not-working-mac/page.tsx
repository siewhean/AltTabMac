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

const title = "Command+` Not Working on Mac? Try These Checks";
const description =
  "If Command+` will not switch Mac windows, check that the right app is active, confirm the grave-accent key for your keyboard layout, and look for a conflicting keyboard shortcut.";
const path = "/guides/cmd-backtick-not-working-mac";
const appleKeyboardShortcuts = "https://support.apple.com/en-au/102650";
const appleWindowGuide = "https://support.apple.com/en-nz/guide/mac-help/mchlb7beb9af/mac";
const appleConflictingShortcuts = "https://support.apple.com/en-hk/guide/mac-help/mchlp2864/mac";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Window switching guide", path: "/guides/switch-between-windows-on-mac" as const },
  { name: "Command+` not working", path: path as "/guides/cmd-backtick-not-working-mac" },
];

export const metadata = createPageMetadata({
  title,
  description,
  path,
  imageAlt: "Troubleshooting guide for the Mac Command+grave window-switching shortcut",
});

export default function CommandBacktickTroubleshootingPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path,
          dateModified: "2026-10-12",
        })}
      />
      <JsonLd
        data={createArticleStructuredData({
          headline: title,
          description,
          path,
          datePublished: "2026-10-12",
          dateModified: "2026-10-12",
          about: ["Mac keyboard shortcuts", "Command-grave accent", "Mac app windows"],
          citation: [appleKeyboardShortcuts, appleWindowGuide, appleConflictingShortcuts],
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Mac shortcut help"
        title="Command+` not working on your Mac?"
        description="Command+` moves between windows in the frontmost app. If nothing happens, check which app is active, which key produces a grave accent on your keyboard, and whether another keyboard shortcut uses it."
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date="2026-10-12" />
        </div>
        <section aria-labelledby="quick-checks" className="surface-panel p-7">
          <h2 id="quick-checks" className="text-2xl font-medium tracking-[-0.04em] text-text">
            Try these checks in order
          </h2>
          <ol className="mt-5 space-y-5 text-base leading-8 text-muted">
            <li>
              <strong className="text-text">1. Bring the app you want to the front.</strong>{" "}
              Command+` cycles windows in the current app. First click or switch to the app, then
              press Command and the key that types a grave accent (`) on your keyboard.
            </li>
            <li>
              <strong className="text-text">2. Check your keyboard layout.</strong>{" "}
              Apple notes that the grave-accent key is commonly above Tab and to the left of 1,
              but its position or character can vary by keyboard and input source. Use the key
              that produces ` for your active layout rather than relying only on its label.
            </li>
            <li>
              <strong className="text-text">3. Check for a shortcut conflict.</strong>{" "}
              Review System Settings → Keyboard → Keyboard Shortcuts. Apple shows a warning icon
              beside conflicting shortcuts; if you see one, change the assignment and try again.
              The exact category depends on which shortcut is in conflict.
            </li>
            <li>
              <strong className="text-text">4. Confirm these are separate windows.</strong>{" "}
              Command+` switches app windows; it does not move between tabs inside one window.
              If you are trying to reach another browser tab, use the browser’s tab shortcut or
              tab overview instead.
            </li>
          </ol>
        </section>
      </SectionShell>

      <SectionShell eyebrow="What the shortcut covers" title="It stays within one app" className="pt-0">
        <p className="max-w-3xl text-base leading-8 text-muted">
          Once the right app is active, Command+` is the built-in way to cycle through that app’s
          open windows. To switch between apps, use Command-Tab. For Apple’s overview of open
          windows and Spaces, see{" "}
          <a
            className="text-cyan underline underline-offset-4 hover:text-text"
            href={appleWindowGuide}
            target="_blank"
            rel="noreferrer"
          >
            Apple Support’s window guide
          </a>
          .
        </p>
        <p className="mt-5 max-w-3xl text-base leading-8 text-muted">
          If you regularly reach the right app but still have to cycle through many windows to
          find one exact window, CmdTab is an optional private preview designed for that search.
          You can also read our broader{" "}
          <a
            className="ml-1 text-cyan underline underline-offset-4 hover:text-text"
            href="/guides/switch-between-windows-on-mac"
          >
            switching between windows on Mac
          </a>
          .
        </p>
      </SectionShell>

      <SectionShell
        eyebrow="Private preview"
        title="Still hunting for the window you meant?"
        description="If this is a regular part of your Mac workflow, request access to the CmdTab private beta."
        className="pt-0"
      >
        <Button href="/waitlist?utm_source=organic_search&utm_medium=guide&utm_campaign=waitlist_1000_30d&utm_content=backtick_guide_cta">
          Request private-beta access
        </Button>
      </SectionShell>

      <SectionShell eyebrow="Apple reference" title="Shortcut details from Apple" className="pt-0">
        <a
          className="text-cyan underline underline-offset-4 hover:text-text"
          href={appleKeyboardShortcuts}
          target="_blank"
          rel="noreferrer"
        >
          Mac keyboard shortcuts — Apple Support
        </a>
        <p className="mt-3 text-sm leading-7 text-muted">
          For conflict indicators and reassignment steps, see{" "}
          <a
            className="text-cyan underline underline-offset-4 hover:text-text"
            href={appleConflictingShortcuts}
            target="_blank"
            rel="noreferrer"
          >
            Apple’s guide to changing a conflicting shortcut
          </a>
          .
        </p>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
