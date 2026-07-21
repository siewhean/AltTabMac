# CmdTab software-directory submission pack

**Prepared:** 2026-07-21  
**Purpose:** One maintained source for owner-operated software directory and launch-community listings.

This file is a preparation artifact. It does **not** claim that CmdTab has been submitted, approved, reviewed, or indexed by any external directory.

## Canonical identity

- **Product name:** CmdTab
- **Entity description:** CmdTab is a standalone native macOS window-switcher application. It is separate from Apple’s built-in Command-Tab shortcut.
- **Category:** macOS window switcher / productivity utility
- **Canonical website:** `https://cmdtab.net/`
- **Source repository:** `https://github.com/siewhean/AltTabMac`
- **Developer profile:** `https://github.com/siewhean`
- **Current public version:** 1.0.0 (build 1)
- **Minimum system:** macOS 13.0 Ventura or later
- **Trial:** 14 days
- **License:** One-time purchase
- **Current founder price:** US$12
- **Evidence page:** `https://cmdtab.net/evidence`
- **Privacy:** `https://cmdtab.net/privacy`
- **Permissions:** `https://cmdtab.net/permissions`
- **Compatibility:** `https://cmdtab.net/compatibility`
- **Changelog:** `https://cmdtab.net/changelog`

Do not add Apple Silicon, Intel, Universal Binary, RAM use, ScreenCaptureKit, reveal latency, or thumbnail-render claims until the release artifact or measured evidence proves them.

## Short descriptions

### 60 characters

Standalone macOS switcher for individual windows.

### 120 characters

CmdTab is a standalone Mac window switcher with individual previews, exact-window recency, search, and quick actions.

### 240 characters

CmdTab is a standalone macOS window-switcher app that represents eligible windows as separate recent-use targets. It includes Classic Grid, Command Palette, Radial Menu, live preview fallback, Quick Actions, and Space/display controls.

## Long description

CmdTab is a standalone native macOS window-switcher application designed for people who need to choose one exact window rather than activate an application and search again.

Eligible top-level windows remain separate targets in one global exact-window recent-use sequence, including multiple windows from the same application. CmdTab offers three presentation modes: Classic Grid for visual scanning, Command Palette for local application and window-title search, and Radial Menu for positional selection. Quick Actions can hide an app, minimize or close an exact window, or quit an app when the selected target exposes the required control.

Accessibility permission supports global shortcut handling, window inspection, exact-window focus, and window actions. Screen Recording permission enables live previews; if capture is unavailable, an otherwise eligible window remains represented with an icon or placeholder.

CmdTab publishes its current product contract, source-dated comparison pages, automated regression evidence, 136-case acceptance matrix, and explicit real-macOS manual-test boundary at cmdtab.net.

## Suggested categories and tags

Choose only categories offered by the destination directory.

- macOS utility
- window manager
- window switcher
- productivity
- keyboard utility
- application launcher alternative
- Command-Tab alternative
- window previews
- multi-monitor productivity
- quick window actions

Avoid describing CmdTab as a full tiling window manager, AI assistant, cloud search product, or ScreenCaptureKit application.

## Key differentiators

Use these as factual bullets rather than unsupported superiority claims:

- Separate targets for eligible windows, including multiple windows from the same app.
- One global exact-window recent-use sequence instead of application grouping.
- Classic Grid, Command Palette, and Radial Menu presentations.
- Local app and window-text matching with acronym signals and bounded remembered-choice promotion.
- Preview failure changes presentation, not eligible-window membership.
- Current Space, Visible Spaces, and All Spaces scope options.
- Active-window display, cursor display, and all-display placement options.
- Hide, minimize, close, and quit Quick Actions where supported.
- Public automated evidence plus a visible real-macOS manual-validation boundary.

## Required screenshots

Use current production or release screenshots only. Preserve truthful captions and avoid mock ratings or testimonials.

1. Hero / current switcher overview
2. Classic Grid
3. Command Palette
4. Radial Menu
5. Quick Actions
6. Permissions and first-run setup
7. Evidence ledger

Recommended source files are maintained under `website/public/screenshots/` and production verification artifacts.

## Directory-specific checklist

| Destination | Account/action required | Prepared category | Status | Notes |
| --- | --- | --- | --- | --- |
| AlternativeTo | Owner account; add product and request relevant alternative relationships | Productivity / window management | Not submitted | Link the canonical website, source repository, privacy page, and current license model. Do not claim an AltTab or Contexts relationship until the directory accepts it. |
| Product Hunt | Maker account; create launch page and schedule only after a signed public release exists | Mac productivity | Not submitted | Avoid launching a waitlist-only listing as if the downloadable release were generally available. |
| MacUpdate | Vendor account or submission form | Desktop enhancement / utilities | Not submitted | Provide the signed download URL, version, minimum macOS, release notes, and notarization status when available. |
| Softpedia | Vendor submission and downloadable build | System utilities / OS enhancements | Not submitted | Do not submit before a stable signed artifact and malware-scannable direct download exist. |
| StackShare | Account; add tool only if its taxonomy supports a desktop utility | Productivity tool | Not submitted | Do not force CmdTab into a software-development-stack category that misrepresents the product. |

## Community-launch boundary

Reddit, Hacker News, forums, and social communities are not backlink vending machines. Post only when there is a real release, a reproducible technical result, or a useful problem-solving write-up. Disclose the maker relationship. Do not manufacture user discussions, votes, testimonials, comparison comments, or review accounts.

## Source-dated competitor language

When a directory asks for alternatives or comparisons:

- Use `https://cmdtab.net/compare/mac-window-switchers` for the wider source-dated landscape.
- Use `https://cmdtab.net/compare/cmdtab-vs-alttab` for the focused AltTab comparison.
- Use `https://cmdtab.net/compare/cmdtab-vs-macos-command-tab` for the built-in shortcut comparison.
- Re-check prices, tiers, compatibility, download counts, and adoption figures after the displayed review date.
- Treat a missing external claim as unknown, not as proof that the competitor lacks a feature.

## Tracking convention

For links that allow campaign parameters, use a consistent source without collecting user query text:

```text
https://cmdtab.net/?utm_source=<directory>&utm_medium=software_directory&utm_campaign=public_release
```

Examples of source values:

- `alternativeto`
- `producthunt`
- `macupdate`
- `softpedia`
- `stackshare`

Use the canonical URL without tracking parameters in fields explicitly labeled homepage, canonical URL, website, or official site.

## Pre-submission release gate

Before changing any status from **Not submitted**:

1. Verify the current signed and notarized release.
2. Confirm the direct download and trial flows work on a clean Mac account.
3. Confirm version, build, minimum macOS, price, and trial terms match the website.
4. Confirm Accessibility and Screen Recording explanations match the shipped behavior.
5. Confirm privacy and telemetry disclosures match the release payload.
6. Capture current screenshots from the release or production website.
7. Save the external listing URL and submission date in this file.
8. Re-run the public production crawler and browser verification after adding any directory link back to the site.
