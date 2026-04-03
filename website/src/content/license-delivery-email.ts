type LicenseDeliveryEmailInput = {
  email: string;
  name?: string;
  licenseKey: string;
  productName?: string;
  receiptUrl?: string;
  orderNumber?: number;
  siteUrl: string;
  testMode?: boolean;
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

export const licenseDeliveryEmailContent = {
  subject: "Your CmdTab license key",
  preview: "Your CmdTab purchase is confirmed and your license key is ready.",
  bullets: [
    "Paste the key into CmdTab > Settings > Licensing.",
    "The key activates this Mac without an online account.",
    "Keep the purchase email and key somewhere safe.",
  ],
  footer:
    "Reply to this email if you need activation help or need to recover the purchase later.",
} as const;

export function renderLicenseDeliveryEmail(input: LicenseDeliveryEmailInput) {
  const subject = input.testMode
    ? `[Test Mode] ${licenseDeliveryEmailContent.subject}`
    : licenseDeliveryEmailContent.subject;
  const greeting = `Hi ${firstName(input.name)}, your CmdTab license is ready.`;
  const productLine = input.productName
    ? `Purchase: ${input.productName}${input.orderNumber ? ` · Order #${input.orderNumber}` : ""}`
    : input.orderNumber
      ? `Order #${input.orderNumber}`
      : "CmdTab one-time purchase";

  const text = [
    licenseDeliveryEmailContent.preview,
    "",
    greeting,
    productLine,
    "",
    "License key:",
    input.licenseKey,
    "",
    "What to do next:",
    ...licenseDeliveryEmailContent.bullets.map((item) => `- ${item}`),
    input.receiptUrl ? `- Receipt: ${input.receiptUrl}` : null,
    "",
    `CmdTab help: ${input.siteUrl}/help`,
    "",
    licenseDeliveryEmailContent.footer,
  ]
    .filter(Boolean)
    .join("\n");

  const html = `
    <div style="background:#05070C;padding:40px 18px;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#E8EEF9;">
      <div style="max-width:680px;margin:0 auto;">
        <div style="margin-bottom:18px;border:1px solid rgba(121,175,255,0.24);border-radius:999px;background:rgba(121,175,255,0.08);padding:10px 16px;color:#A9D2FF;font-size:12px;font-weight:600;letter-spacing:0.18em;text-transform:uppercase;text-align:center;">
          ${escapeHtml(input.testMode ? "CmdTab test purchase" : "CmdTab purchase confirmed")}
        </div>
        <div style="position:relative;overflow:hidden;border:1px solid rgba(255,255,255,0.08);border-radius:30px;background:linear-gradient(180deg,rgba(17,24,39,0.92) 0%,rgba(8,12,22,0.96) 100%);box-shadow:0 24px 80px rgba(0,0,0,0.34);">
          <div style="position:absolute;inset:-80px auto auto -40px;width:220px;height:220px;border-radius:999px;background:radial-gradient(circle,rgba(111,211,255,0.22) 0%,rgba(111,211,255,0) 72%);"></div>
          <div style="position:relative;padding:34px 32px 30px;">
            <div style="display:inline-flex;align-items:center;gap:10px;margin-bottom:18px;padding:10px 14px;border-radius:18px;background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);">
              <div style="width:14px;height:14px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);"></div>
              <span style="font-size:13px;font-weight:600;color:#E8EEF9;">CmdTab</span>
            </div>
            <h1 style="margin:0 0 14px;font-size:34px;line-height:1.04;letter-spacing:-0.05em;color:#F7FAFF;">${escapeHtml(subject)}</h1>
            <p style="margin:0 0 14px;font-size:16px;line-height:1.75;color:#D8E0EE;">${escapeHtml(greeting)}</p>
            <p style="margin:0 0 18px;font-size:15px;line-height:1.8;color:#B7C3D9;">${escapeHtml(productLine)}</p>
            <div style="margin:22px 0;padding:18px 18px 16px;border-radius:22px;border:1px solid rgba(121,175,255,0.22);background:rgba(121,175,255,0.08);">
              <p style="margin:0 0 10px;font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#9CC6FF;">License key</p>
              <code style="display:block;word-break:break-word;font-size:14px;line-height:1.8;color:#F7FAFF;">${escapeHtml(input.licenseKey)}</code>
            </div>
            <div style="display:grid;gap:10px;">
              ${licenseDeliveryEmailContent.bullets
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
            <div style="margin-top:26px;display:flex;gap:12px;flex-wrap:wrap;">
              <a href="${escapeHtml(input.siteUrl)}/help" style="display:inline-block;padding:14px 20px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);color:#08111E;text-decoration:none;font-weight:700;font-size:14px;">
                Open Help
              </a>
              ${
                input.receiptUrl
                  ? `<a href="${escapeHtml(input.receiptUrl)}" style="display:inline-block;padding:14px 20px;border-radius:999px;border:1px solid rgba(255,255,255,0.12);color:#E8EEF9;text-decoration:none;font-weight:600;font-size:14px;background:rgba(255,255,255,0.04);">Open receipt</a>`
                  : ""
              }
            </div>
            <p style="margin:22px 0 0;font-size:13px;line-height:1.75;color:#8A97B0;">${escapeHtml(licenseDeliveryEmailContent.footer)}</p>
          </div>
        </div>
      </div>
    </div>
  `;

  return { subject, text, html };
}
