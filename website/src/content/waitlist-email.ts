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

/**
 * Banner artwork served from /public. Decorative concept art, not a product
 * screenshot, so it has empty alt text: when a mail client blocks remote
 * images (Outlook and Gmail do for unknown senders), the row collapses
 * instead of showing a line of alt text.
 */
export const WELCOME_ILLUSTRATION_PATH = "/email/cmdtab-welcome-illustration.jpg";
export const WELCOME_ILLUSTRATION_ALT = "";

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
      "Thanks, you’re in the CmdTab private beta. We’ll email you the moment a beta build is ready.",
    subject(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? "You’re in the CmdTab private beta"
        : "You’re still in the CmdTab private beta";
    },
    preview(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? "You’re in. We’ll email you as soon as a beta build is ready."
        : "Your CmdTab beta signup is still active.";
    },
    intro(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? `Hi ${firstName(input.name)}, you’re in the CmdTab private beta.`
        : `Hi ${firstName(input.name)}, you’re already in the CmdTab private beta.`;
    },
    body(input: ApplicantEmailInput) {
      return input.variant === "new"
        ? [
            "There’s nothing else to do. We’ll email this address the moment a beta build is ready for your Mac, and share launch news.",
            "While you wait, you can try the switcher in your browser. It takes about 20 seconds and needs no install.",
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
    demo: {
      cta: "Try it in your browser",
      path: "/#demo",
    },
    verify: {
      body: "Optional: verify your email so your invitations count toward the reward.",
      cta: "Verify my email",
    },
    referral: {
      heading: "Earn a CmdTab license",
      body: (target: number) =>
        `Invite ${target} friends. When ${target} of them verify their email, you earn a free license after a quick review. The beta reward is limited to the first 100 members. Each friend must be a different person on their own device and network; duplicate, disposable, or same-device invitations don’t count.`,
      cta: "Your personal invite link",
    },
    footer:
      "If you need to update your signup details, just reply to this email and we’ll sort it out.",
  },
} as const;

export function renderApplicantWaitlistEmail(input: ApplicantEmailInput) {
  const content = waitlistEmailContent.applicant;
  const intro = content.intro(input);
  const body = content.body(input);
  const subject = content.subject(input);
  const preview = content.preview(input);
  const safeSubject = escapeHtml(subject);
  const safeIntro = escapeHtml(intro);
  const safeFooter = escapeHtml(content.footer);
  const safePreview = escapeHtml(preview);
  const siteUrl = input.siteUrl.replace(/\/+$/, "");
  const demoUrl = `${siteUrl}${content.demo.path}`;
  const safeImageUrl = escapeHtml(`${siteUrl}${WELCOME_ILLUSTRATION_PATH}`);
  const target = input.referralTarget ?? 5;

  const text = [
    preview,
    "",
    intro,
    "",
    ...body,
    "",
    "What to expect:",
    ...content.bullets.map((item) => `- ${item}`),
    "",
    `${content.demo.cta}: ${demoUrl}`,
    ...(input.referralUrl
      ? [
          "",
          `${content.referral.heading}:`,
          content.referral.body(target),
          `${content.referral.cta}: ${input.referralUrl}`,
        ]
      : []),
    ...(input.confirmUrl ? ["", `${content.verify.body}`, `${content.verify.cta}: ${input.confirmUrl}`] : []),
    "",
    content.footer,
    ...(input.unsubscribeUrl ? ["", `Unsubscribe: ${input.unsubscribeUrl}`] : []),
  ].join("\n");

  // Email clients (Gmail, Outlook) strip flex, grid, positioning, and gradients,
  // so the layout is tables with inline styles and solid colors only. The one
  // intentional exception is the hidden preheader (display:none), which is the
  // standard way to set the inbox preview text.
  const buttonCell = (href: string, label: string) =>
    `<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td align="center" bgcolor="#8FC8FF" style="border-radius:8px;background-color:#8FC8FF;"><a href="${escapeHtml(href)}" style="display:inline-block;padding:13px 20px;color:#08111E;text-decoration:none;font-size:14px;line-height:20px;font-weight:bold;">${escapeHtml(label)}</a></td></tr></table>`;

  const panelHeading = (label: string) =>
    `<p style="margin:0 0 8px;color:#9FB2CF;font-size:12px;line-height:18px;font-weight:bold;letter-spacing:1.5px;text-transform:uppercase;">${escapeHtml(label)}</p>`;

  const linkStyle = "color:#8FBFFF;";

  // One panel for the reward and the optional verification, so the main
  // message stays "you're in" and verification is clearly a side option.
  const rewardBlock =
    input.referralUrl || input.confirmUrl
      ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:22px;"><tr><td bgcolor="#162238" style="padding:18px 20px;background-color:#162238;border:1px solid #263247;border-radius:10px;">${
          input.referralUrl
            ? `${panelHeading(content.referral.heading)}<p style="margin:0 0 12px;color:#D8E0EE;font-size:14px;line-height:22px;">${escapeHtml(content.referral.body(target))}</p><p style="margin:0 0 ${input.confirmUrl ? "14" : "0"}px;font-size:14px;line-height:22px;word-break:break-all;">${escapeHtml(content.referral.cta)}: <a href="${escapeHtml(input.referralUrl)}" style="${linkStyle}">${escapeHtml(input.referralUrl)}</a></p>`
            : ""
        }${
          input.confirmUrl
            ? `<p style="margin:0;color:#B7C3D9;font-size:13px;line-height:21px;">${escapeHtml(content.verify.body)} <a href="${escapeHtml(input.confirmUrl)}" style="${linkStyle}">${escapeHtml(content.verify.cta)}</a></p>`
            : ""
        }</td></tr></table>`
      : "";

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
          <tr><td bgcolor="#101827" style="padding:0;background-color:#101827;font-size:0;line-height:0;">
            <img src="${safeImageUrl}" width="600" alt="${escapeHtml(WELCOME_ILLUSTRATION_ALT)}" style="display:block;width:100%;max-width:600px;height:auto;border:0;line-height:100%;outline:none;text-decoration:none;font-size:0;color:#101827;">
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
              ${content.bullets
                .map(
                  (item) => `<tr><td width="18" valign="top" style="padding:5px 0;color:#79AFFF;font-size:16px;line-height:22px;">&#8226;</td><td style="padding:5px 0;color:#D8E0EE;font-size:14px;line-height:22px;">${escapeHtml(item)}</td></tr>`,
                )
                .join("")}
            </table>
            <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin-top:24px;"><tr><td>${buttonCell(demoUrl, content.demo.cta)}</td></tr></table>
            ${rewardBlock}
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
