from pathlib import Path

README = Path("README.md")
text = README.read_text(encoding="utf-8")

replacements = {
    "Last Updated: 2026-04-02": "Last Updated: 2026-07-20",
    "Active Task: App-side licensing flow with local trial enforcement, signed license activation, and direct buy/help entry points.": "Active Task: Competitive SEO/GEO hardening, production search verification, and external authority growth.",
    "The repo now also contains a standalone Next.js marketing site under `website/` for the private beta waitlist and public product story.": "The repo also contains a standalone Next.js product, commerce, documentation, analytics, and discovery site under `website/`.",
    "- The marketing site lives in `website/` and stays waitlist-only for private beta; there is still no checkout, testimonials, or public download flow in v1.": "- The product website lives in `website/` and supports public trial, buy, help, compatibility, permissions, privacy, security, factual guide, comparison, FAQ, and changelog routes without fake testimonials or unsupported claims.",
}

for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f"Expected README text not found: {old}")
    text = text.replace(old, new, 1)

status_marker = "\n## Active Constraints / Non-Negotiables\n"
status_block = """
- The website now uses one canonical public-route registry for the sitemap, IndexNow submissions, `llms.txt`, and SEO verification.
- Dedicated discovery pages now cover the core Mac window-switcher category, native window-switching guide, CmdTab-versus-macOS comparison, canonical FAQ, compatibility, permissions, privacy, About, and changelog intents.
- Public pages expose visible H1s, breadcrumbs, review dates, source links, current app version/build, minimum macOS, limitations, and matching WebPage/FAQ/Article/Breadcrumb structured data.
- The public privacy and permissions surfaces document the actual native-app telemetry cadence and fields, plus window titles, previews, screenshots, keystrokes, files, clipboard data, and search queries excluded from the current payload.
- First-party discovery analytics classify broad ChatGPT, Perplexity, Copilot, Gemini, Claude, Google, Bing, direct, and referral sessions without collecting prompts or search-query text.
- A private `/dashboard/discovery` view reports AI-assisted pageviews, visitors, sources, and landing pages while stating referrer-measurement limits.
- Next.js is on the patched `16.2.10` family and React / React DOM on `19.2.7`; the regenerated lockfile passed the high-severity production dependency audit.
- `npm run seo:check`, TypeScript, the production Webpack build, dependency audit, and patch-hygiene checks all passed on the specialist branch.
- CmdTab can exceed reviewed competitors in technical clarity, visible evidence, privacy specificity, source verifiability, and measurement; external ranking authority still requires downloads, independent reviews, backlinks, community discussion, and selective localization.
"""

if status_marker not in text:
    raise SystemExit("README status marker not found")
text = text.replace(status_marker, f"\n{status_block}{status_marker}", 1)

open_marker = "## Open Issues / Next Steps\n\n"
open_block = """- Merge the independent specialist PR into the primary SEO implementation only after final human-head security verification remains green.
- Deploy the final website and verify every canonical URL, sitemap entry, `robots.txt`, `llms.txt`, IndexNow key, metadata card, structured-data graph, redirect, and private-route `X-Robots-Tag` response in production.
- Verify `cmdtab.net` in Google Search Console and Bing Webmaster Tools, submit the sitemap, inspect each public route, and review their generative-AI / AI Performance reports where available.
- Configure `INDEXNOW_KEY` and submit only deployed, changed canonical pages through `npm run indexnow:submit`.
- Compare webmaster-platform evidence with `/dashboard/discovery`, Vercel Analytics, trial starts, and purchases; do not use citation screenshots as the sole GEO KPI.
- Provision monitored `support@cmdtab.net`, `privacy@cmdtab.net`, and `security@cmdtab.net` addresses before replacing the current personal contact email.
- Earn authority through a signed public release, original performance and activation evidence, independent reviews, editorial coverage, authentic user discussion, and evidence-led localization rather than synthetic testimonials or thin pages.
"""

if open_marker not in text:
    raise SystemExit("README open-issues marker not found")
text = text.replace(open_marker, f"{open_marker}{open_block}", 1)

recent_marker = "## Recent Changes Log\n\n"
recent_block = """- 2026-07-20: Added an independent competitor-informed SEO and GEO hardening pass.
  - Added authoritative window-switcher, Mac guide, native comparison, FAQ, compatibility, permissions, privacy, entity, and release content with visible review evidence and primary-source links.
  - Expanded the structured-data graph with Person, Organization, WebSite, SoftwareApplication, WebPage, TechArticle, FAQPage, Offer, and Breadcrumb relationships matching visible page content.
  - Published the actual website and native-app telemetry contract, added broad AI/search referral classification without prompt collection, and added a private AI-discovery dashboard.
  - Added a shared canonical-route registry, maintained sitemap dates, IndexNow support, canonical-only `llms.txt`, app-metadata alignment checks, and stronger build-breaking SEO/GEO invariants.
  - Regenerated the dependency lock at Next.js 16.2.10 and React 19.2.7, then passed SEO verification, TypeScript, production build, high-severity dependency audit, and `git diff --check`.
  - Recorded the honest authority boundary: code can improve clarity and verifiability, but backlinks, press, downloads, reviews, community demand, and localization must be earned through distribution.
"""

if recent_marker not in text:
    raise SystemExit("README recent-changes marker not found")
text = text.replace(recent_marker, f"{recent_marker}{recent_block}", 1)

README.write_text(text, encoding="utf-8")
