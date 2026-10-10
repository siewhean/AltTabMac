import assert from "node:assert/strict";
import { readFileSync, statSync } from "node:fs";
import test from "node:test";

import {
  renderApplicantWaitlistEmail,
  WELCOME_ILLUSTRATION_ALT,
  WELCOME_ILLUSTRATION_PATH,
} from "../src/content/waitlist-email.js";

const base = {
  email: "ada@example.com",
  name: "Ada",
  variant: "new" as const,
  siteUrl: "https://cmdtab.net",
};
const full = {
  ...base,
  confirmUrl: "https://cmdtab.net/api/waitlist/confirm?token=t.1.sig",
  referralUrl: "https://cmdtab.net/?ref=abc23xyz&utm_source=referral",
  referralTarget: 5,
  unsubscribeUrl: "https://cmdtab.net/api/waitlist/unsubscribe?token=abc.def",
};

test("email HTML uses only constructs mail clients keep", () => {
  for (const html of [renderApplicantWaitlistEmail(base).html, renderApplicantWaitlistEmail(full).html]) {
    // Gmail and Outlook strip these, which collapses the layout.
    assert.doesNotMatch(html, /display:\s*(flex|grid|inline-flex)/i);
    assert.doesNotMatch(html, /position:\s*(absolute|relative)/i);
    assert.doesNotMatch(html, /(linear|radial)-gradient/i);
    assert.doesNotMatch(html, /\binset:/i);
    assert.match(html, /<table role="presentation"/);
    assert.match(html, /bgcolor="#101827"/);
  }
});

test("banner image is absolute, normalized, sized and described", () => {
  for (const siteUrl of ["https://cmdtab.net", "https://cmdtab.net/", "https://cmdtab.net//"]) {
    const { html } = renderApplicantWaitlistEmail({ ...base, siteUrl });
    assert.ok(html.includes(`src="https://cmdtab.net${WELCOME_ILLUSTRATION_PATH}"`), siteUrl);
    assert.doesNotMatch(html, /cmdtab\.net\/\/email/);
  }
  const { html } = renderApplicantWaitlistEmail(base);
  assert.match(html, /<img [^>]*width="600"/);
  assert.ok(html.includes(`alt="${WELCOME_ILLUSTRATION_ALT}"`));
});

test("the banner file ships with the site, is a JPEG, and stays email-light", () => {
  const file = `public${WELCOME_ILLUSTRATION_PATH}`;
  const bytes = readFileSync(file);
  assert.equal(bytes[0], 0xff);
  assert.equal(bytes[1], 0xd8);
  assert.ok(statSync(file).size < 150 * 1024, "banner must stay under 150 KB for email");
});

test("a hidden preheader carries the preview text first", () => {
  const { html } = renderApplicantWaitlistEmail(base);
  const first = html.trimStart();
  assert.match(first, /^<div style="display:none;/);
  assert.match(first, /Thanks for joining the CmdTab private beta list\./);
});

test("exactly one primary button: confirm when present, otherwise visit", () => {
  const withConfirm = renderApplicantWaitlistEmail(full).html;
  assert.equal((withConfirm.match(/background-color:#8FC8FF/g) ?? []).length, 1);
  assert.match(withConfirm, />Confirm my email</);
  assert.match(withConfirm, /<a href="https:\/\/cmdtab\.net" style="color:#8FBFFF;">Visit CmdTab<\/a>/);

  const without = renderApplicantWaitlistEmail(base).html;
  assert.equal((without.match(/background-color:#8FC8FF/g) ?? []).length, 1);
  assert.match(without, />Visit CmdTab</);
  assert.doesNotMatch(without, /Confirm my email/);
});

test("the unsubscribe link is in the footer of both formats when available", () => {
  const withLink = renderApplicantWaitlistEmail(full);
  assert.ok(withLink.html.includes('href="https://cmdtab.net/api/waitlist/unsubscribe?token=abc.def"'));
  assert.match(withLink.text, /Unsubscribe: https:\/\/cmdtab\.net\/api\/waitlist\/unsubscribe/);
  const without = renderApplicantWaitlistEmail(base);
  assert.doesNotMatch(without.html, /Unsubscribe/);
});

test("names and urls are escaped in HTML", () => {
  const { html } = renderApplicantWaitlistEmail({
    ...full,
    name: "<img/onerror=alert(1)>",
    referralUrl: 'https://cmdtab.net/?ref=a"b&x=<y>',
  });
  // The greeting uses only the first word of the name; it must still be escaped.
  assert.doesNotMatch(html, /<img\/onerror/);
  assert.match(html, /&lt;img\/onerror/);
  assert.ok(html.includes("ref=a&quot;b&amp;x=&lt;y&gt;"));
});

test("existing members get the existing-list wording", () => {
  const { subject, html } = renderApplicantWaitlistEmail({ ...base, variant: "existing" });
  assert.match(subject, /still on the CmdTab beta list/);
  assert.match(html, /already on the CmdTab private beta list/);
});
