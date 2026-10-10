import assert from "node:assert/strict";
import test from "node:test";

import { renderApplicantWaitlistEmail } from "../src/content/waitlist-email.js";
import {
  collectWaitlistAttribution,
  parseCampaignParams,
} from "../src/lib/waitlist-attribution.js";
import {
  createWaitlistConfirmToken,
  CONFIRM_TOKEN_TTL_SECONDS,
  verifyWaitlistConfirmToken,
} from "../src/lib/waitlist-confirm.js";
import {
  canonicalEmail,
  evaluateReferrals,
  generateReferralCode,
  isDisposableEmail,
  networkKey,
  normalizeReferralCode,
  referralUrl,
  REFERRAL_REWARD_TARGET,
  type ReferralInvitee,
  type ReferralInviter,
} from "../src/lib/waitlist-referral.js";

const inviter: ReferralInviter = {
  canonicalEmail: "host@example.com",
  deviceHash: "dev-host",
  networkHash: "net-host",
  confirmed: true,
};

function friend(n: number, overrides: Partial<ReferralInvitee> = {}): ReferralInvitee {
  return {
    id: `f${n}`,
    canonicalEmail: `friend${n}@example.org`,
    disposable: false,
    deviceHash: `dev-${n}`,
    networkHash: `net-${n}`,
    confirmNetworkHash: `cnet-${n}`,
    signupsFromDevice: 1,
    confirmedAt: `2026-10-1${n}T00:00:00Z`,
    ...overrides,
  };
}

test("generated referral codes are well-formed and unambiguous", () => {
  const seen = new Set<string>();
  for (let index = 0; index < 500; index += 1) {
    const code = generateReferralCode();
    assert.match(code, /^[a-z0-9]{8}$/);
    assert.doesNotMatch(code, /[01oli]/);
    seen.add(code);
  }
  assert.equal(seen.size, 500);
});

test("referral codes are normalized and hostile input is rejected", () => {
  assert.equal(normalizeReferralCode("  AbC23xyz "), "abc23xyz");
  for (const bad of ["", "abc", "a".repeat(13), "abc 12345", "abc'; drop", "../etc", null, undefined, 42]) {
    assert.equal(normalizeReferralCode(bad), undefined);
  }
  const url = new URL(referralUrl("https://cmdtab.net/", "abc23xyz"));
  assert.equal(url.searchParams.get("ref"), "abc23xyz");
});

test("aliases of one mailbox collapse; unrelated addresses do not", () => {
  assert.equal(canonicalEmail("First.Last+promo@Gmail.com"), "firstlast@gmail.com");
  assert.equal(canonicalEmail("f.irst@googlemail.com"), "first@gmail.com");
  assert.equal(canonicalEmail("a+tag@outlook.com"), "a@outlook.com");
  // Dots and plus tags can be significant elsewhere, so they are preserved.
  assert.equal(canonicalEmail("a.b+c@example.com"), "a.b+c@example.com");
  assert.notEqual(canonicalEmail("a@example.com"), canonicalEmail("b@example.com"));
});

test("disposable mailbox providers and their subdomains are recognised", () => {
  assert.equal(isDisposableEmail("x@mailinator.com"), true);
  assert.equal(isDisposableEmail("x@abc.mailinator.com"), true);
  assert.equal(isDisposableEmail("x@gmail.com"), false);
  assert.equal(isDisposableEmail("x@notmailinator.com"), false);
});

test("network key groups IPv4 /24 and IPv6 /64 and rejects junk", () => {
  assert.equal(networkKey("203.0.113.5"), networkKey("203.0.113.250"));
  assert.notEqual(networkKey("203.0.113.5"), networkKey("203.0.114.5"));
  assert.equal(networkKey("::ffff:203.0.113.9"), networkKey("203.0.113.1"));
  assert.equal(networkKey("2001:db8:1:2:aaaa:bbbb:cccc:dddd"), networkKey("2001:db8:1:2::1"));
  assert.notEqual(networkKey("2001:db8:1:3::1"), networkKey("2001:db8:1:2::1"));
  for (const bad of ["unknown", "", null, undefined, "999.1.1.1", "not-an-ip", "1:2:3"]) {
    assert.equal(networkKey(bad as string | null | undefined), undefined);
  }
});

test("five distinct, confirmed friends earn the reward", () => {
  const result = evaluateReferrals(inviter, [1, 2, 3, 4, 5].map((n) => friend(n)));
  assert.equal(result.qualified, REFERRAL_REWARD_TARGET);
  assert.equal(result.rewardEarned, true);
  assert.ok(result.verdicts.every((verdict) => verdict.status === "qualified"));
});

test("unconfirmed friends are pending and never counted", () => {
  const result = evaluateReferrals(inviter, [friend(1, { confirmedAt: null })]);
  assert.deepEqual(result.verdicts, [{ id: "f1", status: "pending" }]);
  assert.equal(result.qualified, 0);
});

test("an unconfirmed inviter cannot earn the reward", () => {
  const result = evaluateReferrals({ ...inviter, confirmed: false }, [1, 2, 3, 4, 5].map((n) => friend(n)));
  assert.equal(result.qualified, 5);
  assert.equal(result.rewardEarned, false);
});

test("self-invites, aliases, disposable mail and shared devices or networks are flagged", () => {
  const cases: Array<[Partial<ReferralInvitee>, string]> = [
    [{ canonicalEmail: "host@example.com" }, "same_person_email"],
    [{ disposable: true }, "disposable_email"],
    [{ deviceHash: "dev-host" }, "same_device_as_inviter"],
    [{ networkHash: "net-host" }, "same_network_as_inviter"],
    [{ confirmNetworkHash: "net-host" }, "same_network_as_inviter"],
    [{ signupsFromDevice: 3 }, "device_used_for_multiple_signups"],
    [{ deviceHash: null }, "missing_device_signals"],
    [{ networkHash: null }, "missing_device_signals"],
  ];
  for (const [override, flag] of cases) {
    const result = evaluateReferrals(inviter, [friend(1, override)]);
    assert.equal(result.verdicts[0].status, "flagged", flag);
    assert.equal(result.verdicts[0].flag, flag);
    assert.equal(result.qualified, 0);
  }
});

test("a missing inviter signal fails closed", () => {
  const result = evaluateReferrals({ ...inviter, deviceHash: null }, [friend(1)]);
  assert.equal(result.verdicts[0].flag, "missing_device_signals");
});

test("friends sharing a device or network with each other count once, earliest first", () => {
  const result = evaluateReferrals(inviter, [
    friend(1),
    friend(2, { deviceHash: "dev-1" }),
    friend(3, { networkHash: "net-1" }),
  ]);
  const byId = Object.fromEntries(result.verdicts.map((verdict) => [verdict.id, verdict]));
  assert.equal(byId.f1.status, "qualified");
  assert.equal(byId.f2.flag, "same_device_as_other_invitee");
  assert.equal(byId.f3.flag, "same_network_as_other_invitee");
  assert.equal(result.qualified, 1);
  assert.equal(result.rewardEarned, false);
});

test("a flagged friend does not block a legitimate later one", () => {
  const result = evaluateReferrals(inviter, [
    friend(1, { disposable: true, deviceHash: "dev-shared", networkHash: "net-shared" }),
    friend(2, { deviceHash: "dev-shared", networkHash: "net-shared" }),
  ]);
  assert.equal(result.verdicts[0].status, "flagged");
  assert.equal(result.verdicts[1].status, "qualified");
});

test("four good friends plus one abusive friend do not earn the reward", () => {
  const result = evaluateReferrals(inviter, [
    ...[1, 2, 3, 4].map((n) => friend(n)),
    friend(5, { deviceHash: "dev-host" }),
  ]);
  assert.equal(result.qualified, 4);
  assert.equal(result.rewardEarned, false);
});

test("retention purges never downgrade an already qualified referral", () => {
  const result = evaluateReferrals(inviter, [
    friend(1, { deviceHash: null, networkHash: null, priorStatus: "qualified" }),
  ]);
  assert.equal(result.verdicts[0].status, "qualified");
});

test("confirmation tokens round-trip, expire, and cannot be forged", () => {
  const secret = "s".repeat(48);
  const now = 1_800_000_000;
  const token = createWaitlistConfirmToken(" Person@Example.COM ", secret, now);
  assert.equal(verifyWaitlistConfirmToken(token, secret, now + 60), "person@example.com");
  assert.equal(verifyWaitlistConfirmToken(token, secret, now + CONFIRM_TOKEN_TTL_SECONDS + 1), null);
  assert.equal(verifyWaitlistConfirmToken(token, "t".repeat(48), now), null);

  const [, issued, sig] = token.split(".");
  const other = Buffer.from("victim@example.com").toString("base64url");
  assert.equal(verifyWaitlistConfirmToken(`${other}.${issued}.${sig}`, secret, now), null);
  assert.equal(verifyWaitlistConfirmToken(`${token.split(".")[0]}.${now + 1}.${sig}`, secret, now + 5), null);
  for (const bad of ["", "a.b", "a.b.c.d", null, undefined, "x".repeat(701)]) {
    assert.equal(verifyWaitlistConfirmToken(bad as string | null | undefined, secret, now), null);
  }
});

test("campaign attribution is withheld without analytics consent and prefers the URL", () => {
  assert.equal(collectWaitlistAttribution("?utm_source=reddit", "/", false, { utm_source: "hn" }), undefined);
  assert.deepEqual(
    collectWaitlistAttribution("?utm_source=Reddit", "/trial", true, { utm_source: "hn", path: "/" }),
    { path: "/trial", utm_source: "reddit" },
  );
  assert.deepEqual(
    collectWaitlistAttribution("", "/trial", true, { utm_source: "hn", path: "/" }),
    { path: "/", utm_source: "hn" },
  );
  const parsed = parseCampaignParams("?utm_source=<script>&utm_medium=email&ref=ABC23XYZ", "/g");
  assert.deepEqual(parsed.campaign, { utm_medium: "email", path: "/g" });
  assert.equal(parsed.referralCode, "abc23xyz");
});

test("confirmation email shows the confirm button and reward terms, with no queue", () => {
  const base = { email: "a@example.com", name: "Ada", variant: "new" as const, siteUrl: "https://cmdtab.net" };
  const full = renderApplicantWaitlistEmail({
    ...base,
    confirmUrl: "https://cmdtab.net/api/waitlist/confirm?token=t",
    referralUrl: "https://cmdtab.net/?ref=abc23xyz&utm_source=referral",
    referralTarget: 5,
  });
  assert.match(full.text, /Confirm my email/);
  assert.match(full.text, /Invite 5 friends/);
  assert.match(full.html, /ref=abc23xyz&amp;utm_source=referral/);
  assert.doesNotMatch(full.text + full.html, /\bqueue\b|\bspots\b|you are #\d/i);

  const bare = renderApplicantWaitlistEmail(base);
  assert.doesNotMatch(bare.text, /Confirm my email|Invite 5/);
});

test("confirmation order is chronological, not alphabetical (timestamps may be formatted any way)", () => {
  // Alphabetically "Mon" < "Wed", but Wednesday is earlier here.
  const result = evaluateReferrals(inviter, [
    friend(1, { id: "late", confirmedAt: "2026-10-12T10:00:00.000Z", networkHash: "net-shared", deviceHash: "dev-a" }),
    friend(2, { id: "early", confirmedAt: "2026-10-07T10:00:00.000Z", networkHash: "net-shared", deviceHash: "dev-b" }),
  ]);
  const byId = Object.fromEntries(result.verdicts.map((verdict) => [verdict.id, verdict]));
  assert.equal(byId.early.status, "qualified");
  assert.equal(byId.late.flag, "same_network_as_other_invitee");
});
