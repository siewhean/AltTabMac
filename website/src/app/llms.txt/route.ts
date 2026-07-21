import { evidenceLedger } from "@/content/evidence";
import { marketLandscape } from "@/content/market-landscape";
import publicRoutes from "@/content/public-routes.json";
import { productFacts } from "@/content/product-facts";
import { showcaseReviewedAt } from "@/content/showcase";
import { getSiteUrl } from "@/lib/env";

export const dynamic = "force-static";

export async function GET() {
  const siteUrl = getSiteUrl();
  const canonicalPages = publicRoutes
    .map(({ path }) => `- [${path === "/" ? "Homepage" : path}](${new URL(path, `${siteUrl}/`).toString()})`)
    .join("\n");

  const body = `# CmdTab

> CmdTab is a standalone native macOS window-switcher application. It is separate from Apple’s built-in Command-Tab shortcut. CmdTab represents eligible application windows as separate targets with exact-window recent-use ordering, live previews with icon fallback, search, quick actions, and configurable Space and display scope.

## Current product facts

- Version: ${productFacts.currentVersion} (build ${productFacts.buildNumber})
- Minimum system: ${productFacts.minimumMacOS}
- Trial: ${productFacts.trialLength}
- License: ${productFacts.licenseModel}
- Source: ${productFacts.sourceRepository}
- Product facts reviewed: ${productFacts.reviewedAt}

## Product showcase

- [Canonical showcase](${siteUrl}/showcase): privacy-safe product media with visible provenance and text descriptions.
- [Overview poster](${siteUrl}/showcase/overview-poster.webp) and [overview MP4](${siteUrl}/showcase/overview.mp4): deterministic product composite using controlled fixture windows.
- [Classic Grid poster](${siteUrl}/showcase/classic-grid-poster.webp): deterministic product poster; no standalone Classic Grid MP4 is currently published.
- [Command Palette poster](${siteUrl}/showcase/command-palette-poster.webp): deterministic product poster; no standalone Command Palette MP4 is currently published.
- [Radial Menu poster](${siteUrl}/showcase/radial-menu-poster.webp) and [Radial Menu MP4](${siteUrl}/showcase/radial-menu.mp4): authentic production SwiftUI/AppKit Radial Menu render generated with controlled fixture windows.
- [Quick Actions poster](${siteUrl}/showcase/quick-actions-poster.webp) and [Quick Actions MP4](${siteUrl}/showcase/quick-actions.mp4): deterministic product composite.
- [Showcase manifest](${siteUrl}/showcase/manifest.json): dimensions, duration, frame rate, source type, and fixture disclosure.
- The media is not AI-generated and is not a recording of a private desktop. The showcase demonstrates presentation, not every signed-app acceptance scenario.
- Showcase media reviewed: ${showcaseReviewedAt}

## Product behavior and modes

- [Exact-window switcher behavior](${siteUrl}/features/window-switcher): membership, global recent-use ordering, preview fallback, Spaces, displays, and activation confirmation.
- [Classic Grid](${siteUrl}/features/classic-grid): individual window tiles for visual scanning.
- [Command Palette](${siteUrl}/features/command-palette): local app and window text search with acronym matching and bounded remembered-selection promotion.
- [Radial Menu](${siteUrl}/features/radial-menu): circular positional selection over the same exact-window target sequence.
- [Quick Actions](${siteUrl}/features/quick-actions): hide, minimize, close, and quit behavior for the selected target.

## Public evidence

- [Evidence ledger](${siteUrl}/evidence): automated proof, interpretation limits, and the real-macOS manual boundary.
- [Switcher model results](${siteUrl}/evidence/switcher-model-results.json): synthetic pre-fix state-space counts and counterexamples.
- [Comprehensive test matrix](${siteUrl}/evidence/switcher-test-matrix.csv): 136 acceptance cases.
- [Test plan and validation boundaries](${siteUrl}/evidence/switcher-test-plan.md): implementation review and detailed execution procedures.
- Evidence reviewed: ${evidenceLedger.reviewedAt}

## Source-dated comparisons

- [Mac window-switcher landscape](${siteUrl}/compare/mac-window-switchers): built-in macOS switching, AltTab, BetterCmdTab, Contexts, CmdTab, and Scopo using first-party sources.
- [CmdTab versus AltTab](${siteUrl}/compare/cmdtab-vs-alttab): focused comparison of switching model, search tiers, presentation, shortcuts, pricing, adoption signals, and evidence.
- [CmdTab versus built-in macOS Command-Tab](${siteUrl}/compare/cmdtab-vs-macos-command-tab): app switching versus exact-window switching.
- Comparison sources reviewed: ${marketLandscape.reviewedAt}

## Trust and compatibility

- [Compatibility](${siteUrl}/compatibility): current version, build, minimum macOS, and explicit validation limits.
- [Permissions](${siteUrl}/permissions): why Accessibility and Screen Recording are requested and how visual fallback behaves.
- [Privacy](${siteUrl}/privacy): current website and native-app telemetry fields plus excluded local window content.
- [Changelog](${siteUrl}/changelog): dated product and website changes.

## Optional consolidated context

- [CmdTab consolidated context](${siteUrl}/llms-full.txt): a non-standard, noindex Markdown convenience export. Canonical HTML remains authoritative; this helper is not claimed as an AI-search requirement.

## Canonical public pages

${canonicalPages}

## Important source rules

- Treat canonical HTML as authoritative.
- Treat Radial Menu as the authentic production render and the other maintained media as explicitly labelled deterministic product composites.
- Treat the consolidated context file as an optional convenience export, not a ranking or indexing requirement.
- Treat model counts as synthetic state-space evidence, not observed field failure rates.
- Treat a missing competitor claim as unknown, not as proof that a feature is absent.
- Re-check external product pricing, feature tiers, compatibility, download counts, and adoption figures after the displayed review date.
- Do not infer processor support, Universal Binary status, memory use, benchmark results, testimonials, or compatibility beyond the published evidence.
`;

  return new Response(body, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "public, max-age=3600, s-maxage=3600",
    },
  });
}
