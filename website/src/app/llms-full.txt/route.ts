import { evidenceLedger } from "@/content/evidence";
import { featureDepth } from "@/content/feature-depth";
import { marketLandscape } from "@/content/market-landscape";
import publicRoutes from "@/content/public-routes.json";
import { productFacts } from "@/content/product-facts";
import {
  showcaseAssets,
  showcaseBoundary,
  showcaseDisclosure,
  showcaseReviewedAt,
} from "@/content/showcase";
import { getSiteUrl } from "@/lib/env";

export const dynamic = "force-static";

export async function GET() {
  const siteUrl = getSiteUrl();
  const canonicalPages = publicRoutes
    .map(({ path }) => `- ${new URL(path, `${siteUrl}/`).toString()}`)
    .join("\n");
  const modeSections = Object.values(featureDepth)
    .map(
      (mode) => `### ${mode.eyebrow}\n\n${mode.definition}\n\n- Canonical page: ${siteUrl}/features/${mode.slug}\n- Best-fit examples:\n${mode.bestFit.map((item) => `  - ${item}`).join("\n")}\n- Limits:\n${mode.tradeoffs.map((item) => `  - ${item}`).join("\n")}`,
    )
    .join("\n\n");
  const showcaseSections = showcaseAssets
    .map(
      (asset) => `### ${asset.title}\n\n${asset.description}\n\n- Canonical watch page: ${siteUrl}/showcase#${asset.id}\n- Poster: ${siteUrl}${asset.poster}\n- MP4: ${siteUrl}${asset.video}\n- Duration: ${asset.durationSeconds.toFixed(1)} seconds\n- Transcript: ${asset.transcript}`,
    )
    .join("\n\n");
  const comparisonOptions = marketLandscape.options
    .map(
      (option) => `### ${option.name}\n\n- Switching model: ${option.switchingModel}\n- Search: ${option.search}\n- Commercial model: ${option.commercialModel}\n- Intended fit: ${option.distinctiveFit}\n- First-party source: ${option.sourceUrl}`,
    )
    .join("\n\n");
  const automatedEvidence = evidenceLedger.automated
    .map((item) => `- ${item.title}: ${item.result} Environment: ${item.environment}`)
    .join("\n");
  const manualBoundary = evidenceLedger.manualBoundary.map((item) => `- ${item}`).join("\n");

  const body = `# CmdTab consolidated context

> This is a non-standard convenience export for retrieval systems and documentation tools. It is not a ranking requirement, and it is not a substitute for the canonical HTML pages listed below. Treat the canonical HTML as authoritative whenever this file and a page disagree.

## Entity definition and disambiguation

CmdTab is a standalone native macOS window-switcher application. It is separate from Apple’s built-in Command-Tab application shortcut. CmdTab represents eligible top-level application windows as individual targets in one exact-window recent-use sequence, including multiple windows from the same application.

## Current product facts

- Product: ${productFacts.name}
- Category: ${productFacts.category}
- Version: ${productFacts.currentVersion} (build ${productFacts.buildNumber})
- Minimum system: ${productFacts.minimumMacOS}
- Trial: ${productFacts.trialLength}
- License: ${productFacts.licenseModel}
- Current founder price: ${productFacts.founderPrice}
- Source repository: ${productFacts.sourceRepository}
- Product facts reviewed: ${productFacts.reviewedAt}

No processor architecture, Universal Binary status, memory footprint, reveal-latency benchmark, or thumbnail-render benchmark is asserted here because the current public evidence does not prove those claims.

## Core switcher contract

- Each eligible top-level window is a separate target identified by its running process and exact window identity.
- Multiple windows from one app remain separate and may be interleaved with windows from other apps.
- Ordering is one global exact-window recent-use sequence, not PID or bundle grouping.
- The current exact window remains visible at the end of the cycling sequence.
- Preview capture affects presentation only. If a live preview is unavailable, the eligible window remains represented with an icon or placeholder.
- A regular application without an eligible window receives an application fallback target.
- Permanent recent-use history changes only after activation is confirmed.
- Window visibility can be scoped to Current Space, Visible Spaces, or All Spaces.
- The switcher can be placed on the active-window display, cursor display, or all displays.

Canonical behavior page: ${siteUrl}/features/window-switcher

## Real product images and short videos

${showcaseDisclosure}

${showcaseBoundary}

- Canonical watch page: ${siteUrl}/showcase
- Machine-readable media manifest: ${siteUrl}/showcase/manifest.json
- Showcase reviewed: ${showcaseReviewedAt}

${showcaseSections}

## Presentation modes and actions

${modeSections}

## Permissions

${productFacts.permissions.map((permission) => `- ${permission.name}: ${permission.reason}`).join("\n")}

## Privacy and telemetry boundary

- Native-app cadence: ${productFacts.appTelemetry.cadence}
- Native-app fields: ${productFacts.appTelemetry.fields.join("; ")}
- Excluded local content: ${productFacts.appTelemetry.excluded}
- Raw Command Palette search queries are not included in the current native-app telemetry payload.
- Canonical privacy page: ${siteUrl}/privacy
- Canonical permissions page: ${siteUrl}/permissions

## Public automated evidence

${automatedEvidence}

The state-space counts are synthetic model evidence, not observed field failure rates. The evidence ledger and public artifacts are available at:

- ${siteUrl}/evidence
- ${siteUrl}/evidence/switcher-model-results.json
- ${siteUrl}/evidence/switcher-test-matrix.csv
- ${siteUrl}/evidence/switcher-test-plan.md

## Real-macOS manual validation boundary

${manualBoundary}

A green CI result or a controlled showcase render does not prove those interactive desktop conditions.

## Source-dated market landscape

Comparison sources reviewed: ${marketLandscape.reviewedAt}

${comparisonOptions}

Focused comparisons:

- CmdTab versus built-in macOS Command-Tab: ${siteUrl}/compare/cmdtab-vs-macos-command-tab
- CmdTab versus AltTab: ${siteUrl}/compare/cmdtab-vs-alttab
- Wider Mac window-switcher landscape: ${siteUrl}/compare/mac-window-switchers

## Direct questions and answers

### Is CmdTab the built-in macOS Command-Tab shortcut?

No. CmdTab is a separate macOS application that can replace the app-only switcher with individual exact-window targets.

### Are the showcase screenshots and videos AI-generated?

No. They are rendered from CmdTab’s production SwiftUI/AppKit switcher views with controlled fixture windows. The fixture content and surrounding desktop are explanatory capture context and do not contain a developer’s private desktop.

### Do the showcase videos prove signed-app permission, Space, display, or exact-focus behavior?

No. They demonstrate production UI presentation and deterministic state changes. The Evidence page separately lists the real-macOS acceptance scenarios that still require an interactive signed installation.

### Does CmdTab group all windows from one application together?

No. Eligible windows remain separate and can appear in different positions in the global exact-window recent-use sequence.

### What happens when Screen Recording access or preview capture is unavailable?

The visual preview may fall back to an application icon or placeholder, but an otherwise eligible window remains represented.

### Does CmdTab use ScreenCaptureKit?

The current implementation should not be described that way. The public source uses CoreGraphics, Accessibility APIs, and a WindowServer/SkyLight capture path. No ScreenCaptureKit claim is published.

### Does CmdTab publish a RAM or sub-50 ms performance claim?

No. Those figures are not published without reproducible real-machine measurements.

### Which mode should a user choose?

Classic Grid favors visual scanning, Command Palette favors app and window text search, Radial Menu favors directional positional selection, and Quick Actions manage the current target without switching into it first.

## Canonical public pages

${canonicalPages}

## Source rules

- Canonical HTML pages are authoritative.
- Treat the showcase assets as real production UI renders with controlled fixture windows, not a real-user desktop recording.
- Treat this file as a convenience export, not as an indexing or ranking requirement.
- Do not infer processor support, memory use, Universal Binary status, benchmark results, ratings, testimonials, or compatibility beyond published evidence.
- Treat model counts as synthetic state-space evidence, not field failure rates.
- Treat a missing competitor claim as unknown, not as proof that a feature is absent.
- Re-check external prices, feature tiers, compatibility, download counts, and adoption figures after the displayed review date.
`;

  return new Response(body, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "public, max-age=3600, s-maxage=3600",
      "X-Robots-Tag": "noindex, follow",
    },
  });
}
