/** Qualified referrals needed to earn a free CmdTab license. */
export const REFERRAL_REWARD_TARGET = 5;
/**
 * Beta limit on free licenses (earned plus granted). Qualifying members beyond
 * it wait for a slot. Public copy says "the first 100"; if the server override
 * CMDTAB_REFERRAL_REWARD_CAP is changed, update that copy too.
 */
export const REFERRAL_REWARD_CAP = 100;

// This module is bundled into the browser: it must not import Node-only modules.
// Server-only helpers live in waitlist-referral-code.ts.
export const REFERRAL_CODE_PATTERN = /^[a-z0-9]{6,12}$/;
export const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

/** Returns a normalized code, or undefined when the input cannot be a code. */
export function normalizeReferralCode(value: unknown) {
  if (typeof value !== "string") return undefined;
  const code = value.trim().toLowerCase();
  return REFERRAL_CODE_PATTERN.test(code) ? code : undefined;
}

export function referralUrl(siteUrl: string, code: string) {
  const base = siteUrl.replace(/\/+$/, "");
  return `${base}/?ref=${encodeURIComponent(code)}&utm_source=referral&utm_medium=invite&utm_campaign=beta_referral`;
}

export const referralShareText =
  "I just joined the CmdTab private beta, a Mac switcher that switches individual windows, not just apps.";

// ---------------------------------------------------------------------------
// Identity signals
// ---------------------------------------------------------------------------

const GMAIL_DOMAINS = new Set(["gmail.com", "googlemail.com"]);
// Providers that deliver "name+anything@domain" to "name@domain".
const PLUS_ADDRESSING_DOMAINS = new Set([
  "outlook.com",
  "hotmail.com",
  "live.com",
  "msn.com",
  "icloud.com",
  "me.com",
  "mac.com",
  "proton.me",
  "protonmail.com",
  "pm.me",
  "fastmail.com",
  "fastmail.fm",
]);

/**
 * Collapses addresses that provably reach one mailbox (Gmail dots and +tags,
 * +tags at providers that support them) so aliases of one inbox cannot pass as
 * separate people. Other domains are only lowercased: dots and plus signs can
 * be significant there.
 */
export function canonicalEmail(email: string) {
  const normalized = email.trim().toLowerCase();
  const at = normalized.lastIndexOf("@");
  if (at < 1) return normalized;
  let local = normalized.slice(0, at);
  let domain = normalized.slice(at + 1);

  if (GMAIL_DOMAINS.has(domain)) {
    domain = "gmail.com";
    local = local.split("+")[0].replaceAll(".", "");
  } else if (PLUS_ADDRESSING_DOMAINS.has(domain)) {
    local = local.split("+")[0];
  }
  return `${local}@${domain}`;
}

// A starter list of throwaway-mailbox providers. It reduces cheap abuse; it is
// not exhaustive, which is why rewards are also reviewed by a person.
const DISPOSABLE_DOMAINS = new Set([
  "mailinator.com", "guerrillamail.com", "guerrillamail.net", "guerrillamail.org",
  "guerrillamailblock.com", "sharklasers.com", "grr.la", "10minutemail.com",
  "10minutemail.net", "20minutemail.com", "tempmail.com", "temp-mail.org",
  "temp-mail.io", "tempmailo.com", "tempail.com", "yopmail.com", "yopmail.net",
  "yopmail.fr", "trashmail.com", "trashmail.net", "getnada.com", "nada.email",
  "dispostable.com", "maildrop.cc", "throwawaymail.com", "fakeinbox.com",
  "mintemail.com", "mailnesia.com", "moakt.com", "emailondeck.com", "mohmal.com",
  "burnermail.io", "spamgourmet.com", "discard.email", "mailcatch.com",
  "inboxkitten.com", "tmpmail.org", "tmpmail.net", "tmail.ws", "mytemp.email",
  "fakemail.net", "mailforspam.com", "spambox.us", "spam4.me", "getairmail.com",
  "mail.tm", "dropmail.me", "emailfake.com", "crazymailing.com", "linshiyouxiang.net",
]);

export function isDisposableEmail(email: string) {
  const domain = email.trim().toLowerCase().split("@").pop() ?? "";
  if (DISPOSABLE_DOMAINS.has(domain)) return true;
  // Catch subdomains of known providers (e.g. x.mailinator.com).
  return [...DISPOSABLE_DOMAINS].some((blocked) => domain.endsWith(`.${blocked}`));
}

/**
 * Coarse network identity: the IPv4 /24 or IPv6 /64. Households, offices and
 * mobile carriers share these on purpose, so matches are treated as signals
 * for review, never as proof of a single person. Returns undefined when the IP
 * is unknown or unparseable.
 */
export function networkKey(ip: string | null | undefined) {
  const value = ip?.trim().toLowerCase();
  if (!value || value === "unknown") return undefined;

  const mapped = value.startsWith("::ffff:") ? value.slice(7) : value;
  const v4 = mapped.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.\d{1,3}$/);
  if (v4) {
    const octets = v4.slice(1, 4).map(Number);
    if (octets.some((octet) => octet > 255)) return undefined;
    return `v4:${octets.join(".")}`;
  }

  if (!/^[0-9a-f:]+$/.test(value) || !value.includes(":")) return undefined;
  const [head, tail = ""] = value.split("::");
  const headParts = head ? head.split(":") : [];
  const tailParts = value.includes("::") && tail ? tail.split(":") : [];
  if (!value.includes("::") && headParts.length !== 8) return undefined;
  const missing = value.includes("::") ? 8 - headParts.length - tailParts.length : 0;
  if (missing < 0) return undefined;
  const groups = [...headParts, ...Array(missing).fill("0"), ...tailParts];
  if (groups.length !== 8 || groups.some((group) => !/^[0-9a-f]{1,4}$/.test(group))) {
    return undefined;
  }
  return `v6:${groups.slice(0, 4).map((group) => group.padStart(4, "0")).join(":")}`;
}

// ---------------------------------------------------------------------------
// Referral qualification
// ---------------------------------------------------------------------------

export type ReferralFlag =
  | "same_person_email"
  | "disposable_email"
  | "missing_device_signals"
  | "same_device_as_inviter"
  | "same_network_as_inviter"
  | "device_used_for_multiple_signups"
  | "same_device_as_other_invitee"
  | "same_network_as_other_invitee";

export type ReferralInviter = {
  canonicalEmail: string;
  deviceHash?: string | null;
  networkHash?: string | null;
  confirmed: boolean;
};

export type ReferralInvitee = {
  id: string;
  canonicalEmail: string;
  disposable: boolean;
  /** Signup-time signals. */
  deviceHash?: string | null;
  networkHash?: string | null;
  /** Network seen when the invitee clicked the confirmation link. */
  confirmNetworkHash?: string | null;
  /** Number of waitlist rows created from this invitee's device (including its own). */
  signupsFromDevice: number;
  confirmedAt?: string | null;
  /** Previous verdict, used so retention purges never downgrade a decided referral. */
  priorStatus?: "qualified" | "flagged" | null;
};

export type ReferralVerdict = {
  id: string;
  status: "pending" | "qualified" | "flagged";
  flag?: ReferralFlag;
};

export type ReferralEvaluation = {
  verdicts: ReferralVerdict[];
  qualified: number;
  /** True when the inviter is confirmed and has enough qualified referrals. */
  rewardEarned: boolean;
};

/**
 * Decides which invitations count. Invitees are judged in confirmation order,
 * so when two friends collide the earlier confirmation wins and the later one
 * is flagged for human review. An invitation counts only if the invitee
 * confirmed their email and shares no device or network with the inviter or
 * with another counted invitee. Flagged invitations are never silently
 * dropped: they stay visible to the reviewer with the reason.
 */
export function evaluateReferrals(
  inviter: ReferralInviter,
  invitees: ReadonlyArray<ReferralInvitee>,
): ReferralEvaluation {
  const verdicts = new Map<string, ReferralVerdict>();
  const seenDevices = new Set<string>();
  const seenNetworks = new Set<string>();
  let qualified = 0;

  const confirmed = invitees
    .filter((invitee) => invitee.confirmedAt)
    .sort((a, b) => Date.parse(String(a.confirmedAt)) - Date.parse(String(b.confirmedAt)) || a.id.localeCompare(b.id));

  for (const invitee of invitees) {
    if (!invitee.confirmedAt) verdicts.set(invitee.id, { id: invitee.id, status: "pending" });
  }

  for (const invitee of confirmed) {
    const signalsPurged =
      invitee.priorStatus === "qualified" && !invitee.deviceHash && !invitee.networkHash;
    let flag: ReferralFlag | undefined;

    if (signalsPurged) {
      // Hashes were deleted under the retention policy after a decision.
      verdicts.set(invitee.id, { id: invitee.id, status: "qualified" });
      qualified += 1;
      continue;
    }

    if (invitee.canonicalEmail === inviter.canonicalEmail) flag = "same_person_email";
    else if (invitee.disposable) flag = "disposable_email";
    else if (!invitee.deviceHash || !invitee.networkHash || !inviter.deviceHash || !inviter.networkHash) {
      flag = "missing_device_signals";
    } else if (invitee.deviceHash === inviter.deviceHash) flag = "same_device_as_inviter";
    else if (
      invitee.networkHash === inviter.networkHash ||
      (invitee.confirmNetworkHash && invitee.confirmNetworkHash === inviter.networkHash)
    ) {
      flag = "same_network_as_inviter";
    } else if (invitee.signupsFromDevice > 1) flag = "device_used_for_multiple_signups";
    else if (seenDevices.has(invitee.deviceHash)) flag = "same_device_as_other_invitee";
    else if (seenNetworks.has(invitee.networkHash)) flag = "same_network_as_other_invitee";

    if (flag) {
      verdicts.set(invitee.id, { id: invitee.id, status: "flagged", flag });
      continue;
    }

    seenDevices.add(invitee.deviceHash as string);
    seenNetworks.add(invitee.networkHash as string);
    verdicts.set(invitee.id, { id: invitee.id, status: "qualified" });
    qualified += 1;
  }

  return {
    verdicts: invitees.map((invitee) => verdicts.get(invitee.id) as ReferralVerdict),
    qualified,
    rewardEarned: inviter.confirmed && qualified >= REFERRAL_REWARD_TARGET,
  };
}
