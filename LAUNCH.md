# CmdTab Launch Checklist

This file separates what is already prepared in the repo from what still requires owner decisions, accounts, and operational setup.

## Done In Repo

- `website/` is a production-buildable Next.js marketing site.
- Waitlist capture exists at `POST /api/waitlist`.
- The site now includes Vercel Analytics page tracking and CTA event tracking.
- `.env.example` exists in `website/` for the waitlist email setup.
- The macOS app already builds into `CmdTab.app` via `./build.sh`.
- `./scripts/build_release_dmg.sh` packages a signed + notarized DMG once Apple credentials are configured.

## You Need To Decide

- Final offer:
  - public 14-day trial
  - standard one-time license price: `$9.99`
- Commerce stack:
  - Lemon Squeezy
- Support inbox:
  - beta/support email
  - refund/contact email
- Download strategy:
  - direct app download only
  - or direct download + Setapp later

## Website Launch Steps

1. Create and verify your sending domain in Resend.
2. Fill in `website/.env.example` values in Vercel project env vars:
   - `NEXT_PUBLIC_SITE_URL`
   - `SITE_URL`
   - `RESEND_API_KEY`
   - `WAITLIST_FROM_EMAIL`
   - `WAITLIST_TO_EMAIL`
   - `WAITLIST_REPLY_TO_EMAIL`
   - `NEXT_PUBLIC_CHECKOUT_PROVIDER`
   - `NEXT_PUBLIC_CHECKOUT_URL`
   - `NEXT_PUBLIC_STANDARD_CHECKOUT_URL`
   - `NEXT_PUBLIC_TRIAL_URL`
   - `NEXT_PUBLIC_SUPPORT_EMAIL`
   - `LEMONSQUEEZY_WEBHOOK_SECRET`
   - `CMDTAB_LICENSE_PRIVATE_KEY_PEM`
   - `LICENSE_DELIVERY_FROM_EMAIL` (optional)
3. Connect your real domain to the Vercel project.
4. Confirm the direct purchase flow opens the Lemon Squeezy checkout.
5. Configure the Lemon Squeezy webhook to `https://cmdtab.net/api/lemonsqueezy/webhook`.
6. Run a signed test delivery:
   - `node scripts/send_test_purchase_webhook.mjs --url https://cmdtab.net/api/lemonsqueezy/webhook --email tohsh17@gmail.com`
7. Provision and monitor:
   - `tohsh17@gmail.com`
8. Enable Vercel edge protections and production abuse controls:
   - WAF / attack challenge mode where appropriate
   - request throttling / bot protection
   - deployment access controls
9. Replace the remaining static walkthrough SVGs with actual product GIFs or MP4 clips.
10. Keep secrets production-only:
   - do not commit live env values
   - use separate preview and production keys
   - rotate `RESEND_API_KEY` immediately if exposure is suspected

## Commerce Steps

1. Pick a merchant-of-record provider.
2. Create:
   - standard price
   - trial/download delivery flow
   - hosted checkout URL for the site launch section
   - webhook secret for `order_created`
3. Decide license model:
   - device count
   - trial duration
   - re-download policy
4. Confirm the automatic license email reaches the purchaser inbox from the webhook flow.
5. Add support/refund policy text to the website before public paid launch.

## macOS Distribution Steps

1. Export release credentials:
   - `export CMDTAB_DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)'`
   - `export CMDTAB_NOTARY_PROFILE='cmdtab-notary-profile'`
2. Optionally set release metadata overrides:
   - `export CMDTAB_BUNDLE_ID='net.cmdtab.app'`
   - `export CMDTAB_VERSION='1.0.0'`
   - `export CMDTAB_BUILD_NUMBER='1'`
3. Run `./scripts/release_notarization_checklist.sh` for a human-readable preflight.
4. Build the signed, notarized DMG with `./scripts/build_release_dmg.sh`.
5. Upload the DMG from `dist/` and set that public file URL as `NEXT_PUBLIC_TRIAL_URL`.
6. Redeploy the website after the trial URL is live.
7. Test on a clean Mac:
   - install
   - Accessibility permission
   - Screen Recording permission
   - first switch
   - hot swap
   - quick actions

## Beta Exit Criteria

- Switching is reliable across your core target apps.
- Preview capture is reliable enough that the app feels trustworthy.
- Permission onboarding is understandable.
- At least 20 to 50 beta users have exercised real workflows.
- You have a working support inbox and refund policy before enabling paid launch.

## Nice-To-Have Before Paid Launch

- Actual recorded walkthrough videos for:
  - Classic Grid
  - Command Palette
  - Radial Menu
  - Quick Actions
  - Hot Swap
- Short onboarding screen inside the app for permissions and first use.
- Event tracking for:
  - download click
  - trial start
  - purchase complete
- Add `npm run security:check` to your deploy gate or CI before production releases.
