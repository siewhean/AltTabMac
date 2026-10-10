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

/** Banner artwork served from /public. Decorative concept art, not a product screenshot. */
export const WELCOME_ILLUSTRATION_PATH = "/email/cmdtab-welcome-illustration.jpg";
export const WELCOME_ILLUSTRATION_ALT =
  "Conceptual artwork of desktop windows, with one window highlighted in cyan.";

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
        `Invite ${target} friends. When ${target} of them confirm their email, you get a free CmdTab license after a quick review. The beta reward is limited to the first 100 members. Each friend must be a different person on their own device and network; duplicate, disposable, or same-device invitations don’t count.`,
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
  const safePreview = escapeHtml(preview);
  const siteUrl = input.siteUrl.replace(/\/+$/, "");
  const safeSiteUrl = escapeHtml(siteUrl);
  const safeImageUrl = escapeHtml(`${siteUrl}${WELCOME_ILLUSTRATION_PATH}`);

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

  // Email clients (Gmail, Outlook) strip flex, grid, positioning, and gradients,
  // so the layout is tables with inline styles and solid colors only. The one
  // intentional exception is the hidden preheader (display:none), which is the
  // standard way to set the inbox preview text.
  const buttonCell = (href: string, label: string) =>
    `<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td align="center" bgcolor="#8FC8FF" style="border-radius:8px;background-color:#8FC8FF;"><a href="${escapeHtml(href)}" style="display:inline-block;padding:13px 20px;color:#08111E;text-decoration:none;font-size:14px;line-height:20px;font-weight:bold;">${escapeHtml(label)}</a></td></tr></table>`;

  const panel = (borderColor: string, inner: string) =>
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:22px;"><tr><td bgcolor="#162238" style="padding:18px 20px;background-color:#162238;border:1px solid ${borderColor};border-radius:10px;">${inner}</td></tr></table>`;

  const panelHeading = (label: string) =>
    `<p style="margin:0 0 8px;color:#9FB2CF;font-size:12px;line-height:18px;font-weight:bold;letter-spacing:1.5px;text-transform:uppercase;">${escapeHtml(label)}</p>`;

  const confirmBlock = input.confirmUrl
    ? panel(
        "#2C4263",
        `${panelHeading(waitlistEmailContent.applicant.confirm.heading)}<p style="margin:0 0 14px;color:#D8E0EE;font-size:14px;line-height:22px;">${escapeHtml(waitlistEmailContent.applicant.confirm.body)}</p>${buttonCell(input.confirmUrl, waitlistEmailContent.applicant.confirm.cta)}`,
      )
    : "";

  const referralBlock = input.referralUrl
    ? panel(
        "#263247",
        `${panelHeading(waitlistEmailContent.applicant.referral.heading)}<p style="margin:0 0 12px;color:#D8E0EE;font-size:14px;line-height:22px;">${escapeHtml(waitlistEmailContent.applicant.referral.body(input.referralTarget ?? 5))}</p><p style="margin:0;font-size:14px;line-height:22px;word-break:break-all;"><a href="${escapeHtml(input.referralUrl)}" style="color:#8FBFFF;">${escapeHtml(input.referralUrl)}</a></p>`,
      )
    : "";

  // One primary button per email: the confirm button when there is one,
  // otherwise the visit button. The visit link then drops to plain text.
  const visitBlock = input.confirmUrl
    ? `<p style="margin:22px 0 0;font-size:14px;line-height:22px;"><a href="${safeSiteUrl}" style="color:#8FBFFF;">${escapeHtml(waitlistEmailContent.applicant.ctaLabel)}</a></p>`
    : `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin-top:24px;"><tr><td>${buttonCell(siteUrl, waitlistEmailContent.applicant.ctaLabel)}</td></tr></table>`;

  const html = `
    <div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;color:#080D18;">
      ${safePreview}${"&nbsp;&#847;".repeat(60)}
    </div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#080D18" style="width:100%;margin:0;background-color:#080D18;font-family:Arial,Helvetica,sans-serif;color:#E8EEF9;">
      <tr><td align="center" style="padding:28px 12px;">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;border-collapse:separate;border-spacing:0;">
          <tr><td align="center" bgcolor="#111A2B" style="padding:12px 16px;border:1px solid #243550;border-radius:12px 12px 0 0;color:#B9D8FF;font-size:12px;line-height:18px;font-weight:bold;letter-spacing:2px;text-transform:uppercase;">
            CmdTab private beta
          </td></tr>
          <tr><td bgcolor="#101827" style="padding:0;background-color:#101827;">
            <img src="${safeImageUrl}" width="600" alt="${escapeHtml(WELCOME_ILLUSTRATION_ALT)}" style="display:block;width:100%;max-width:600px;height:auto;border:0;line-height:100%;outline:none;text-decoration:none;">
          </td></tr>
          <tr><td bgcolor="#101827" style="padding:28px 30px 30px;border:1px solid #263247;border-top:0;border-radius:0 0 12px 12px;background-color:#101827;">
            <p style="margin:0 0 10px;color:#8FBFFF;font-size:13px;line-height:20px;font-weight:bold;">CMDTAB</p>
            <h1 style="margin:0 0 14px;color:#F7FAFF;font-size:30px;line-height:36px;font-weight:700;">${safeSubject}</h1>
            <p style="margin:0 0 18px;color:#D8E0EE;font-size:16px;line-height:26px;">${safeIntro}</p>
            ${body
              .map(
                (paragraph) =>
                  `<p style="margin:0 0 14px;color:#B7C3D9;font-size:15px;line-height:25px;">${escapeHtml(paragraph)}</p>`,
              )
              .join("")}
            <p style="margin:24px 0 12px;padding-top:18px;border-top:1px solid #2A3548;color:#8A97B0;font-size:12px;line-height:18px;font-weight:bold;letter-spacing:1.5px;text-transform:uppercase;">What to expect</p>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              ${waitlistEmailContent.applicant.bullets
                .map(
                  (item) => `<tr><td width="18" valign="top" style="padding:5px 0;color:#79AFFF;font-size:16px;line-height:22px;">&#8226;</td><td style="padding:5px 0;color:#D8E0EE;font-size:14px;line-height:22px;">${escapeHtml(item)}</td></tr>`,
                )
                .join("")}
            </table>
            ${confirmBlock}
            ${referralBlock}
            ${visitBlock}
            <p style="margin:22px 0 0;color:#8A97B0;font-size:13px;line-height:21px;">${safeFooter}</p>
          </td></tr>
          <tr><td align="center" style="padding:14px 10px 0;color:#7B879A;font-size:12px;line-height:19px;">
            You’re receiving this because you joined the CmdTab beta list.${
              input.unsubscribeUrl
                ? ` <a href="${escapeHtml(input.unsubscribeUrl)}" style="color:#9AA7BD;text-decoration:underline;">Unsubscribe</a>`
                : ""
            }
          </td></tr>
        </table>
      </td></tr>
    </table>
  `;

  return { subject, text, html };
}
