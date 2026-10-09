# Email drafts and list-use rules

## Audience rules

- The current live form requests trial access and promises an availability email. Do not assume this is consent for recurring promotional updates.
- Send the access/availability notice only to the address that requested it, when there is a real status change.
- Use the product-update sequence only for contacts with a separately recorded, affirmative marketing opt-in and a working unsubscribe/suppression path.
- The current flow has no double-opt-in link. Do not call a form submission a verified contact until address verification is implemented.
- Never use scraped or purchased addresses. The companion CSV is an empty schema, not a mailing list.

## Draft 1: requested-access verification (requires implementation)

**Subject:** Confirm your CmdTab trial waitlist request

You asked to join the CmdTab trial waitlist. Confirm this email address to verify your request:

**Confirm my email:** [single-use verification link]

If you did not request access, ignore this message. Confirming trial access does not subscribe you to product updates. [Manage email preferences]

## Draft 2: access request receipt (transactional)

**Subject:** Your CmdTab trial access request

Thanks for requesting CmdTab trial access. The app is in private preview, and there is no public download yet. We’ll email you when trial access is ready.

Read about the current product and permissions: https://cmdtab.net/trial

## Draft 3: product update (separately opted-in contacts only)

**Subject:** CmdTab update: [specific, verified progress]

You asked for occasional CmdTab product updates. [One concise, factual update about a real product change or preview milestone.]

The trial is still in private preview. We’ll send the access email when the download is ready.

Manage preferences or unsubscribe: [working one-click link]

## Draft 4: trial access is ready (send only after release verification)

**Subject:** Your CmdTab trial access is ready

The CmdTab trial is ready. Get the signed download, read the supported macOS version and required permissions, and follow the first-switch guide here: [verified access URL].

Need help? Reply to this email or visit [support URL].

Do not send this until the exact public build, download, permission guidance, and support path have been verified.
