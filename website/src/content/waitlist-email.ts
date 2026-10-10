type ApplicantEmailVariant = "new" | "existing";

type ApplicantEmailInput = {
  name?: string;
  email: string;
  variant: ApplicantEmailVariant;
  siteUrl: string;
  /** Signed unsubscribe link; omitted when no unsubscribe secret is configured. */
  unsubscribeUrl?: string;
  /** Personal invite link; omitted when referrals are unavailable. */
  referralUrl?: string;
  /** Signed link that confirms the address; omitted when no secret is configured. */
  confirmUrl?: string;
  /** Confirmed friends needed for the free license. */
  referralTarget?: number;
};

function firstName(name?: string) {
  if (!name) return "there";
  return name.trim().split(/\s+/)[0] || "there";
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export const waitlistEmailContent = {
  ownerNotification: {
    subject: "New CmdTab private beta waitlist signup",
    heading: "CmdTab private beta waitlist submission",
  },
  applicant: {
    // One message for new and existing signups, so the form never reveals
    // whether an address is already on the list. The email itself (sent only
    // to that address) says which case applies.
    onPageMessage:
      "Thanks, you’re on the list. Check your inbox and confirm your email address, and we’ll email you when the next beta opens.",
    subject(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? "You’re on the CmdTab beta list"
        : "You’re still on the CmdTab beta list";
    },
    preview(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? "Thanks for joining the CmdTab private beta list."
        : "Your CmdTab beta signup is still active.";
    },
    intro(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? `Hi ${firstName(input.name)}, thanks for joining the CmdTab private beta list.`
        : `Hi ${firstName(input.name)}, you’re already on the CmdTab private beta list.`;
    },
    body(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? [
            "We’ll use this email to share beta access updates, launch news, and first access to the trial when it’s ready.",
            "You do not need to sign up again. When a build is ready for you, this is the address we’ll contact.",
          ]
        : [
            "We kept your existing spot and will continue using this address for beta access updates, launch news, and first access to the trial.",
            "You do not need to sign up again unless you want to change the email address on your spot.",
          ];
    },
    bullets: [
      "Private beta updates only",
      "First access to the trial when it is ready",
    ],
    confirm: {
      heading: "Confirm your email",
      body: "Confirm this address so we know it’s really yours. Your free-license progress only counts once you’ve confirmed.",
      cta: "Confirm my email",
    },
    referral: {
      heading: "Get CmdTab free",
      body: (target: number) =>
        `Invite ${target} friends. When ${target} of them confirm their email, you get a free CmdTab license after a quick review. Each friend must be a different person on their own device and network; duplicate, disposable, or same-device invitations don’t count.`,
      cta: "Your invite link",
    },
    ctaLabel: "Visit CmdTab",
    footer:
      "If you need to update your signup details, just reply to this email and we’ll sort it out.",
  },
} as const;

export function renderApplicantWaitlistEmail(input: ApplicantEmailInput) {
  const intro = waitlistEmailContent.applicant.intro(input);
  const body = waitlistEmailContent.applicant.body(input);
  const subject = waitlistEmailContent.applicant.subject(input);
  const preview = waitlistEmailContent.applicant.preview(input);
  const safeSubject = escapeHtml(subject);
  const safeIntro = escapeHtml(intro);
  const safeFooter = escapeHtml(waitlistEmailContent.applicant.footer);
  const safeSiteUrl = escapeHtml(input.siteUrl);

  const text = [
    preview,
    "",
    intro,
    "",
    ...body,
    "",
    "What to expect:",
    ...waitlistEmailContent.applicant.bullets.map((item) => `- ${item}`),
    ...(input.confirmUrl
      ? [
          "",
          `${waitlistEmailContent.applicant.confirm.heading}:`,
          waitlistEmailContent.applicant.confirm.body,
          `${waitlistEmailContent.applicant.confirm.cta}: ${input.confirmUrl}`,
        ]
      : []),
    ...(input.referralUrl
      ? [
          "",
          `${waitlistEmailContent.applicant.referral.heading}:`,
          waitlistEmailContent.applicant.referral.body(input.referralTarget ?? 5),
          `${waitlistEmailContent.applicant.referral.cta}: ${input.referralUrl}`,
        ]
      : []),
    "",
    `CmdTab: ${input.siteUrl}`,
    "",
    waitlistEmailContent.applicant.footer,
    ...(input.unsubscribeUrl ? ["", `Unsubscribe: ${input.unsubscribeUrl}`] : []),
  ].join("\n");

  const html = `
    <div style="background:#05070C;padding:40px 18px;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#E8EEF9;">
      <div style="max-width:640px;margin:0 auto;">
        <div style="margin-bottom:18px;border:1px solid rgba(121,175,255,0.24);border-radius:999px;background:rgba(121,175,255,0.08);padding:10px 16px;color:#A9D2FF;font-size:12px;font-weight:600;letter-spacing:0.18em;text-transform:uppercase;text-align:center;">
          CmdTab private beta
        </div>
        <!-- Email-safe layout: Gmail strips position, flex/grid, and gradients,
             so the card uses solid colors and tables only. -->
        <div style="border:1px solid #1C2433;border-radius:30px;background-color:#0E1421;">
          <div style="padding:34px 32px 30px;">
            <p style="margin:0 0 18px;font-size:13px;font-weight:600;color:#A9D2FF;">&#9679;&nbsp; CmdTab</p>
            <h1 style="margin:0 0 14px;font-size:34px;line-height:1.04;letter-spacing:-0.05em;color:#F7FAFF;">${safeSubject}</h1>
            <p style="margin:0 0 20px;font-size:16px;line-height:1.75;color:#D8E0EE;">${safeIntro}</p>
        ${body
          .map(
            (paragraph) =>
              `<p style="margin:0 0 14px;font-size:15px;line-height:1.8;color:#B7C3D9;">${escapeHtml(paragraph)}</p>`,
          )
          .join("")}
            <div style="margin:28px 0 0;border-top:1px solid rgba(255,255,255,0.08);padding-top:22px;">
              <p style="margin:0 0 14px;font-size:12px;letter-spacing:0.2em;text-transform:uppercase;color:#8A97B0;">What to expect</p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;border-spacing:0 10px;">
                ${waitlistEmailContent.applicant.bullets
                  .map(
                    (item) => `
                      <tr>
                        <td width="22" valign="top" style="padding:12px 0 12px 14px;background-color:#131A28;border-radius:18px 0 0 18px;color:#79AFFF;font-size:14px;line-height:1.7;">&#9679;</td>
                        <td style="padding:12px 14px 12px 6px;background-color:#131A28;border-radius:0 18px 18px 0;font-size:14px;line-height:1.7;color:#D8E0EE;">${escapeHtml(item)}</td>
                      </tr>
                    `,
                  )
                  .join("")}
              </table>
            </div>
            ${
              input.confirmUrl
                ? `<div style="margin:26px 0 0;border:1px solid rgba(121,175,255,0.24);border-radius:20px;background-color:#131A28;padding:18px 20px;">
              <p style="margin:0 0 8px;font-size:12px;letter-spacing:0.2em;text-transform:uppercase;color:#8A97B0;">${escapeHtml(waitlistEmailContent.applicant.confirm.heading)}</p>
              <p style="margin:0 0 14px;font-size:14px;line-height:1.7;color:#D8E0EE;">${escapeHtml(waitlistEmailContent.applicant.confirm.body)}</p>
              <a href="${escapeHtml(input.confirmUrl)}" style="display:inline-block;padding:12px 18px;border-radius:999px;background-color:#79AFFF;color:#08111E;text-decoration:none;font-weight:700;font-size:14px;">${escapeHtml(waitlistEmailContent.applicant.confirm.cta)}</a>
            </div>`
                : ""
            }
            ${
              input.referralUrl
                ? `<div style="margin:18px 0 0;border:1px solid rgba(255,255,255,0.1);border-radius:20px;background-color:#131A28;padding:18px 20px;">
              <p style="margin:0 0 8px;font-size:12px;letter-spacing:0.2em;text-transform:uppercase;color:#8A97B0;">${escapeHtml(waitlistEmailContent.applicant.referral.heading)}</p>
              <p style="margin:0 0 12px;font-size:14px;line-height:1.7;color:#D8E0EE;">${escapeHtml(waitlistEmailContent.applicant.referral.body(input.referralTarget ?? 5))}</p>
              <p style="margin:0;font-size:14px;line-height:1.6;word-break:break-all;"><a href="${escapeHtml(input.referralUrl)}" style="color:#79AFFF;">${escapeHtml(input.referralUrl)}</a></p>
            </div>`
                : ""
            }
            <div style="margin-top:26px;">
              <a href="${safeSiteUrl}" style="display:inline-block;padding:14px 20px;border-radius:999px;background-color:#79AFFF;color:#08111E;text-decoration:none;font-weight:700;font-size:14px;">
                ${escapeHtml(waitlistEmailContent.applicant.ctaLabel)}
              </a>
            </div>
            <p style="margin:22px 0 0;font-size:13px;line-height:1.75;color:#8A97B0;">${safeFooter}</p>
          </div>
        </div>
        <p style="margin:16px 0 0;text-align:center;font-size:12px;line-height:1.7;color:#657189;">
          You’re receiving this because you joined the CmdTab beta list.${
            input.unsubscribeUrl
              ? ` <a href="${escapeHtml(input.unsubscribeUrl)}" style="color:#8A97B0;text-decoration:underline;">Unsubscribe</a>`
              : ""
          }
        </p>
      </div>
    </div>
  `;

  return { subject, text, html };
}
