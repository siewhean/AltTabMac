# CmdTab — Diagnosis + 30-Day Waitlist Sprint (goal: 1,000 real signups)

> **Corrected 2026-10-10 — read `06-marketing-report.md` first.** Show HN does not accept sign-up/waitlist pages, r/macapps now restricts developer promotion, and Resend open/click tracking is off. Where this file disagrees with the report, the report wins.

Data pulled 2026-10-10 from the production Postgres (`site_analytics_events`, `waitlist_signups`). Vercel Web Analytics is **not enabled** (API returns 404), so the first-party tables are the only source. They only record visitors who accepted analytics consent, so true traffic is somewhat higher than shown.

## 1. What the data says (no sugar)

| Metric | Value |
|---|---|
| Waitlist rows | **5, all test data** (4 tagged `e2e_verification_test` / `template_check` / `sgt_check`, 1 unlabelled). **Real signups: 0.** |
| Lifetime consented visitors | 383 (975 events) since 2026-03-29 |
| Peak month | Jul 2026: 333 pageviews / 88 visitors |
| Aug → Oct | 7 pv → 0 → **1 pv in the last 30 days.** The site is effectively dark. |
| Top pages | `/` 446 pv, `/trial` 90, `/buy` 54, `/help` 42, everything else ≤24 |
| Sources (visitors) | Direct 291, Google 51, internal 36, **chatgpt.com 13**, DuckDuckGo 10, Bing ~12 |
| Hero primary CTA | 17 clicks / 15 visitors of 348 home visitors = **4.3%** click rate |
| Demo engagement | `demo_mode_selected` 41 clicks (13 visitors), `demo_navigation` 33 (only 2 visitors) |
| Intent signals | `/trial` + `/buy` got 144 pv — people look for a download/price, not a waitlist |

### Findings that drive the plan
1. **There is no funnel to optimise yet — there is no traffic.** Everything below is distribution-first.
2. **The only organic channels that ever moved were Google (51) and ChatGPT (13).** Search + AI answers are the cheapest scalable source. ChatGPT sending visitors unprompted is a real GEO signal; double down on it.
3. **Direct (291) dominates**, i.e. the founder's own sharing/word of mouth. Warm network works; cold channels were never tried.
4. **Visitors want to try it** (`/trial`, `/buy` outweigh features pages). Public native release is gated (no Developer ID/notarisation per README), so the honest offer is **"private beta waitlist"**. Every asset below sells the beta, never "download now".
5. **The interactive demo is the best asset** (41 mode selections) — it must be the centrepiece of every post: "try it in your browser, no install".
6. Tracking gap: waitlist rows have **no UTM/source** (`metadata` null) because attribution only stores when consent is given. Fix before spending money (see `04-site-seo-geo-and-brand.md`, item A).

## 2. Honest math
- 1,000 signups at a 6% cold visit→signup rate needs ~16,000 unique visitors; at 12% (warm communities, demo-first) ~8,300.
- Realistic outcomes: **no breakout post → 150–400 signups. One Show HN / r/macapps hit + referral loop + creator pickup → 1,000+.** I can't guarantee a hit, so the plan buys many lottery tickets, cheaply, and doubles down on whatever works by day 10.
- Referral reward ("invite 5 friends who verify their email, get CmdTab free", after review) at K≈0.3 lifts every channel ~1.4×. Each reward costs a US$12 license, so budget for it; the abuse checks keep that cost bounded.

## 3. Positioning (single idea)
> **Cmd+Tab switches apps. You don't have 6 apps open — you have 6 Chrome windows.**
> CmdTab switches the *exact window*, with real previews.

Proof points that are true and already published on the site: individual-window targets, real previews, Command Palette search, Radial Menu, hide/minimise/close/quit from the switcher, Current/Visible/All Spaces, display-aware, macOS 14+, planned US$12 one-time (up to 3 Macs, 14-day trial, 14-day refund), optional telemetry off by default, needs Accessibility + Screen Recording (say so up front — it builds trust).

**Hard rules (from `website/SEO-GEO.md`):** no fake testimonials/ratings/benchmarks, no "sub-50 ms", RAM, or Intel/Apple-Silicon claims, no "download now". Founder-voice, honest beta framing.

## 4. UTM scheme (all links)
`https://cmdtab.net/?utm_source=<channel>&utm_medium=<type>&utm_campaign=beta1k&utm_content=<variant>`
Examples: `reddit/organic/macapps_demo`, `x/organic/thread_a`, `hn/organic/showhn`, `google/cpc/altab_exact`, `email/newsletter/<name>`, `xhs/organic/note1`.

## 5. 30-day calendar

**Days 1–3 — Ground work (needs the founder, ~6 h)**
- Enable Vercel Web Analytics; ship UTM capture for waitlist rows; record 3 screen captures (≤20 s each: grid, palette, quick actions — reuse `public/showcase/*.mp4`).
- Post #1 (X thread A) + LinkedIn + personal network DM blast (direct is the proven channel): `01-social-posts.md` §1, §6, §9.
- Submit the 10 pages in `04-…` §C to IndexNow (`npm run indexnow:submit`).

**Days 4–10 — Lottery tickets**
- Day 4 Tue: **r/macapps** post. Day 5 Wed: r/MacOS (different angle, check rules). Show HN is deferred (see the 06 report: not eligible without a downloadable build). Day 7: Indie Hackers + dev.to write-up. Day 8: Product Hunt "Coming soon" page live. Day 9–10: Xiaohongshu + Bilibili notes (Asia angle), V2EX + 少数派 (Chinese Mac power users).
- Send 25 creator/newsletter pitches (`03-…` §3) — 5 per day.
- Email #1 to every signup the minute they join (`02-…`).

**Day 10 checkpoint — decide with data**: pull the UTM table. Kill any channel under 1% visit→signup or <20 visitors. Put the paid budget behind the best-converting message.

**Days 11–20 — Double down**
- Re-run the winning angle in 3 adjacent communities. Daily: reply to every comment for 48 h after each post (this is what makes posts rank).
- Start paid test (`03-…` §1): US$25/day cap for 10 days, kill if CPL > US$3.
- Publish 1 SEO/GEO page every 2 days from the list in `04-…` §C. Ask ChatGPT/Perplexity the 10 target questions weekly and log whether CmdTab is cited.
- Referral email #3 to everyone on the list.

**Days 21–30 — Convert and close**
- "Waitlist hits N" milestone posts (only with true numbers). Email #4 (beta invitation tiers). Founder build-in-public daily post.
- Day 28: last-48h scarcity email — only if the beta cohort cap is real. Day 30: results post (true numbers, what worked) — the retrospective itself is a strong organic post.

## 6. KPIs (tracked weekly)
Unique visitors · visit→signup % per UTM · verification rate · CPL (paid) · referral K-factor · cited-by-AI count (10 fixed prompts) · waitlist total (real, deduped, excluding `e2e_*` test rows).
Milestones: day 7 = 100 · day 14 = 300 · day 21 = 600 · day 30 = 1,000. Missing day-14 by >50% → escalate budget/creator outreach, not more posts.

## 7. What I did not do (needs you)
Posting, emailing, and ad purchases require your accounts and approval, so nothing has been sent or published. Everything is paste-ready. Production DB credentials were pulled to a private temp file for read-only aggregate queries and deleted afterwards.
