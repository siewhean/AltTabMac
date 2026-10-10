# CmdTab — Email system

Sender: the configured waitlist from-address (public contact address is `trycmdtab@gmail.com`) (Resend already wired in `website/src/lib/resend.ts`). Plain, founder-voice, text-first. Every email needs the signed unsubscribe link (`WAITLIST_UNSUBSCRIBE_SECRET` already in production). Consent text on the form covers "beta updates and launch-related messages" — keep every email within that scope; do **not** import purchased lists.

## A. Welcome sequence (automated)

### E0 — Instant confirmation (built into the product; this is the live copy)
**Subject:** You're on the CmdTab beta list
Contains: a **Confirm my email** button (signed link, valid 7 days), and the reward terms with the personal invite link: "Invite 5 friends. When 5 of them confirm their email, you get a free CmdTab license after a quick review. Each friend must be a different person on their own device and network; duplicate, disposable, or same-device invitations don't count."
Follow up manually only by replying to people who write back; do not send marketing beyond the beta/trial/launch scope the signup consented to.

### E1 — Day 2: the story
**Subject:** Why Cmd+Tab isn't enough
Hi {{first_name}}, a 90-second story: [ME: the moment you got fed up — real, specific, with the Cmd+` detail]. That's why every window in CmdTab is its own target. Here's a 15-second clip of the Command Palette: [gif]. What's your most chaotic desktop? Hit reply.

### E2 — Day 5: the feature that converts skeptics
**Subject:** Close 12 windows without opening any of them
Quick actions: select → hide / minimise / close / quit. [clip]. Most people I show this to say "wait, that's the feature." If you've got a Mac with 20+ windows right now, try the demo: {{demo_url}}.

### E3 — Day 9: trust + transparency
**Subject:** What CmdTab asks for (and what it doesn't)
Permissions: Accessibility (shortcut + focus windows), Screen Recording (previews). Telemetry: off by default; if on, only: install ID, event, license state, app/macOS version — never titles, screenshots, keystrokes, or clipboard. Pricing plan: US$12 one-time, 3 Macs, 14-day trial, 14-day refund. Full details: {{privacy_url}}. Questions? Reply.

### E4 — Day 14: social proof (only when true)
**Subject:** {{count}} Mac users are on the list — your move
Use the **real** count only. Ask for a referral: "Send this to the one friend with 30 windows open: {{referral_url}}". Reward: a free license at 5 confirmed friends (see E0).

### E5 — Beta invitation (manual, in waves)
**Subject:** Your CmdTab beta is ready
Wave 1: top-referrers + replied-to-me users. Include install steps, the permission walkthrough, the feedback channel, known limitations (not notarised yet if still true, so include the Gatekeeper step). Ask for one thing: a 2-minute reply on what broke.

## B. Nudge / re-engagement
- **No click in E0–E1 (day 7):** "Did the demo load for you? Reply with your browser and I'll fix it."
- **Beta invited, no install (day 3 after):** "Stuck on permissions? Here's the 60-second video."
- **Sunset (day 45):** "Stay on the list? One click."

## C. Referral mechanic (built; see `website/src/lib/waitlist-referral.ts`)
- Reward: **5 qualified referrals = a free CmdTab license**, granted by a person after review. No queue or position.
- A referral qualifies only if the friend (1) confirmed their email via the signed link, (2) is not a disposable-mail domain or a Gmail dot/plus alias of an existing address, (3) did not sign up from the inviter's device or network, (4) shares no device or network with another counted friend, and (5) did not create several signups from one device. The inviter must also have confirmed their own email.
- Anything that fails is **flagged for review with the reason**, not silently dropped. Dashboard CSV export includes `referral_status`, `referral_flag`, `reward_status`.
- Stored as keyed hashes only (network prefix, browser device id), deleted after 90 days unless flagged or awaiting review. Disclosed in the privacy policy.
- Known limit: one person with a different device, a different network, and several real mailboxes can still pass the automated checks. The human review before granting is the backstop.

## D. Cold outreach (individual, 1:1, not bulk blasts)
### To a Mac newsletter / creator
**Subject:** Mac window switcher for your readers (beta access + questions)
Hi [name], I read [specific issue/video]. I'm building CmdTab, a native Mac switcher where each *window* is a target (previews, command palette, quick actions). It's in private beta. Would you like early access and, if you like it, a custom 10% … *(no discount codes until commerce is live — offer **early access + a Q&A with the dev** instead)*. Browser demo: [LINK-email_<name>]. No obligation, and I'll accept honest criticism.

### To a YouTube Mac-productivity creator
Same as above + "I'll send a clean 30-second B-roll pack (the three modes) and the benchmark-free feature list so you can verify everything on screen."

### Follow-up (day 4, one only)
"Bumping this once — happy to answer anything about permissions/privacy before you decide."

## E. Metrics
Welcome open ≥55%, click ≥18%; referral share rate ≥10%; unsubscribe <1.5%/email. Test subject lines 2 variants on E1 (curiosity vs benefit) once list >200.
