import { createHmac } from "node:crypto";

import { optionalStrongInternalSecret } from "./env";
import { canonicalEmail, DEVICE_ID_PATTERN, networkKey } from "./waitlist-referral";

type SignalKind = "device" | "network" | "email";

// Raw IPs and device identifiers are never stored. Keyed with a server secret,
// a leaked table cannot be reversed by hashing guessed addresses. Without the
// secret there is no safe way to store a signal, so none is stored and
// referrals fail closed (they are flagged for review instead of counted).
function hashSignal(kind: SignalKind, value: string) {
  const secret = optionalStrongInternalSecret(process.env.REQUEST_FINGERPRINT_SECRET);
  if (!secret) return undefined;
  return createHmac("sha256", secret)
    .update(`cmdtab:waitlist-signal:v1:${kind}\0${value}`)
    .digest("hex");
}

export function hashDeviceId(deviceId: string | null | undefined) {
  if (!deviceId || !DEVICE_ID_PATTERN.test(deviceId)) return undefined;
  return hashSignal("device", deviceId);
}

export function hashNetwork(ip: string | null | undefined) {
  const key = networkKey(ip);
  return key ? hashSignal("network", key) : undefined;
}

/**
 * Keyed hash of a canonical address, so an unsubscribe survives re-submission
 * (and alias spellings) without keeping the address itself.
 */
export function hashEmailForSuppression(email: string) {
  return hashSignal("email", canonicalEmail(email));
}
