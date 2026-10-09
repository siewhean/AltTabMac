# CmdTab 30-Day Waitlist Growth Campaign

**Prepared:** 7 October 2026
**Campaign window:** 8 October–6 November 2026
**Status:** Campaign plan and draft copy only. No posts, emails, listings, or ads have been sent or launched.

**Ready-to-review campaign assets:** [campaign kit](campaign-kit/README.md)

## Goal and baseline

Goal: reach **at least 1,000 unique, double-opted-in email addresses on the CmdTab trial waitlist by 6 November**. This measures verified addresses, not necessarily unique people. To ensure at least 1,000 on the list regardless of its current size, plan for 1,000 net-new confirmations; verify the existing aggregate first and adjust the target if the goal is 1,000 total including current signups.

Vercel Web Analytics reports **15 website visitors and 35 pageviews** for 7 September–7 October 2026. The live `/trial` page offers a waitlist form and no download. The current list size and signup conversion rate were not verified; the admin dashboard is protected, and no signup records were accessed. The site’s custom-events API is plan-restricted (HTTP 402), and first-party analytics are consent-gated.

The live trial form says “Request Trial Access” and promises an email when the trial is ready. It does not display a marketing checkbox or an email verification link. The server sends a receipt but does not verify that the address owner confirmed. A form success response is not proof that the signup was stored: the API can respond successfully when the waitlist database is not configured. Before counting signups, require a durable unique record and a verification link. Do not treat current form submissions as consent to a recurring promotional sequence; send only the requested access/availability notice unless separate affirmative consent is recorded.

**8 October dashboard snapshot (user-provided Vercel screenshot):** Production, Last 7 Days: 8 visitors, 18 pageviews, 75% bounce rate. The visible page rows show `/` (4 visitors), `/guides/switch-between-windows-on-mac` (4), `/trial` (2), `/buy` (1), and `/security` (1). Visible referrers are Google (4), Bing (1), and DuckDuckGo (1). These are tiny, overlapping aggregates; they do not establish search as a winning channel or reveal signup conversion. The guide has the same visible visitor count as the home page, so this iteration adds a clearly labeled private-preview waitlist CTA near the guide introduction and tags its link. Compare guide visits and consented form-success responses after a production release; neither metric proves a confirmed signup.

**Production copy mismatch:** the live trial page currently says macOS 13.0+, while current repository facts say macOS 14+. Resolve the deployed product-fact mismatch before promotion; use no compatibility claims until the live release owner verifies them.

## Funnel model and reach required

Planning assumptions, not observed conversion: 10% of qualified unique landing visitors submit the form, and 80% of submissions complete email verification. To get 1,000 confirmed addresses, target **12,500 qualified unique visitors → 1,250 form submissions → 1,000 confirmed signups**, or about **417 qualified visitors per day**. That is roughly **833×** the measured 15 monthly visitors. Recalculate after the first 100 qualified visits and 50 submissions. This is a stretch scenario, not a forecast or guarantee.

| Source | Qualified unique visitors | Assumed confirmed signups | Execution |
|---|---:|---:|---|
| Creators and partner newsletters | 4,000 | 320 | Tailored outreach to 40 Mac productivity creators/newsletters; offer an honest preview and trackable link; follow up once. Disclose any paid relationship. |
| Mac communities and founder social | 3,000 | 240 | Useful daily workflow tips and preview clips on founder channels; post in relevant Mac, developer, and design communities only where self-promotion is allowed. Avoid mass cross-posting. |
| Separately consented email and referral traffic | 2,500 | 200 | Use only contacts with recorded permission for this type of message. If that audience is too small, replace reach through partners/community referrals; never scrape or purchase a list. |
| Search, SEO/GEO, and direct | 2,000 | 160 | Publish one helpful guide weekly; keep product facts accurate; link feature/comparison pages to `/trial`; share canonical pages with search and AI discovery surfaces. |
| Paid search/social | 1,000 | 80 | Proposed US$300, 7-day pilot only after verification and attribution work. Scale only if cost per confirmed signup is at or below US$3; proposed total cap US$900, subject to available budget. |
| **Total** | **12,500** | **1,000** | All rates are assumptions. Attribute confirmed addresses by source; deduplicate by normalized email. |

The allocation is a channel hypothesis, not a forecast. If no separately consented list exists, shift its visitor allocation to partner/community outreach and revise the schedule. Do not submit to product directories that require a public release while the product remains waitlist-only.

## Week-by-week execution

- **Week 1 (8–14 Oct):** Obtain the current waitlist aggregate without exporting addresses. Resolve live/source compatibility copy. Verify the new consent-gated campaign attribution in a controlled test; add explicit optional marketing consent, double opt-in, unsubscribe/suppression, and a durable-confirmation metric before any nurture campaign. Prepare actual-app footage or clearly labeled showcase composites. No paid spend until measurement works.
- **Week 2 (15–21 Oct):** Start the creator/community wave. Publish the first demo and setup guide. Email only a separately permissioned segment; current access requests get only the access/availability update they were promised. Run the US$300 paid pilot after attribution and verification are working.
- **Week 3 (22–28 Oct):** Compare cost per confirmed signup and signup quality by channel. Shift effort to the best two sources; stop weak or misleading channels. Publish two workflow tips and one fair comparison.
- **Week 4 (29 Oct–6 Nov):** Run a referral and community push; publish an honest progress update; suppress unsubscribed/bounced addresses; report total verified unique addresses, net-new signups, source mix, conversion, spend, and remaining gap.

## Measurement pipeline

1. Tag every campaign link with `utm_source`, `utm_medium`, `utm_campaign=waitlist_1000_30d`, and unique `utm_content`.
2. The current source captures bounded campaign labels and landing path in signup metadata after explicit submission only when optional analytics consent is accepted; the privacy notice describes this. Waitlist access request and analytics consent remain separate.
3. Add double opt-in and count only a durable, verified, unique email record. An email provider accepting a message or the API returning `ok` does not count as confirmation.
4. Add an explicit, unchecked marketing consent with scope and timestamp. Keep trial-access notification separate; add working unsubscribe and suppression before any nurture email.
5. A consented `waitlist_form_success_response` event now measures successful API responses. It is not proof of durable storage or email verification. Record confirmed-signup events server-side after double opt-in exists.
6. Review aggregate daily: qualified visits, form submissions, verification rate, confirmed unique addresses, source, spend, cost per confirmed signup, bounces, unsubscribes, and complaints. Do not expose or share individual addresses in campaign reporting.

## Ready-to-review campaign copy (not sent)

**Social:** Mac users: how many windows do you juggle on a busy day? CmdTab is building a keyboard-first way to find the right open window and get back to work. We’re inviting people to the private trial waitlist while release readiness is in progress. See the current product preview and join here: [trackable URL]. Check current requirements and permissions here: [verified URL].

**Creator outreach:** Hi [name] — I saw your [specific Mac workflow/video]. I’m working on CmdTab, a keyboard-first Mac window switcher, and thought the window-heavy workflow might be relevant to your audience. The public trial isn’t available yet, so I can share a preview and waitlist link. If you’re interested, I’d value honest feedback; there’s no expectation of a positive review. [trackable URL]

**Email verification (new step required):** Subject: Confirm your CmdTab trial waitlist request. Body: You asked to join the CmdTab trial waitlist. Confirm this email address to verify your request: [single-use verification link]. If you did not request access, ignore this message. Confirming trial access does not subscribe you to optional product updates. If you separately selected product updates, that preference is managed here: [preferences/unsubscribe link].

**Access availability notice (after verification):** Thanks for confirming your CmdTab trial access request. The trial is still in private preview. We’ll email you when access is ready.

**Optional product updates (only to separately opted-in contacts):** You asked to receive occasional CmdTab product updates. Here’s this month’s progress: [verified update]. Manage or unsubscribe from these updates here: [link].

Replace bracketed items only with verified details. Do not claim a release date, compatibility, endorsements, user count, or app capability without evidence.

## Blockers and status

- Current waitlist aggregate and conversion baseline: **unknown**; get aggregate counts through the protected dashboard before setting the net-new target.
- Consent-gated campaign attribution is implemented in local source but **not deployed**; it records a request/API-response path, not a confirmed signup. As of 10 October (`main` after PR #64): a signed one-click **unsubscribe** exists, but only when `WAITLIST_UNSUBSCRIBE_SECRET` is configured (otherwise emails go out without the link). It deletes the record rather than suppressing it, so a re-submitted address is emailed again, and bounces and complaints are not handled. **Double opt-in, verified-address counting, separate marketing consent, and suppression are not implemented.** The design and the product decisions it needs are in `tasks/todo.md` (2026-10-10).
- `hello@cmdtab.net` is the intended contact address but **not an operational mailbox**: DNS has no MX record, and no email/DNS provider is connected. Do not publish contact details or deploy the contact-source change until it is provisioned and verified.
- Live/source macOS minimum mismatch: **needs resolution before public promotion**.
- Current traffic is far below the reach needed by the planning model; large partner/community distribution is essential. The goal cannot be guaranteed.
- Vercel traffic was queried for project `website` on 7 October 2026 using the Web Analytics visits count endpoint with `since=2026-09-07` and `until=2026-10-07`; result: 15 visitors and 35 pageviews. The custom-events query returned HTTP 402. This is an account query snapshot, not a committed analytics export.
- No posts, email campaigns, directory listings, or ads have been sent/launched; no spend has been made.
