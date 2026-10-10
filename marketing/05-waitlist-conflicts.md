> **Status update (2026-10-10, end of task):** every conflict in sections A and B is resolved or consciously deferred; see "Resolution" at the bottom.

# Waitlist conflicts (checked 2026-10-10 against `origin/main` 94343041)

Method: my work was snapshotted as a dangling commit and `git merge-tree` was run against each branch, then the branch diffs were read.

## A. Git conflicts with my branch (`feat/beta-first-referral-loop`)

| Branch / PR | Status | Conflicts with mine | What it actually does |
|---|---|---|---|
| `origin/main` | 13 commits ahead of where I started | `README.md`, `website/package.json` only (resolved) | Contact email → `trycmdtab@gmail.com`; macOS 14 FAQ; licensing route tests. |
| **PR #52** `codex/waitlist-seo-growth` (open, 47 behind main) | **Heavy: 36 files** incl. `api/waitlist/route.ts`, `waitlist-store.ts`, `waitlist-attribution.ts`, `waitlist-email.ts`, `legal.ts`, hero, header, trial, buy, launch section | Makes the site **waitlist-only**, rewrites the route (drops honeypot + fingerprint de-dupe, adds `form-request-origin`) and changes the store to `on conflict do nothing`. | Overlaps my hero/CTA work and **breaks my referral backfill**: `do nothing` never fills `referral_code`, `canonical_email`, or signals for existing rows. Needs a deliberate merge, not a mechanical one. |
| `codex/marketing-waitlist-readiness` (no PR, 47 behind) | **Heavy: 20 files** (route, trial form, attribution, `legal.ts`, `faq.ts`, `home.ts`, `site.ts`, header, docs) | Older copy of the same attribution/consent work, plus a `waitlist-campaign-safety` test and a campaign kit. | Largely superseded by what is already on main; merging it would regress main. Treat as a source of ideas, not a branch to merge. |
| **PR #76** `feat/waitlist-consent` (open, docs/plan only) | **No file conflicts** | none | Plans double opt-in, verified counting, marketing consent, suppression. **Blocked on product decisions D1–D8.** See B1. |
| PR #77 / #47 Tailwind 4 | 1 file: `ui/site-header.tsx` | header button label | Mechanical. |

## B. Design conflicts (no git error, but they contradict each other)

1. **Double opt-in is built twice.** PR #76 is a plan whose decisions are unmade. I implemented the part referrals need: signed link, `confirmed_at`, `confirmation_sent_at`, `/api/waitlist/confirm`, token context `cmdtab-waitlist-confirm:v1:`, 7-day expiry, GET = button / POST = confirm. Names match #76 on purpose. What differs: #76 wants **fail-closed 503 when DB/Resend/secret is missing**, a `status` column, a **suppression table** (unsubscribe keeps a hash so re-signups are not re-emailed), **counting only confirmed rows**, and moving the owner notification to confirmation. I did none of that. Decide D1–D8, then reconcile once.
2. **Unsubscribe semantics.** Privacy policy and code: unsubscribing **deletes** the row (mine also re-judges the inviter's reward). #76: delete **plus** suppression hash. These cannot both be true.
3. **Counting rules.** Marketing plan (#76/`docs/marketing`) says only *confirmed* addresses count toward 1,000. The dashboard (`getWaitlistAggregateStats`) still counts every row, including unconfirmed and test rows.
4. **Attribution under consent.** Policy says UTM labels are stored only if analytics consent was accepted, so most rows will have none. #76 and my kit both want measurable channels. Unresolved product/legal choice.
5. **Duplicate marketing kits with different baselines.** `docs/marketing/campaign-kit/` and `docs/marketing/one-month-1000-active-users-plan.md` (on main) vs `marketing/` (mine) vs `docs/marketing/2026-10-09-website-growth/` (PR #52). Baselines disagree: #76's plan cites Vercel Web Analytics **15 visitors / 35 pageviews** for Sep 7–Oct 7; my DB query showed **1 pageview in 30 days**. **Mine undercounts**: it reads only the consent-gated first-party table, so "the site is dark" in my first report was too strong. Treat the Vercel dashboard as the better traffic source (the API returned 404 for it, so I could not read it).
6. **Reward vs pricing/terms copy.** The site says one-time US$12 (`commerce.ts`, `product-facts.ts` "One-time purchase"). A free license for 5 referrals is not in `terms.ts` (eligibility, review, revocation, one per person) or the FAQ.
7. **"Waitlist-only" vs commerce pages.** README/#52 say waitlist-first; `/buy` and launch-section still render checkout copy. #52 removes it; my branch leaves it.
8. **Contact address.** Main uses `trycmdtab@gmail.com`; my first marketing drafts said `hello@cmdtab.net` (fixed in this kit).
9. **Email promise vs behaviour.** Form copy says every email has an unsubscribe link; `waitlistUnsubscribeUrl` returns none when the secret is unset (it is set in production; not in preview/dev). The same secret now gates the confirm link.

## C. Suggested merge order
1. Decide #76's D1–D8. 2. Merge my branch onto main (clean). 3. Rebase #52 on top, **keeping `on conflict do update` with the referral/signal backfills** and its waitlist-only copy. 4. Retire `codex/marketing-waitlist-readiness`. 5. Consolidate the four marketing docs into one.


## Resolution
| Item | Outcome |
|---|---|
| My branch vs `main` | Merged as PR #79 (CI green) after merging `main` (with Tailwind 4) into the branch; production serves `/waitlist`. |
| PR #52 | Closed as superseded by #79. Ported: canonical `/waitlist`, permanent `/trial` and `/buy` redirects that keep `utm_*` and `ref`, waitlist-only public copy. Deliberately **not** ported: Tailwind 4 (own PR #77), dependency bumps, CI workflows that need verification secrets, closing `/api/trial/*` (the installed app uses them), and its "macOS 13" text (the minimum is 14.0). |
| PR #76 | Closed as resolved by #79: D1–D5, D7, D8 decided and implemented; D6 (bounce/complaint webhook) deferred. Recorded in `tasks/todo.md`. |
| `codex/marketing-waitlist-readiness` | Superseded by `main`; branch left untouched, nothing merged from it. It would still conflict in ~23 files if anyone merged it, so treat it as dead (safe to delete). |
| PR #77 (Tailwind 4) | Merged to `main` while #79 was open. Its conflicts with #79 (header, mobile nav, the deleted `/trial` page, todo) were resolved in #79, and the new components use Tailwind 4 syntax. |
| B3 counting | Dashboard aggregate now reports `confirmed` and `unconfirmed`. |
| B6 terms/FAQ | "Beta invite reward" terms section and FAQ entry added; cap of 100 stated. |
| B7 commerce pages | `/buy` redirects to `/waitlist`; links, nav, footer and structured-data URLs updated. |
| B9 unsubscribe promise | Signup now fails closed (503) when the link-signing secret is missing. |
