import { createHash, timingSafeEqual } from "node:crypto";

/**
 * Compares arbitrary-length secrets without returning before a constant-length
 * cryptographic comparison has occurred. The SHA-256 digests are always the
 * same length, so callers do not leak the original secret length through the
 * timingSafeEqual precondition.
 */
export function constantTimeEqual(left: string, right: string) {
  const leftDigest = createHash("sha256").update(left, "utf8").digest();
  const rightDigest = createHash("sha256").update(right, "utf8").digest();
  return timingSafeEqual(leftDigest, rightDigest);
}
