import { randomBytes } from "node:crypto";

// Server only (uses node:crypto). Lowercase, no look-alike characters
// (0/o, 1/l/i), so codes survive being read aloud.
const ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz";
const CODE_LENGTH = 8;

export function generateReferralCode() {
  const bytes = randomBytes(CODE_LENGTH);
  let code = "";
  for (let index = 0; index < CODE_LENGTH; index += 1) {
    code += ALPHABET[bytes[index] % ALPHABET.length];
  }
  return code;
}
