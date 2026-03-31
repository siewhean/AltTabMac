"use client";

import { track } from "@vercel/analytics";

const VISITOR_STORAGE_KEY = "cmdtab-website-visitor-id";
const SESSION_STORAGE_KEY = "cmdtab-website-session-id";

type AnalyticsPropertyValue = string | number | boolean | null;

function makeId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function getStorageId(storage: Storage, key: string) {
  const existing = storage.getItem(key);
  if (existing) return existing;

  const next = makeId();
  storage.setItem(key, next);
  return next;
}

function getVisitorId() {
  if (typeof window === "undefined") return undefined;
  try {
    return getStorageId(window.localStorage, VISITOR_STORAGE_KEY);
  } catch {
    return undefined;
  }
}

function getSessionId() {
  if (typeof window === "undefined") return undefined;
  try {
    return getStorageId(window.sessionStorage, SESSION_STORAGE_KEY);
  } catch {
    return undefined;
  }
}

function postAnalytics(payload: Record<string, unknown>) {
  if (typeof window === "undefined") return;

  const body = JSON.stringify(payload);

  try {
    if (navigator.sendBeacon) {
      const blob = new Blob([body], { type: "application/json" });
      navigator.sendBeacon("/api/analytics", blob);
      return;
    }
  } catch {
    // Fall back to fetch.
  }

  void fetch("/api/analytics", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    keepalive: true,
  });
}

function sanitizeEventData(data?: Record<string, unknown>) {
  if (!data) return undefined;

  const result: Record<string, AnalyticsPropertyValue> = {};
  for (const [key, value] of Object.entries(data)) {
    if (
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean" ||
      value === null
    ) {
      result[key] = value;
      continue;
    }

    if (value instanceof Date) {
      result[key] = value.toISOString();
      continue;
    }

    if (value !== undefined) {
      result[key] = JSON.stringify(value);
    }
  }

  return result;
}

export function trackSiteEvent(
  eventName: string,
  data?: Record<string, unknown>,
) {
  const sanitized = sanitizeEventData(data);
  track(eventName, sanitized);

  postAnalytics({
    eventType: "event",
    eventName,
    eventData: sanitized,
    context: typeof sanitized?.context === "string" ? sanitized.context : undefined,
    path: window.location.pathname,
    referrer: document.referrer || undefined,
    visitorId: getVisitorId(),
    sessionId: getSessionId(),
    occurredAt: new Date().toISOString(),
  });
}

export function trackSitePageView(path: string) {
  postAnalytics({
    eventType: "pageview",
    path,
    referrer: document.referrer || undefined,
    visitorId: getVisitorId(),
    sessionId: getSessionId(),
    occurredAt: new Date().toISOString(),
  });
}
