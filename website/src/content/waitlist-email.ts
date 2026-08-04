type ApplicantEmailVariant = "new" | "existing";

type ApplicantEmailInput = {
  name?: string;
  email: string;
  variant: ApplicantEmailVariant;
  siteUrl: string;
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
    onPageMessage: {
      new: "You’re on the list. We’ll email you if the next signed beta becomes available.",
      existing:
        "You were already on the list. We kept your place and will still email you about beta availability updates.",
    },
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
            "We’ll use this email to share beta availability updates and launch news if a signed beta is approved for publication.",
            "You do not need to sign up again. When a build is ready for you, this is the address we’ll contact.",
          ]
        : [
            "We kept your existing spot and will continue using this address for beta availability updates and launch news.",
            "You do not need to sign up again unless you want to change the email address on your spot.",
          ];
    },
    bullets: [
      "Private beta updates only",
      "Beta availability updates if a signed build is published",
      "No beta trial, purchase, or support operation is enabled by this signup",
    ],
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
    "",
    `CmdTab: ${input.siteUrl}`,
    "",
    waitlistEmailContent.applicant.footer,
  ].join("\n");

  const html = `
    <div style="background:#05070C;padding:40px 18px;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#E8EEF9;">
      <div style="max-width:640px;margin:0 auto;">
        <div style="margin-bottom:18px;border:1px solid rgba(121,175,255,0.24);border-radius:999px;background:rgba(121,175,255,0.08);padding:10px 16px;color:#A9D2FF;font-size:12px;font-weight:600;letter-spacing:0.18em;text-transform:uppercase;text-align:center;">
          CmdTab private beta
        </div>
        <div style="position:relative;overflow:hidden;border:1px solid rgba(255,255,255,0.08);border-radius:30px;background:linear-gradient(180deg,rgba(17,24,39,0.92) 0%,rgba(8,12,22,0.96) 100%);box-shadow:0 24px 80px rgba(0,0,0,0.34);">
          <div style="position:absolute;inset:-80px auto auto -40px;width:220px;height:220px;border-radius:999px;background:radial-gradient(circle,rgba(111,211,255,0.22) 0%,rgba(111,211,255,0) 72%);"></div>
          <div style="position:absolute;inset:auto -60px -110px auto;width:260px;height:260px;border-radius:999px;background:radial-gradient(circle,rgba(121,175,255,0.18) 0%,rgba(121,175,255,0) 75%);"></div>
          <div style="position:relative;padding:34px 32px 30px;">
            <div style="display:inline-flex;align-items:center;gap:10px;margin-bottom:18px;padding:10px 14px;border-radius:18px;background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);">
              <div style="width:14px;height:14px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);"></div>
              <span style="font-size:13px;font-weight:600;color:#E8EEF9;">CmdTab</span>
            </div>
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
              <div style="display:grid;gap:10px;">
                ${waitlistEmailContent.applicant.bullets
                  .map(
                    (item) => `
                      <div style="display:flex;gap:12px;align-items:flex-start;padding:12px 14px;border-radius:18px;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);">
                        <div style="width:8px;height:8px;margin-top:7px;border-radius:999px;background:#79AFFF;flex:0 0 auto;"></div>
                        <p style="margin:0;font-size:14px;line-height:1.7;color:#D8E0EE;">${escapeHtml(item)}</p>
                      </div>
                    `,
                  )
                  .join("")}
              </div>
            </div>
            <div style="margin-top:26px;">
              <a href="${safeSiteUrl}" style="display:inline-block;padding:14px 20px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);color:#08111E;text-decoration:none;font-weight:700;font-size:14px;">
                ${escapeHtml(waitlistEmailContent.applicant.ctaLabel)}
              </a>
            </div>
            <p style="margin:22px 0 0;font-size:13px;line-height:1.75;color:#8A97B0;">${safeFooter}</p>
          </div>
        </div>
        <p style="margin:16px 0 0;text-align:center;font-size:12px;line-height:1.7;color:#657189;">
          You’re receiving this because you joined the CmdTab beta list.
        </p>
      </div>
    </div>
  `;

  return { subject, text, html };
}
