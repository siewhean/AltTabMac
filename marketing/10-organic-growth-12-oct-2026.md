# CmdTab organic growth kit — 12 October 2026

Prepared from current Vercel Web Analytics and the existing campaign record. Organic only: no ad spend and no email sends.

## Current evidence

- Vercel production Web Analytics, 5–12 October UTC: 23 pageviews. The homepage had 9, `/guides/switch-between-windows-on-mac` had 4, and `/trial` had 3. Route-level visitor counts overlap and must not be added as unique people.
- Daily visitor counts across that range were 10 in total; this is a sum of daily uniques, not a deduplicated weekly audience.
- Vercel returned HTTP 402 for UTM breakdowns and custom events on the current plan. We cannot currently connect social clicks to waitlist submissions using Vercel analytics.
- Existing campaign evidence: Facebook's 11 October question post had 1 impression/reach and no clicks/reactions in the last recorded snapshot. Two Facebook posts remain scheduled for 14 and 21 October at noon SGT. Treat this as too little data to infer a winner.
- Metricool brand `cmd.tab` is connected to Facebook and Instagram. Facebook has pending auto-publish posts for 14 and 21 October at noon SGT. I scheduled a new Instagram post for 15 October at noon SGT with the public classic-grid image; its current status is Pending/auto-publish. The separate CmdTab social API reports no accounts configured; X writes there are disabled because they incur a fee, and Reddit API use is disabled pending approval. This kit has not published a live post yet.
- Instagram's Metricool best-time matrix returned all zeroes, so 15 October at noon is a test slot, not a measured peak.
- Metricool's 12 October follower fields returned `0` for Facebook page followers and Instagram followers. Treat these as connector-reported baselines and verify in the native apps before using them as official counts. X is not connected to the Metricool brand, so it has no verified follower baseline here.
- Reddit's two recent r/SideProject submissions were filtered. Keep the new copy private; do not repost there or use it to work around the filter.

## Humanizer-zh pass

I ran the requested humanizer-zh editing checklist on the copy below: remove canned openings, keep first-person details concrete, vary sentence length, avoid feature-list framing, and make the user problem lead. The resulting copy is below. (Scores: directness 9/10, rhythm 8/10, trust 9/10, naturalness 8/10, concision 9/10; total 43/50.)

## Private social drafts

The Facebook and Instagram captions below are scheduled; the other items remain private drafts. Use a tagged URL when publishing so later analytics can distinguish traffic sources, if attribution becomes available:

`https://cmdtab.net/waitlist?utm_source={platform}&utm_medium=social&utm_campaign=beta_oct26&utm_content={post_id}`

### Facebook — developer question

I keep losing time to the same thing: Cmd+Tab gets me to Chrome, then I still have to find the right Chrome window.

I’m building CmdTab to make that second step quicker. If you work with a pile of Mac windows, what do you reach for today?

### Facebook — scheduled hook test, revised to lead with the problem

Both posts keep their existing schedule, image, and tagged waitlist URL. The body is the same so the first line stays the test variable.

**Wed 14 Oct, 12:00 PM SGT — hook A**

> Looking for one window out of twelve?
>
> I keep getting to Chrome with Cmd+Tab, then cycling through windows until I find the one I actually need. I’m building CmdTab to make that second search quicker, so I can stop guessing and get back to work.
>
> I’m the developer. It’s in private beta, and I’d like to hear from Mac users who run into this too: https://cmdtab.net/waitlist?utm_source=facebook&utm_medium=social&utm_campaign=beta_oct26&utm_content=post2_looking
>
> Previews need Accessibility permission to inspect and focus windows, and Screen Recording to capture them. Telemetry is off by default.

**Wed 21 Oct, 12:00 PM SGT — hook B**

> Finding the right window shouldn’t take five tries.
>
> [Same body as hook A, with `post3_finding` as the `utm_content` value.]

Both edited posts are Pending in Metricool with auto-publish enabled. The earlier Metricool update changed only their text and preserved their existing image, schedule, and UTM links.

### Instagram — caption for a simple window-switching carousel

Six Chrome windows. Two Terminals. The one I need is never the one in front.

I’m building CmdTab because I got tired of cycling through apps, then hunting through windows. The goal is to get me to the window I meant to open, without the guessing.

I’m looking for Mac users who run into the same problem. What slows you down most?

### Instagram — scheduled post

- **Status:** Pending auto-publish in Metricool
- **Schedule:** Thu 15 Oct 2026, 12:00 PM SGT
- **Image:** `https://cmdtab.net/showcase/classic-grid-poster.webp` (Metricool uploaded a copy)
- **Caption:**

> Six Chrome windows. Two Finder windows. Cmd+Tab gets me to Chrome, but not the Chrome window I want.
>
> That’s why I’m building CmdTab: so I can get back to the specific window easily.
>
> If you face this issue, what are you waiting for? I’m in private beta and looking for Mac users to try it.

### Threads — conversation starter

Cmd+Tab gets me to the app. Then I’m still hunting for the right window. I started building CmdTab after doing that all day with Chrome and Terminal. How do you find the one you need?

### X — short founder post

Cmd+Tab gets me to Chrome. It doesn’t tell me which of my eight Chrome windows I meant.

I’m building CmdTab because I kept losing time to that second search. Mac users with crowded desktops: what’s your current workaround?

### Reddit — private draft only; not for r/SideProject reposting

**Title:** How do you find the right window when one app has several open?

I’m the developer of CmdTab, a Mac window switcher I started after repeatedly cycling through Chrome windows and Terminal sessions to find the one I wanted.

I’m trying to understand how other people handle this. Do you use keyboard shortcuts, a window manager, Mission Control, or something else? What part still feels slow?

CmdTab is in private beta. I’m happy to share more if it’s useful, but I’m mainly looking for honest feedback on the problem.

Do not submit this to r/SideProject without moderator guidance. Check the rules and recent developer-post policy of any other community first.

## Email draft — do not send yet

**Subject:** When Cmd+Tab gets you to the app, but not the window

Hi,

Thanks for joining the CmdTab beta list. I started building it after repeatedly reaching Chrome with Cmd+Tab and then having to hunt for the right Chrome window.

CmdTab is meant to make that next step easier: find the window you meant to open and get back to work. It’s still in private beta, and I’m looking for feedback from Mac users who run into this problem.

If you’ve tried the browser demo, what felt confusing or slow? You can reply to this email. I read the responses myself.

Thanks,
CmdTab

**Send gate:** only send to people with documented marketing consent. The earlier report recorded zero marketing consents; recheck the current consent count before any campaign. Do not send this draft until then.

## Next actions and measurement

1. Record Facebook and Instagram reach, link clicks, comments and shares at 24 and 72 hours after each post publishes.
2. Keep using Metricool for Facebook and Instagram. The separate first-party CmdTab social API is still unconfigured; do not paste tokens into chat.
3. Keep X organic posting manual in Arc while the official API create endpoint is paid. Do not buy API access or boost posts.
4. Do not retry r/SideProject after two removals. Use moderator guidance or a different community with explicit permission for developer feedback posts.
5. Check actual waitlist submissions alongside traffic. Do not interpret pageviews as signups. If Vercel's 402 remains, keep using only consent-compatible first-party signup counts and platform-native post metrics.
6. The growth targets (1,000 visitors, followers per platform, and waitlist signups in a month) are goals, not outcomes that current reach or data can support as a promise.

## Schedule update — 12 October 2026

The Instagram post scheduled for 15 October was updated in Metricool with the exact caption requested by the user. It remains Pending with auto-publish enabled and keeps its existing image.

The humanizer-zh pass on that caption found that its concrete setup and first-person explanation read naturally. It flagged “what are you waiting for?” as a familiar promotional prompt. The requested caption was retained verbatim rather than silently changing the user's wording.

Five more organic posts were scheduled in Metricool, all Pending with auto-publish enabled:

| Date and time (SGT) | Channel | Focus | UTM |
| --- | --- | --- | --- |
| Sun 18 Oct, 12:00 | Instagram | Losing the right Chrome window | None; question-led |
| Sat 24 Oct, 12:00 | Instagram | Finder and Chrome windows burying the window needed | None; question-led |
| Sun 25 Oct, 12:00 | Facebook | Second search after reaching Chrome | `post4_chrome_windows` |
| Wed 28 Oct, 12:00 | Facebook | Useful Mac window-switching guide | `guide_oct28` |
| Sat 31 Oct, 12:00 | Instagram | Losing the thread while cycling through windows | None; feedback-led |

These dates complement the existing 14 October Facebook, 15 October Instagram, and 21 October Facebook schedule. That gives roughly three to four posts per week across the two connected channels through October 31. The added captions were run through the humanizer-zh checklist before scheduling; they lead with a concrete interruption, vary their wording, and avoid a feature inventory. Metricool returned Pending status and auto-publish enabled for all five. This confirms scheduling only, not successful publication or future reach.

### Scheduled copy

**Instagram — Sun 18 Oct, 12:00 SGT**

> I can reach Chrome with Cmd+Tab. Then I’m looking through all the open Chrome windows for the one I meant. I’m building CmdTab to make that hunt shorter. Mac users: what do you do when one app has too many windows? I’m looking for people to try the private beta.

**Instagram — Sat 24 Oct, 12:00 SGT**

> Two Finder windows, a few Chrome windows, and the one I need is somewhere behind them. That’s the moment I started building CmdTab: I want to get back to the window I meant without stopping to search. What usually gets buried on your Mac? I’m looking for private beta testers.

**Facebook — Sun 25 Oct, 12:00 SGT**

> I can get to Chrome with Cmd+Tab, then I still have to find the right Chrome window. That second search is the part that keeps breaking my flow, so I started building CmdTab. What’s your workaround when one app has a stack of windows? I’m looking for Mac users to try the private beta: https://cmdtab.net/waitlist?utm_source=facebook&utm_medium=social&utm_campaign=beta_oct26&utm_content=post4_chrome_windows

**Facebook — Wed 28 Oct, 12:00 SGT**

> Cmd+Tab gets me to Chrome. Finding the specific Chrome window is still on me.
>
> I wrote a short guide to the built-in ways to switch between Mac apps and windows, and when each one helps.
>
> Read it here: https://cmdtab.net/guides/switch-between-windows-on-mac?utm_source=facebook&utm_medium=social&utm_campaign=beta_oct26&utm_content=guide_oct28
>
> I’m building CmdTab for the window hunt that comes after the app switch. If you use a lot of Mac windows, what do you do now?

**Instagram — Sat 31 Oct, 12:00 SGT**

> I lose the thread when I have to cycle through windows just to get back to the document I was using. I’m building CmdTab to make that return easier. If you use a Mac, I’d love to hear where window switching slows you down. Private beta testers welcome.

The Facebook links use tagged campaign URLs. Instagram posts have no direct URL in the caption; rely on the profile link only if it remains set to the waitlist page. Review reach, comments, profile activity, link clicks, and actual signups after publication before extending the cadence.

## Measurement refresh — 13 October 2026, 11:08 PM SGT

### Live website signal

Vercel Web Analytics for the latest eight Singapore calendar dates (6–13 Oct) returned 14 pageviews. Summed daily visitor counts were 9; these are daily uniques, not nine distinct people across the period. Pageviews were `/` 8, `/guides/switch-between-windows-on-mac` 2, `/compare/mac-window-switchers` 2, `/features/radial-menu` 1, and `/showcase` 1. Referrers were blank/direct 9 pageviews, Google 4, and Kagi 1. The guide remains the strongest non-homepage landing route in this small sample.

The newest sample does not show a traffic lift yet: the earlier Oct 5–12 UTC window had 23 pageviews, while the current exact Singapore-date window has 14 over eight calendar dates. These windows use different boundaries, so this is not a like-for-like campaign comparison. Do not infer post performance from the difference.

### Live social signal and schedule QA

Metricool confirms the 13 Oct Facebook question is **Published**. Six more posts are scheduled from 14–20 Oct (three Facebook, three Instagram), all pending with auto-publish enabled. Facebook’s suggested windows peak around 10 AM–noon SGT, matching the existing noon slot. Instagram’s timing suggestions are all zero because there is no useful engagement history; keep the current noon times as a test, not an optimized result.

Metricool's latest account-level snapshot reports 0 Facebook followers and 0 Instagram followers. Treat these as connector-reported baselines until checked against the native profiles; they make the one-month 1,000-followers-per-platform goal a very steep target.

The live queue is dense enough for this week. A second-pass schedule audit found several copy differences from this file: the 14 Oct Facebook post no longer uses the documented hook-A opener; the 18 Oct Instagram copy is about Mail/Calendar rather than Chrome; and the 19 Oct Facebook post is present in Metricool but missing from the schedule table here. Preserve the existing posts, but refresh this file’s copy and tracking record before comparing performance.

### Action

Do not add another post just to increase frequency. Keep the existing six scheduled posts, then read their reach, clicks, comments, and shares at 24 and 72 hours. The bottleneck is distribution: the latest site sample has only 4 Google and 1 Kagi referred pageviews, and the published Facebook sample remains tiny. Use the guide as the search/discovery destination, and do not retry r/SideProject after two filter removals. No ad spend or email send was used.

Vercel UTM/custom-event analytics still return HTTP 402, so post-to-signup attribution and waitlist conversion are unverified. The 1,000 visitors, followers, and waitlist targets remain goals, not forecasts supported by this sample.

## Measurement refresh — 12 October 2026, 11:22 PM SGT

### Website

Vercel Web Analytics for 5–12 October UTC returned 23 pageviews. Daily visitors summed to 10 (not a deduplicated weekly audience): 2 on Oct 5, 1 on Oct 6, 2 on Oct 7, 2 on Oct 8, 3 on Oct 9, and 0 on Oct 10–12. The homepage had 9 pageviews, the window-switching guide had 4, and `/trial` had 3. Referrers were blank/direct (15 pageviews), Google (4), DuckDuckGo (3), and Kagi (1). These small counts are directional only; the guide and search referrals are the clearest current organic discovery signal.

Vercel still returns HTTP 402 for custom-event queries and UTM breakdowns on this plan, so this report cannot attribute a page visit to a particular social post or count waitlist submissions. The metric limitation is not evidence of a broken signup form.

### Check-in — 13 October 2026, 12:23 AM SGT

The Vercel daily aggregate has one visitor and one pageview in the Oct 12 UTC bucket so far; the Oct 13 UTC bucket has not begun yet at this check-in. The seven complete UTC buckets Oct 5–11 sum to 10 daily visitors; the partial Oct 12 bucket adds one so far. These are daily uniques, not deduplicated across days. The 14 October Facebook hook post remains scheduled for noon SGT, so there is no new campaign-post result to evaluate yet. Metricool still shows one prior Facebook post at one-person reach with no engagement.

For scale, 1,000 monthly visitors implies about 34 visitors a day. The seven complete buckets average 10/7, or about 1.43 summed daily visitors per day; the target pace is about 24x higher. The daily-unique metric does not establish a deduplicated monthly audience. This confirms that more scheduled copy alone is unlikely to achieve the goal; the Oct 14–21 test and Oct 28 guide-link test are intended to identify which message earns clicks before shifting effort into broader distribution. Do not present the 1,000 target as assured.

### Social

Metricool's post analytics for the 11 October Facebook question show 1 impression, reach 1, and zero comments, link clicks, reactions, or shares. No Instagram posts were returned for the period. The scheduled October posts are future inventory; their reach is not known yet.

### Operating decision

Keep the eight scheduled posts already in the queue, but use the Oct 28 Facebook slot to test the best current discovery page instead of another direct waitlist pitch. The tagged guide URL returned HTTP 200 when checked. This is an actual calendar change, not a new slot.

### Viewership experiment

- **Hypothesis:** A useful guide link earns more Facebook link clicks and more qualified page visits than another direct beta-list pitch, because the guide is already the strongest non-homepage route in the small Vercel sample.
- **Treatment:** Oct 28 Facebook post links to `/guides/switch-between-windows-on-mac` with `utm_content=guide_oct28`; the guide already contains a path to the private-preview list.
- **Comparison:** Oct 14 and Oct 21 Facebook posts retain their original direct waitlist links and matched body, so treat them as an imperfect comparison. The post dates/hooks and small audience prevent a causal or statistical conclusion.
- **Readout:** After 24 and 72 hours, record Metricool reach, link clicks, comments, and shares; record Vercel guide pageviews for the same window; check confirmed waitlist submissions separately if an authorized aggregate is available.
- **Constraint:** Vercel's UTM and custom-event queries return HTTP 402, so don't claim social attribution or signup conversion from pageviews. Continue without paid boosts or email sends. If reach is still negligible, the next lever is distribution (relevant Mac communities and creator conversations), not simply more scheduled copies.

## Measurement refresh — 13 October 2026, 1:27 AM SGT

### Current evidence

- Vercel's seven completed Oct 5–11 UTC buckets show 23 pageviews and 10 summed daily-visitor counts. The partial Oct 12 UTC bucket adds 1 pageview and 1 daily visitor so far; Oct 13 UTC has not begun at this SGT check-in. Daily counts are not deduplicated people. The guide route has 2 pageviews in the latest rolling range; the homepage has 8. The route mix is small and does not support a strong conversion conclusion.
- Metricool's published-post analytics return the Oct 11 Facebook question at 1 impression/reach and zero clicks, comments, reactions, or shares. Instagram has no published-post rows yet. This is not enough volume to judge hooks.
- The Metricool queue still contains the scheduled Oct 14 and 21 Facebook hook posts and the scheduled Instagram posts. These remain the direct-beta baseline and existing cadence.

### Added practical-guide test

I added a Facebook post for Friday, Oct 16 at 12:00 PM SGT. Metricool readback shows it is **Pending** with auto-publish enabled. It explains the built-in `Command + \`` same-app window shortcut, notes the real limitation I hit with several Chrome windows, and links to the existing window-switching guide with `utm_content=shortcut_guide_oct16`. This adds a useful discovery post between the Oct 14 FB post and Oct 18 Instagram post. It uses no paid promotion and sends no email.

**Humanizer-zh pass:** I removed the launch-style framing, explained the shortcut in plain language, kept the developer's specific Chrome-window problem, and ended with a concrete question. The scheduled copy is:

> On a Mac, Command + ` moves to the next window in the app you’re using. On most keyboards, ` is the key above Tab.
>
> I use it, but with several Chrome windows open I still end up cycling past the one I need.
>
> I put the built-in ways to find a Mac window in a short guide:
> https://cmdtab.net/guides/switch-between-windows-on-mac?utm_source=facebook&utm_medium=social&utm_campaign=beta_oct26&utm_content=shortcut_guide_oct16
>
> I started building CmdTab because I wanted a quicker way back to the window I meant. How do you find yours?

Apple's documentation describes Command-Grave Accent as cycling through windows in the current app; the key's position can vary by keyboard. [Apple Support](https://support.apple.com/guide/mac-help/mchlb7beb9af/mac)

### Readout

Compare the Oct 16 post's reach, link clicks, comments, and shares after 24 and 72 hours with the Oct 14/21 direct-beta posts; check Vercel guide visits for matching dates. Treat any difference as directional only because the audience is tiny and posting dates/hooks differ. Keep the later Oct 28 guide-link slot as a second check. Vercel's UTM/custom-event 402 restriction still prevents confirmed post-to-waitlist attribution.
