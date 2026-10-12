# Homepage waitlist CTA copy test

Date: 2026-10-13 (Asia/Singapore)

## Observation

The homepage form joined the waitlist, but its button said “Join the private beta.” The `/waitlist` page explains that beta invitations will arrive later in waves. That mismatch may make the immediate outcome unclear.

## Change

- Use “Join the waitlist” for the header, mobile navigation, and waitlist form buttons.
- Tell homepage visitors that joining is free and that CmdTab will email them when beta invitations open.
- Keep the existing `homepage_hero` signup source and consent-gated attribution unchanged.

## Measurement

This is a copy hypothesis, not a proven conversion fix. Vercel’s latest complete UTC-day ranges are 16 visitors / 34 pageviews from 2026-09-12 through 2026-10-12, and 10 visitors / 23 pageviews from 2026-10-05 through 2026-10-12. Custom-event analytics are unavailable on the current Vercel plan (402), so this change cannot be judged from Vercel form-success events. Compare actual stored waitlist submissions from `homepage_hero` against homepage visitors if that aggregate is available; otherwise report the conversion result as unmeasured.

No email was sent and no paid traffic was used.
