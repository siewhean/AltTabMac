# Guide-end waitlist CTA — 13 October 2026

## Why this change

Vercel's latest route breakdown shows only 2 pageviews on `/guides/switch-between-windows-on-mac` in the measured period, so the sample is small. The page already has a waitlist CTA near the top, but readers who finish the decision table and source notes have no next step. The guide has a verified search title and useful native-shortcut content; this change tests a clearer end-of-page path without adding another feature pitch.

## Change

Added a second contextual CTA after the guide's decision table and Apple source links:

- **Heading:** “Still looking for the window you meant?”
- **Copy:** “If you reach the right app but still have to cycle through its open windows, CmdTab is being built to help you get back to the one you meant.”
- **Button:** “Request private-preview access”
- **Attribution label:** `utm_content=guide_end_cta`

The original top-of-page CTA remains unchanged. The new link uses the same campaign source, medium, and campaign labels as the intro CTA, with a distinct content label.

## Readout

After the change is deployed, compare guide-end CTA waitlist visits/submissions with the intro CTA only if the current consent-gated analytics report the distinct content labels. Otherwise, use aggregate waitlist submissions and guide pageviews as directional signals; do not infer conversion rate from pageviews alone. Vercel's UTM/custom-event reports previously returned HTTP 402 on the current plan, so reliable CTA-level attribution may remain unavailable.

## Validation

- `npm run typecheck` — PASS
- `node scripts/verify-seo.mjs` — PASS
- Local Next.js render — PASS. Started with `./node_modules/.bin/next dev -p 3092`; `curl -sS --max-time 15 'http://localhost:3092/guides/switch-between-windows-on-mac'` returned the route, and `rg` matched the CTA heading, button label, and escaped `guide_end_cta` href. Next.js logged `GET /guides/switch-between-windows-on-mac 200`.
- `git diff --check` — PASS
- Production deploy — NOT RUN. The change remains on a review branch.
