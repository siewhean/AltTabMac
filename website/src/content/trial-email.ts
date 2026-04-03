type TrialEmailInput = {
  email: string;
  startedAt: string;
  endsAt: string;
  siteUrl: string;
};

function formatDate(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? value
    : new Intl.DateTimeFormat("en-SG", {
        dateStyle: "medium",
        timeStyle: "short",
        timeZone: "Asia/Singapore",
      }).format(date);
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function renderTrialStartedEmail(input: TrialEmailInput) {
  const subject = "Your CmdTab trial has started";
  const text = [
    "Your 14-day CmdTab trial is active.",
    "",
    `Email: ${input.email}`,
    `Started: ${formatDate(input.startedAt)}`,
    `Ends: ${formatDate(input.endsAt)}`,
    "",
    "You can keep using CmdTab on this Mac right away.",
    `Buy CmdTab: ${input.siteUrl}/buy`,
    `Help: ${input.siteUrl}/help`,
  ].join("\n");

  const html = `
    <div style="background:#05070C;padding:40px 18px;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#E8EEF9;">
      <div style="max-width:680px;margin:0 auto;border:1px solid rgba(255,255,255,0.08);border-radius:30px;background:linear-gradient(180deg,rgba(17,24,39,0.92) 0%,rgba(8,12,22,0.96) 100%);box-shadow:0 24px 80px rgba(0,0,0,0.34);overflow:hidden;">
        <div style="padding:34px 32px 30px;">
          <div style="display:inline-flex;align-items:center;gap:10px;margin-bottom:18px;padding:10px 14px;border-radius:18px;background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);">
            <div style="width:14px;height:14px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);"></div>
            <span style="font-size:13px;font-weight:600;color:#E8EEF9;">CmdTab</span>
          </div>
          <h1 style="margin:0 0 12px;font-size:34px;line-height:1.04;letter-spacing:-0.05em;color:#F7FAFF;">Your 14-day trial is active</h1>
          <p style="margin:0 0 18px;font-size:15px;line-height:1.8;color:#B7C3D9;">CmdTab is now unlocked on this Mac for the next 14 days.</p>
          <div style="display:grid;gap:10px;">
            <div style="padding:14px 16px;border-radius:20px;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);">
              <p style="margin:0;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#9CC6FF;">Started</p>
              <p style="margin:8px 0 0;font-size:15px;line-height:1.7;color:#E8EEF9;">${escapeHtml(formatDate(input.startedAt))}</p>
            </div>
            <div style="padding:14px 16px;border-radius:20px;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);">
              <p style="margin:0;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#9CC6FF;">Ends</p>
              <p style="margin:8px 0 0;font-size:15px;line-height:1.7;color:#E8EEF9;">${escapeHtml(formatDate(input.endsAt))}</p>
            </div>
          </div>
          <div style="margin-top:24px;display:flex;gap:12px;flex-wrap:wrap;">
            <a href="${escapeHtml(input.siteUrl)}/buy" style="display:inline-block;padding:14px 20px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);color:#08111E;text-decoration:none;font-weight:700;font-size:14px;">Buy CmdTab</a>
            <a href="${escapeHtml(input.siteUrl)}/help" style="display:inline-block;padding:14px 20px;border-radius:999px;border:1px solid rgba(255,255,255,0.12);color:#E8EEF9;text-decoration:none;font-weight:600;font-size:14px;background:rgba(255,255,255,0.04);">Open Help</a>
          </div>
        </div>
      </div>
    </div>
  `;

  return { subject, text, html };
}

export function renderTrialReminderEmail(input: TrialEmailInput) {
  const subject = "Your CmdTab trial ends tomorrow";
  const text = [
    "Your CmdTab trial ends tomorrow.",
    "",
    `Ends: ${formatDate(input.endsAt)}`,
    "",
    "If you want to keep using CmdTab after the trial, you can buy the one-time license now.",
    `Buy CmdTab: ${input.siteUrl}/buy`,
    `Help: ${input.siteUrl}/help`,
  ].join("\n");

  const html = `
    <div style="background:#05070C;padding:40px 18px;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#E8EEF9;">
      <div style="max-width:680px;margin:0 auto;border:1px solid rgba(255,255,255,0.08);border-radius:30px;background:linear-gradient(180deg,rgba(17,24,39,0.92) 0%,rgba(8,12,22,0.96) 100%);box-shadow:0 24px 80px rgba(0,0,0,0.34);overflow:hidden;">
        <div style="padding:34px 32px 30px;">
          <div style="display:inline-flex;align-items:center;gap:10px;margin-bottom:18px;padding:10px 14px;border-radius:18px;background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);">
            <div style="width:14px;height:14px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);"></div>
            <span style="font-size:13px;font-weight:600;color:#E8EEF9;">CmdTab</span>
          </div>
          <h1 style="margin:0 0 12px;font-size:34px;line-height:1.04;letter-spacing:-0.05em;color:#F7FAFF;">Your trial ends tomorrow</h1>
          <p style="margin:0 0 18px;font-size:15px;line-height:1.8;color:#B7C3D9;">If you want to keep using CmdTab after the 14-day trial, you can buy the one-time license now.</p>
          <div style="padding:14px 16px;border-radius:20px;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);">
            <p style="margin:0;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#9CC6FF;">Trial ends</p>
            <p style="margin:8px 0 0;font-size:15px;line-height:1.7;color:#E8EEF9;">${escapeHtml(formatDate(input.endsAt))}</p>
          </div>
          <div style="margin-top:24px;display:flex;gap:12px;flex-wrap:wrap;">
            <a href="${escapeHtml(input.siteUrl)}/buy" style="display:inline-block;padding:14px 20px;border-radius:999px;background:linear-gradient(135deg,#79AFFF 0%,#6FD3FF 100%);color:#08111E;text-decoration:none;font-weight:700;font-size:14px;">Buy CmdTab</a>
            <a href="${escapeHtml(input.siteUrl)}/help" style="display:inline-block;padding:14px 20px;border-radius:999px;border:1px solid rgba(255,255,255,0.12);color:#E8EEF9;text-decoration:none;font-weight:600;font-size:14px;background:rgba(255,255,255,0.04);">Open Help</a>
          </div>
        </div>
      </div>
    </div>
  `;

  return { subject, text, html };
}
