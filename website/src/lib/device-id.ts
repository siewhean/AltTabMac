"use client";

const DEVICE_STORAGE_KEY = "cmdtab-device-id";

/**
 * A random id that lets the server notice repeat waitlist signups from one
 * browser (the server stores only a salted hash). It is created when someone
 * submits the waitlist form, never on page load, and is not used for analytics.
 */
export function getOrCreateDeviceId(): string | undefined {
  if (typeof window === "undefined") return undefined;
  try {
    const existing = window.localStorage.getItem(DEVICE_STORAGE_KEY);
    if (existing && /^[A-Za-z0-9_-]{16,64}$/.test(existing)) return existing;

    const bytes = new Uint8Array(18);
    window.crypto.getRandomValues(bytes);
    const id = btoa(String.fromCharCode(...bytes))
      .replaceAll("+", "-")
      .replaceAll("/", "_")
      .replaceAll("=", "");
    window.localStorage.setItem(DEVICE_STORAGE_KEY, id);
    return id;
  } catch {
    return undefined;
  }
}
