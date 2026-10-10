# CmdTab Marketing Report: where we are, what to send, where, and when

Prepared 10 October 2026 (Saturday). Covers the next four weeks (12 Oct – 8 Nov) and the launch that follows.
Everything marked **verified** was checked today against a live source; everything marked **estimate** is my judgment, not data.

---

## 0. The bottom line

1. **You have no audience yet, and no downloadable product.** The waitlist holds 6 rows: 5 are old test rows counted as confirmed, 1 is your own unconfirmed test signup. **Real confirmed signups: 0.** Consented site traffic last 7 days: 4 pageviews, 2 visitors.
2. **The missing download is the biggest constraint on marketing.** Hacker News "Show HN", Product Hunt, AlternativeTo and Mac-press reviews all expect something people can try. Until a signed build exists, only the waitlist-building channels below are usable.
3. **I corrected three things from my first plan:** Show HN is *not allowed* for sign-up pages, r/macapps *now restricts* developer posts, and Resend open/click tracking is *off*, so I can't measure email opens. Details in §2.
4. **1,000 confirmed signups by 8 Nov is unlikely** without a downloadable beta. Honest range from the channels available now: **about 50 to 600** (§9). The plan below maximises that range and prepares the launch that unlocks the rest.
5. **What to do first (this weekend, about 3 hours):** pick a founder story paragraph, create/confirm your X, LinkedIn, Reddit, Xiaohongshu handles, record one 15-second screen capture of the in-browser demo, and check the welcome-email sample I emailed you (Gmail, phone, dark mode). Then Monday: 40 personal messages.

**What I produced today:** six social cards (`marketing/assets/`), this report, corrections to the earlier kit, and one fix task for a bug I found on your website (§7).

---

## 1. Where things stand (verified today)

| Area | State | Source |
|---|---|---|
| Product | Native macOS window switcher: Classic Grid, Command Palette, Radial Menu, quick actions, exact-window recency. **macOS 14+.** Private beta; **no public download**; release blocked on Developer ID signing, notarization, Gatekeeper and clean-account evidence | README |
| Planned price | US$12 once, up to 3 Macs, 14-day trial, 14-day refund, no subscription | `commerce.ts` |
| Website | Live: homepage with inline signup and browser demo; `/waitlist` canonical page; `/trial` and `/buy` redirect there; terms, FAQ, privacy updated | production check |
| Waitlist | 6 rows, 5 counted confirmed (legacy test rows), 0 marketing consents, 0 referrals, 0 rewards | production DB aggregate (no addresses read) |
| Traffic | 4 pageviews / 2 visitors in 7 days (consented only; Vercel's own dashboard showed 15 visitors in the prior month) | first-party table; PR #76 plan |
| Email infrastructure | **`cmdtab.net` verified, sending enabled**; `updates.cmdtab.net` verified since March. The site's automated email currently sends from a `cmdtab.net` address configured in Vercel; the public contact and reply-to address is `trycmdtab@gmail.com` (you asked me to use only that address from now on). 8 of 8 recent emails delivered, 0 bounces, 0 complaints. **Open and click tracking are OFF** | Resend account |
| Welcome email | Redesigned version merged (banner, confirm button, free-license block, unsubscribe). **Never viewed in a real inbox by me** | PR #82 |
| Reward program | 5 confirmed friends = free license, reviewed by a person, **capped at 100** (US$1,200 face value) | PR #79 |
| Brand assets | Logo, 5 showcase images, 3 MP4 loops, OG image | `website/public` |
| New today | 6 social cards, honestly labelled (§7) | `marketing/assets` |

---

## 2. What the research changed

| Earlier advice | What I found | New advice |
|---|---|---|
| "Show HN on day 6" | Show HN excludes sign-up pages and landing pages, and requires something people can run without signups. Asking friends to upvote is banned. *(news.ycombinator.com/showhn.html, fetched today)* | **Not eligible now.** Submit a regular engineering article instead (Appendix B). Show HN becomes a launch-day item once there is a download |
| "Post in r/macapps main feed" | Current rules (seen via mirrors of an Aug 2026 megathread, so **verify the live sidebar**) send developers who are not Mac App Store, not established GitHub projects (100+ stars, a year of history), and not flaired to the monthly **"App Pile" megathread**, in a fixed **"PCP" format**. Reddit auto-removes first comments with links if your email is unverified. Promotion in the megathread counts toward a 30-day limit | Use the megathread (Appendix A), verify email, and have 10+ karma first |
| "Track email opens ≥55%" | Resend open/click tracking is off, which is good for privacy | Measure **confirmation rate** and UTM-tagged visits instead. Don't turn tracking on without a policy decision |
| "Add Product Hunt" | I could not find official current Product Hunt documentation; community sources disagree on whether "coming soon" subscribers are notified | Do not plan around it until a downloadable build exists; read the maker guide then |
| "The site is dark (1 pageview)" | That came from the consent-gated table; Vercel's dashboard showed more | Treat Vercel's dashboard as the traffic source of truth |

---

## 3. Strategy: two phases and a gate

**Phase A, now → beta (4 weeks): build a list with what we have.** The hook is the in-browser demo, the "Cmd+Tab switches apps, CmdTab switches windows" line, and honesty about permissions and privacy. Channels: warm network, founder-led social, Asia communities (Xiaohongshu, V2EX, Sspai), one restricted Reddit post, search/AI-answer pages, and one or two genuinely technical articles.

**The gate** (you decide when it opens): a **signed, notarized, downloadable beta** with a working 14-day trial path and tested Gatekeeper install. Without it, don't submit to Show HN, Product Hunt, AlternativeTo or press.

**Phase B, gate → +2 weeks: launch.** One coordinated day (Tue–Thu): site download CTA, email to the confirmed list, Show HN, Product Hunt, AlternativeTo listing, r/macapps, press and creator pitches with a testable build.

Why this order: every channel with big reach demands a product people can try. Spending those one-shot chances now would waste them.

---

## 4. Positioning and competitors

**One line:** *Cmd+Tab switches apps. CmdTab switches windows.*
**Three pillars (all already true on the site):** exact-window targets with real previews · Command Palette search that learns your picks, plus Radial Menu · quick actions (hide, minimise, close, quit) without opening the window.
**Trust points to lead with:** says what permissions it needs and why, telemetry off by default and never includes window titles/screenshots/keystrokes, one-time price, refund.

### Competitors (verified today; vendor claims are the vendors' own)

| Product | Price | Notes | How to speak about it |
|---|---|---|---|
| **AltTab** | Free, open source; Pro US$9.99 per its own comparison table | Dedicated switcher; 15k+ GitHub stars (older snapshot, check live); previews, close/minimise buttons, shortcuts, "no telemetry" per vendor | "AltTab is excellent and free." Never attack it. Be clear about who still wants CmdTab |
| **DockDoor** | Free, open source | Dock-hover previews; switcher is secondary; macOS 13+ in newer releases | Different focus (Dock hover) |
| **Macscope** | AlternativeTo lists US$22 one-time and/or US$1/month (inconsistent; check vendor) | Search-first, live previews, searches titles/URLs/tabs; macOS 14+ | Closest rival on search. Price sits between AltTab Pro and Macscope |
| **BetterCmdTab, TabTab** | Free / freemium | Other Cmd+Tab alternatives | Background only |

**Implication:** the strongest free incumbent is good and cheap, so **price is not our wedge.** The wedge is *how* you find the window (palette, radial, quick actions, exact-window history). Make no "better than" claim until the comparison page exists with dated, first-party sources (your own rule in `SEO-GEO.md`).

**Objection to prepare for ("why pay when AltTab is free?"):** *"If AltTab covers you, keep it. CmdTab is for people who want search that remembers their picks, a radial option, and acting on windows without opening them. It's US$12 once, with a 14-day trial."*

---

## 5. Audience (who to find first)

1. **Keyboard-heavy Mac power users:** developers, designers, researchers, writers with 15+ windows. Reachable via X, Reddit, V2EX, dev blogs.
2. **Asia-based Mac users:** Singapore/Malaysia/HK developers and Chinese-language communities. Your edge: very few Western tools address them in their language.
3. **People who already search the problem:** "cmd ` not working", "switch windows same app mac", "alt tab mac". Reachable through the SEO/GEO pages (`04-…` §C).

---

## 6. The send plan: where, what, who, when

**Legend:** *You* = needs your account or your face. *Me* = I can do it after you approve. Nothing below has been sent. The "Success" thresholds are my guesses to calibrate against, not benchmarks, and posting times are suggestions. UTM format: `https://cmdtab.net/waitlist?utm_source=<source>&utm_medium=<medium>&utm_campaign=beta_oct26&utm_content=<variant>`.

### Phase A: dated schedule

| Date | Where | What exactly | Asset / copy | Who | Link `utm_source/medium/content` | Success |
|---|---|---|---|---|---|---|
| **Sat 10 – Sun 11** | Your desk | Founder story paragraph (3 sentences, real); confirm handles; verify email on Reddit; record 15 s demo capture; check the welcome-email sample I emailed you | `01-social-posts.md` §1; Appendix D | You | n/a | Test email looks right in Gmail and on a phone |
| **Mon 12** | Direct messages (WhatsApp, Telegram, iMessage, LinkedIn) | **40 personal messages** to Mac power users you know. One specific question each | Appendix D | You | `dm / dm / personal` | ≥10 click, ≥4 confirmed |
| **Tue 13** | X (your account) | Thread A (6 posts) + card **x-hero** on post 1, **radial-menu** on post 3 | `01` §1 Thread A; `assets/x-hero…`, `assets/card-radial-menu…` | You | `x / social / thread_a` | ≥300 impressions per post; ≥15 clicks |
| **Tue 13** | LinkedIn (personal profile) | Short post + square card | `01` §6; `assets/square-pain…` | You | `linkedin / social / post1` | ≥10 clicks |
| **Tue 13 →** every 2 days | cmdtab.net | Publish one SEO/GEO page: guides on "cmd ` not working", "switch windows of same app", "multiple monitors", permissions explainer | `04-…` §C | Me (write + PR) | n/a | Indexed; AI-citation check |
| **Wed 14** | Xiaohongshu (evening SGT, 8–10 pm) | Note #1 with 6 images | `01` §8; cards `x-hero`, `radial-menu`, `quick-actions` | You (post), Me (translate edits) | `xhs / social / note1` | ≥30 saves |
| **Thu 15** | V2EX "分享创造" and Sspai 少数派 submission | Share the project honestly; ask for beta feedback. **Verify each site's promotion rules first (not verified)** | `01` §8 | You | `v2ex / community / share1`, `sspai / community / pitch1` | Replies; ≥10 signups |
| **Fri 16** | Reddit r/macapps **App Pile megathread** | One post in PCP format. Only if the thread is open and you have a verified email and 10+ karma | **Appendix A** | You | `reddit / community / apppile` | ≥20 clicks |
| **Mon 19, 26, 2 Nov** | Weekly review | Pull counts, UTM results, ask ChatGPT/Perplexity/Gemini/Claude the 10 target questions, log citations | §8 | Me | n/a | A one-page weekly note |
| **Tue 20** | cmdtab.net + dev.to | Publish **engineering article #1** (Appendix B) on your own site, cross-post to dev.to a day later | Appendix B | Me (draft), You (edit, publish) | `devto / content / article1` | Read time >2 min |
| **Tue 20, 8 am ET (8 pm SGT)** | Hacker News, **regular submission** (not Show HN) | Submit the article URL. No upvote requests. Answer every comment | Appendix B | You | `hn / community / article1` | Front page is luck; ≥300 visits would be good |
| **Wed 21** | Indie Hackers | Build-in-public post: "0 → ? waitlist in 4 weeks, every number" | Appendix B | You | `indiehackers / community / post1` | Comments |
| **Mon 19 – Fri 23** | Short video (TikTok, Reels, Shorts, Bilibili) | 5 videos from the scripts; **only after you record the 15 s capture** | `01` §7; card `square-pain` as cover | You | `tiktok / social / v1…v5` | Kill formats under 500 views after 5 tries |
| **Mon 26 – Fri 30** | Creators and newsletters | **5 pitches per day, 25 total**, asking for an early look and an interview, **not a review** (reviewers need a testable build) | Appendix C | You (send), Me (draft per person) | `creator_<name> / email / pitch` | Replies; interviews |
| **Sun 8 Nov** | X, LinkedIn, Indie Hackers | Results post with true numbers and what you learned | Template in §8 | You | `x / social / results` | A retrospective is itself a good post |

### Always-on (no date)
- **Reply to every comment** within 2 hours for 48 hours after each post.
- **Referral card** (`assets/card-free-license…`): do **not** use before signup (the Cobra Effect flagged by the marketing-psychology skill: advertising a reward attracts people gaming it). Use it in the confirmation follow-up, in replies when someone asks how to get it free, and in community posts where sharing is natural.
- **Reward review** (weekly): export the dashboard CSV; for each `reward_status = earned`, check `referral_flag` of the 5 friends, then grant or deny by hand. Template reply in Appendix E.

### Phase B: launch day (opens when the gate opens)

| Where | What exactly | Prerequisite | Who |
|---|---|---|---|
| cmdtab.net | Download CTA; `releases/stable.json` published; trial path verified | Signed, notarized build; Gatekeeper tested on a clean Mac | Me + You |
| **Email to the confirmed list** | "Your beta is ready" (transactional scope: all confirmed). Product updates only to the 0 people who ticked the marketing box | Domain verified ✓ | Me (draft/send with your approval) |
| **Show HN** (Tue–Thu, 8–9 am ET) | Title `Show HN: CmdTab – a macOS window switcher …`; first comment from you with the technical story | Downloadable, no signup needed to try | You |
| **Product Hunt** (Tue–Thu) | Launch page, 5 images, maker comment | Read PH's current maker guide first | You |
| **AlternativeTo** | "Suggest new application" as an alternative to AltTab and Macscope; review queue is slow | Public availability | You |
| **r/macapps** | Megathread again (30-day limit applies) | Verify current rules | You |
| **MacStories, Six Colors, 9to5Mac tips** | Short pitch with a way to test (their editors only write about apps they've tried); verify current contact paths on each site | Testable build + press kit | You |
| **Paid test** (optional, US$250) | Google search and Reddit ads from `03-…` | Download exists, tracking works | Me (set up), You (pay) |

---

## 7. Assets

### Ready (created today, in `marketing/assets/`)

| File | Size | Use | Honesty label on the image |
|---|---|---|---|
| `x-hero-1200x675.png` | 1200×675 | X, LinkedIn, Reddit | "Illustrative composite, not a live capture" |
| `square-pain-1080x1080.png` | 1080×1080 | Instagram, Threads, LinkedIn, Xiaohongshu cover | Concept graphic (no product claim) |
| `card-classic-grid-1200x675.png` | 1200×675 | Feature post | Illustrative composite |
| `card-radial-menu-1200x675.png` | 1200×675 | Feature post | "Real render of the app" |
| `card-quick-actions-1200x675.png` | 1200×675 | Feature post | Illustrative composite |
| `card-free-license-1200x675.png` | 1200×675 | After signup only; see the Cobra Effect note | Terms printed on the card |

**Alt text:** x-hero: "CmdTab window grid with one window highlighted. Headline: Cmd+Tab switches apps. CmdTab switches windows." square-pain: "Stack of six overlapping windows, one highlighted. Headline: You don't have 6 apps open. You have 6 Chrome windows." Radial: "CmdTab radial menu ring of app icons." Quick actions: "CmdTab window grid with quick actions." Free-license: "Invite 5 friends. Get CmdTab free. Limited to the first 100 members."

**Rule from your `SEO-GEO.md`:** the Showcase images are labelled deterministic composites, except the Radial Menu (a real render). Keep those labels on every reuse. No fake testimonials, ratings, benchmarks or "sub-50 ms" claims.

### Missing, and only you can make
1. **A real screen capture of the app** (even 15 seconds of Classic Grid and Command Palette on your own Mac). It beats every composite and unlocks Show HN and Product Hunt.
2. **The 12-second side-by-side video** "Cmd+Tab vs CmdTab" (strongest social asset).
3. **Founder story** (3 real sentences) and a headshot. People back people on small utilities.
4. **Press kit page** (logo files, 3 real screenshots, one-paragraph description, price, contact) at `cmdtab.net/press`. I can build the page once you have the screenshots.

### Bug found while building the cards (fix task already queued for you)
The Command Palette image on your **Showcase and homepage** shows the search "spotify" returning **"No matching fixture windows"**, because the generator's fixture windows contain no Spotify entry. A visitor sees a failed search for your flagship feature. I did not use it in any card. A one-click task chip is waiting in this session.

---

## 8. Measurement

**North Star:** confirmed email addresses (not raw signups), because rewards and invitations only count confirmed ones.

| Metric | Source | Target (4 weeks) |
|---|---|---|
| Unique visitors | Vercel Analytics dashboard (primary) | 1,500 / 4,000 / 12,000 (scenarios, §9) |
| Visit → signup | signups ÷ visitors | 5–8% (assumption; your hero CTA click rate was 4.3%) |
| **Confirmation rate** | `confirmed_at` / signups | ≥60% |
| Reward progress | dashboard export | n/a |
| Channel quality | signups by `utm_source` | see caveat |
| AI citations | weekly manual check of 10 prompts | CmdTab named in ≥3 of 10 |

**Attribution caveat:** campaign labels reach a signup only if the visitor accepted analytics. Most won't. **Recommendation (needs your OK, small site change):** add one **optional** "How did you hear about CmdTab?" dropdown to the full form. It is user-supplied data, not tracking, so no consent conflict, and it fixes the blind spot.

**UTM sources to use:** `dm`, `x`, `linkedin`, `reddit`, `hn`, `devto`, `indiehackers`, `xhs`, `v2ex`, `sspai`, `tiktok`, `creator_<name>`, `referral`. One campaign for the sprint: `beta_oct26`.

**Weekly ritual (Mondays, 20 min):** counts and conversion → what worked → keep/kill rule (cut any channel with <1% visit→signup and <20 visitors) → one change for next week.

**Results-post template (8 Nov):** "4 weeks, N confirmed signups. What worked: …; what didn't: …; the number that surprised me: …; next: the download."

---

## 9. Scenarios (estimates, not data)

Formula: visitors × signup rate × confirm rate, then a referral lift of ×1.2–1.4.

| Scenario | Visitors | Signup | Confirm | Confirmed | With referrals |
|---|---|---|---|---|---|
| Conservative | 1,500 | 5% | 60% | **≈45** | ≈55–65 |
| Base | 4,000 | 7% | 65% | **≈180** | ≈215–250 |
| Stretch (one community thread or the article takes off) | 12,000 | 8% | 65% | **≈620** | ≈750–870 |

To reach **1,000 confirmed** you need roughly 15–19k visitors at those rates. **My judgment: well under a 10% chance before a downloadable beta exists.** Opening the gate earlier is the single biggest lever on this number.

---

## 10. Budget and reward economics

- **Cash for Phase A: US$0.** Time: about 5–7 hours per week for you; I handle drafting, pages and weekly reports.
- **Optional paid test: US$250** only after the download exists (kill at cost per signup above US$3 or the stop rules in `03-…`).
- **Reward cost:** each earned reward gives away one US$12 license. **Cap 100 = US$1,200 face value** (no extra cost to you beyond the lost sale) plus about 3 minutes of review each (~5 hours at the cap). That works out to about **US$2.40 per friend brought in**, cheaper than paid acquisition estimates in `03-…` (unvalidated).
- **Watch for abuse:** the system flags same-device/network, aliases and disposable mail, and a person approves each grant.

---

## 11. Risks and compliance

| Risk | Mitigation |
|---|---|
| Promotion rules differ per community | Read the live rules before each post; disclose that you are the developer; no vote-asking; no sock puppets |
| Waitlist-only product on a download-first community | Don't post where a download is required (§2) |
| Privacy law (Singapore PDPA, GDPR) | Consent-based marketing only (0 consents today); every email has unsubscribe; purge of never-confirmed signups; policy updated |
| Reward gaming | Confirmation, device/network checks, flags, manual approval, cap of 100 |
| Over-claiming | Use only claims in `product-facts.ts` and `SEO-GEO.md`; no unverified benchmarks, Apple-Silicon/Intel claims, or fake proof |
| Failed first impression on the product | Fix the Command Palette poster before pushing traffic (§7) |
| Email deliverability on a new domain | Start small, personal first; consider a separate marketing subdomain (below) |

**Email recommendation:** keep the existing `cmdtab.net` sender for transactional mail (confirmations), with `trycmdtab@gmail.com` as the reply-to. Send any future bulk updates from **`updates.cmdtab.net`** (already verified) so a marketing complaint can't hurt confirmation delivery.

---

## 12. Your pre-flight checklist and decisions

**Do before Monday**
- [ ] Send yourself the welcome email (sign up with a second address) and check Gmail desktop, Gmail mobile, and dark mode.
- [ ] Reddit: verify email, check karma, read the live r/macapps sidebar and the App Pile thread.
- [ ] Write the 3-sentence founder story and pick a headshot.
- [ ] Record the 15-second capture.
- [ ] Decide handles/links for X, LinkedIn, Xiaohongshu, V2EX, Sspai.

**Decisions I need from you**
1. **When is the target date for a signed, downloadable beta?** It sets the launch day and the realistic goal.
2. **OK to add the optional "How did you hear about CmdTab?" field?**
3. **Do you want an engineering article first (Appendix B), and which topic?**
4. **OK to build a `/press` page** once you have screenshots?
5. ~~Email this report to you~~ **Done:** the report and a sample of the welcome email were emailed to you on 10 Oct from the `cmdtab.net` sending domain (before you asked me to stop using that address) (no other email has been sent).

---

## Appendix A: r/macapps "App Pile" megathread post (PCP format; verify current format first)

**CmdTab: switch exact windows, not just apps (macOS 14+, private beta)**

**Problem:** Cmd+Tab switches apps, so with 6 Chrome windows and a few terminals you end up on Cmd+` and guessing. CmdTab treats every window as its own target with a real preview.

**Compared with:** AltTab is free, open source and a great window switcher. CmdTab's focus is different: a Command Palette that searches your open windows and remembers your picks, a Radial Menu, and quick actions (hide, minimise, close, quit) without opening the window. Macscope is also search-first. CmdTab's palette remembers your picks and sits alongside a Radial Menu and quick actions. If AltTab already covers you, you may not need CmdTab.

**Pricing:** planned US$12 once, up to 3 Macs, 14-day trial, 14-day refund, no subscription. Currently a **private beta; join the waitlist** (no payment): https://cmdtab.net/waitlist?utm_source=reddit&utm_medium=community&utm_campaign=beta_oct26&utm_content=apppile

Needs Accessibility and Screen Recording permission (previews require it); telemetry is off by default. I'm the developer. Questions welcome.

*(Add a screenshot. Use `assets/card-radial-menu-1200x675.png`, which is a real render, and say so.)*

## Appendix B: Engineering articles (for your site, dev.to, and a regular HN submission)

All three come from real work in your repo. **Re-verify every technical claim against the current code and macOS before publishing.**

1. **"Why Cmd+Tab can't tell your windows apart: exact (PID, CGWindowID) recency"**: how CmdTab keeps one global most-recently-used list of individual windows, why preview failure changes presentation but not membership, and why history updates only after activation is confirmed.
2. **"A macOS screen-sharing indicator that reports a (-1,-1) frame"**: the AppKit geometry fault you reproduced in a plain window with no CmdTab code (`Tests/Fixtures/AppKitSharingGeometry/README.md`). Strong HN material because it is a reproducible platform bug.
3. **"Keeping a global shortcut non-blocking: event taps, 0.25 s Accessibility timeouts and a watchdog"**: the event-tap callback stays non-blocking, hung apps can't stall it, and a once-a-second watchdog reinstalls disabled taps.

**HN title options (regular submission, link to the article):** *Why macOS Cmd+Tab can't tell your windows apart* · *A macOS screen-sharing indicator that reports a (-1,-1) window frame*.
**Rules to follow:** no asking for upvotes; be present for the first two hours; don't submit the waitlist page itself.

## Appendix C: pre-beta pitch to a creator or newsletter

> **Subject:** Early look: a Mac window switcher built around search (interview, not a review)
> Hi [name], I liked [specific episode/post]. I'm building CmdTab, a native macOS switcher where every window is its own target, with a Command Palette, Radial Menu and quick actions. It's in private beta and **not downloadable yet**, so I'm not asking for a review. I'd love to talk about the problem (Cmd+Tab switches apps, not windows) or send a short demo clip. There's a browser demo here: [link with `creator_<name>` UTM]. Either way, thanks for the work you do.
> [Name], developer, CmdTab · trycmdtab@gmail.com

## Appendix D: personal message (Mon 12)

> Hey [name], I built a Mac window switcher (switches *windows*, not just apps, with previews). It's in private beta; you're one of the few Mac power users I'd trust to tell me what's broken. Try the demo in your browser (20 seconds), no install: [link, `dm / dm / <name>`]. If it clicks, add your email there. And one question: how many windows do you have open right now?

## Appendix E: reward decision replies (manual)

**Granted:** *Subject: Your CmdTab license* · "You invited 5 friends who confirmed their email, so here is your free CmdTab personal license: [key/link]. Thank you for spreading the word."
**Declined:** *Subject: About your CmdTab invite reward* · "I reviewed your invitations and couldn't count some of them (for example same device or network, or duplicate addresses). The rules are in our Terms. If you think this is a mistake, reply and I'll look again."

## Appendix F: "Your beta is ready" (Phase B; confirmed list)

> **Subject:** CmdTab beta: your invitation
> Hi [first name], the CmdTab private beta is open. Download: [link]. Needs macOS 14+, and Accessibility and Screen Recording permission (previews need it; here's why: [permissions page]). Your 14-day trial starts when you open the app. I read every reply: what broke, what's missing? · [founder]

## Sources checked today
- Hacker News Show HN rules: https://news.ycombinator.com/showhn.html
- r/macapps rules (via third-party mirrors; verify live): https://redlib.groet-infra.nl/r/macapps
- AlternativeTo submission flow: https://alternativeto.net/faq/
- AltTab features and comparison (vendor): https://alt-tab.app/features · https://alt-tab.app/vs/mission-control
- DockDoor README: https://github.com/ejbills/DockDoor
- Macscope listing: https://alternativeto.net/software/macscope/about
- Product Hunt (community sources only; no official document found)
- Resend account (domains, delivery metrics) and production database (aggregate counts only, no addresses): queried today
