type ApplicantLicenseEmailInput = {
  name?: string;
  reasonLabel: string;
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

export const licenseEmailContent = {
  ownerNotification: {
    subject: "New CmdTab license support request",
    heading: "CmdTab license support request",
  },
  applicant: {
    subject: "We received your CmdTab license request",
    preview: "Your CmdTab license request is in the queue.",
    bullets: [
      "License recovery and receipt lookup",
      "Activation and purchase questions",
      "Billing and refund support",
    ],
    footer:
      "Reply to this email if you need to add more context before we get back to you.",
  },
} as const;

export function renderApplicantLicenseEmail(input: ApplicantLicenseEmailInput) {
  const safeSiteUrl = escapeHtml(input.siteUrl);
  const safeSubject = escapeHtml(licenseEmailContent.applicant.subject);
  const safeGreeting = escapeHtml(`Hi ${firstName(input.name)}, we received your CmdTab request.`);
  const safeReason = escapeHtml(input.reasonLabel);
  const safeFooter = escapeHtml(licenseEmailContent.applicant.footer);

  const text = [
    licenseEmailContent.applicant.preview,
    "",
    `Reason: ${input.reasonLabel}`,
    "",
    "What happens next:",
    "- We’ll review the request and reply by email.",
    "- If this is a purchase recovery request, keep the email address used at checkout handy.",
    "- If you need to add more detail, reply directly to this message.",
    "",
    `CmdTab: ${input.siteUrl}`,
    "",
    licenseEmailContent.applicant.footer,
  ].join("\n");

  const html = `
    <div style="background:#05070C;padding:40px 18px;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#E8EEF9;">
      <div style="max-width:640px;margin:0 auto;">
        <div style="margin-bottom:18px;border:1px solid rgba(121,175,255,0.24);border-radius:999px;background:rgba(121,175,255,0.08);padding:10px 16px;color:#A9D2FF;font-size:12px;font-weight:600;letter-spacing:0.18em;text-transform:uppercase;text-align:center;">
          CmdTab license help
        </div>
        <div style="position:relative;overflow:hidden;border:1px solid rgba(255,255,255,0.08);border-radius:30px;background:linear-gradient(180deg,rgba(17,24,39,0.92) 0%,rgba(8,12,22,0.96) 100%);box-shadow:0 24px 80px rgba(0,0,0,0.34);">
          <div style="position:absolute;inset:-80px auto auto -40px;width:220px;height:220px;border-radius:999px;background:radial-gradient(circle,rgba(111,211,255,0.22) 0%,rgba(111,211,255,0) 72%);"></div>
          <div style="position:relative;padding:34px 32px 30px;">
            <div style="display:inline-flex;align-items:center;gap:10px;margin-bottom:18px;padding:10px 14px;border-radius:18px;background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);">
              <div style="width:14px;height:14px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);"></div>
              <span style="font-size:13px;font-weight:600;color:#E8EEF9;">CmdTab</span>
            </div>
            <h1 style="margin:0 0 14px;font-size:34px;line-height:1.04;letter-spacing:-0.05em;color:#F7FAFF;">${safeSubject}</h1>
            <p style="margin:0 0 14px;font-size:16px;line-height:1.75;color:#D8E0EE;">${safeGreeting}</p>
            <p style="margin:0 0 14px;font-size:15px;line-height:1.8;color:#B7C3D9;">Request type: ${safeReason}</p>
            <p style="margin:0 0 14px;font-size:15px;line-height:1.8;color:#B7C3D9;">We’ll review the request and reply by email. If this is a purchase recovery request, keep the email address used at checkout nearby so we can verify the order quickly.</p>
            <div style="margin:28px 0 0;border-top:1px solid rgba(255,255,255,0.08);padding-top:22px;">
              <p style="margin:0 0 14px;font-size:12px;letter-spacing:0.2em;text-transform:uppercase;color:#8A97B0;">Support scope</p>
              <div style="display:grid;gap:10px;">
                ${licenseEmailContent.applicant.bullets
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
              <a href="${safeSiteUrl}/help" style="display:inline-block;padding:14px 20px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);color:#08111E;text-decoration:none;font-weight:700;font-size:14px;">
                Visit Help
              </a>
            </div>
            <p style="margin:22px 0 0;font-size:13px;line-height:1.75;color:#8A97B0;">${safeFooter}</p>
          </div>
        </div>
      </div>
    </div>
  `;

  return {
    subject: licenseEmailContent.applicant.subject,
    text,
    html,
  };
}
