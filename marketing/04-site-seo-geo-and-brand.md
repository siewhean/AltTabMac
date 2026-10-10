# CmdTab — Website conversion, SEO/GEO, brand kit

## A. Must-fix before spending (each is small, high-leverage)
1. **Enable Vercel Web Analytics** (currently 404). Then compare against first-party table.
2. **Persist attribution on waitlist rows.** All 5 rows have `metadata: null`. `collectWaitlistAttribution()` returns nothing unless analytics consent is true. Store campaign params (`utm_*`) and the landing path in a first-party cookie/session *before* consent for the narrow purpose of attributing a voluntary signup, or accept consent-gated loss. Decide with your privacy policy; I did not change this.
3. **Waitlist form is not above the fold on every path.** `/trial` (90 pv) and `/buy` (54 pv) are the #2 and #3 pages: people looking for a download hit a page that can't deliver. Make both pages lead with "Private beta — join the list" and the form, and say honestly when the first beta wave opens.
4. **Success state = growth loop.** After signup show: reward progress (N of 5 friends counted), referral link, X/WhatsApp/Telegram/WeChat share, "try the demo".
5. **Cross-post proof:** add the "side-by-side Cmd+Tab vs CmdTab" 12-sec video to the hero (poster-first, lazy video).
6. **Keep one primary CTA** on `/`: "Join the private beta". Hero currently has primary + secondary + tertiary (3 CTAs). Test removing the tertiary.
7. Remove/adjust nav item "Buy" while commerce is disabled; replace with "Beta".

## B. Copy upgrades (drop-in)
**Hero**
- Eyebrow: Private beta · macOS 14+
- H1 (replace "Find the right Mac window in one move."): **Cmd+Tab switches apps. CmdTab switches windows.**
- Sub: Every window is its own target, with a real preview. Type to find it, flick to it, or close it without opening it.
- Primary CTA: **Join the private beta** · Secondary: **Try it in your browser**
- Under-form microcopy: "No spam. First access in waves. Needs Accessibility + Screen Recording — here's why."
**Alt H1 test:** "You don't have 6 apps open. You have 6 Chrome windows."
**Section order (test):** Hero → 12-sec demo video → interactive demo → three modes → quick actions → honesty block (permissions, telemetry, pricing plan) → FAQ → form.
**Honesty block (differentiator):** "What we ask for · What we never collect · What it will cost" as a 3-column strip. Trust beats hype for system-level apps.
**Waitlist heading:** "Be first when the beta opens" · button "Save my spot" · after: "Invite 5 friends, get CmdTab free."

## C. SEO/GEO — 10 pages, ship 1 every 2 days
Each = one question a Mac user types or asks an AI, answered directly in the first 80 words, then depth, FAQ schema, and a CTA. Run `npm run seo:check` and `npm run retrieval:check` per `SEO-GEO.md`.
| # | URL | Target query |
|---|---|---|
| 1 | /guides/switch-between-windows-on-mac | (exists — refresh, add shortcut table) |
| 2 | /guides/cmd-backtick-not-working-mac | "cmd ` not working mac" |
| 3 | /guides/mac-switch-windows-same-app | "switch between windows of same app mac" |
| 4 | /compare/cmdtab-vs-alttab | "alt tab mac vs …" (fair, dated, first-party sources only, per policy) |
| 5 | /compare/cmdtab-vs-contexts | "contexts vs alttab" |
| 6 | /guides/mac-window-switcher-for-developers | "mac window switcher developers" |
| 7 | /guides/multiple-monitors-mac-window-switching | "switch windows multiple displays mac" |
| 8 | /guides/mac-keyboard-shortcuts-window-management | "mac window management shortcuts" |
| 9 | /guides/accessibility-screen-recording-permission-mac | "why does app need screen recording mac" |
| 10 | /guides/reduce-window-clutter-mac | "too many windows open mac" |

**GEO (ChatGPT already sent 13 visitors — protect and grow this):**
- Keep `llms.txt` current; add a plain-language "What is CmdTab" paragraph + facts table to `/` (already exists via `product-facts.ts` — surface it visibly).
- Publish an `/about` with the founder name, location, repo link (E-E-A-T).
- Answer-ready snippets (copy into FAQ):
  - *What is CmdTab?* — "CmdTab is a native macOS window switcher that treats each window as its own target, with previews, command-palette search, and quick actions."
  - *How is it different from Cmd+Tab?* — "macOS Cmd+Tab switches apps. CmdTab lists individual windows."
  - *Is it free?* — "Planned: 14-day trial then US$12 one-time for up to three Macs. Currently in private beta." *(re-verify price at publish)*
  - *What permissions?* — "Accessibility and Screen Recording; both are explained in-app and on /permissions."
- Weekly: ask ChatGPT, Perplexity, Gemini, Claude the same 10 prompts; log citation yes/no in a sheet. Add pages for any prompt where a competitor is cited and CmdTab isn't.
- Earn citations: AlternativeTo listing, GitHub README link, 少数派/V2EX posts, dev.to article, Hacker News thread.

## D. Brand kit
- **Name:** CmdTab (one word, capital C & T). Never "CMDTab" or "Cmd-Tab".
- **Promise:** "Switch windows, not just apps."
- **Personality:** precise, calm, keyboard-native, honest. Not hyped.
- **Voice rules:** short sentences; verbs first; say the permission cost out loud; no superlatives we can't prove ("fastest", "best", "sub-50 ms" banned).
- **Taglines (test):** 1) "Cmd+Tab, but for windows." 2) "Every window. One keystroke." 3) "Stop guessing which window."
- **Palette (matches current site):** near-black `#05070C`, deep navy `#08111D`, cyan accent (~`#69D6FF`), white text at 92%/60%. Keep one accent.
- **Typography:** current site stack; for social use a bold grotesk (Inter Tight / SF-like) for headlines, tabular figures for counters.
- **Social templates (Canva):** 1) Pain meme "6 Chrome windows" 2) Split Cmd+Tab vs CmdTab 3) Feature card (mode name + 5-word benefit) 4) Milestone card "N of 1,000" (true numbers only) 5) Founder quote card.
- **OG image:** replace overview poster with the side-by-side still plus the H1.

## E. Social proof without lying
- Real counters ("N on the list"), real replies (screenshots with permission), real quotes from beta users, real GitHub activity ("340+ automated tests"), real dated changelog.
- Never: fake logos, fake reviews, invented "trusted by" claims, unverified benchmarks.
