"use client";

import { track } from "@vercel/analytics";

const VISITOR_STORAGE_KEY = "cmdtab-website-visitor-id";
const SESSION_STORAGE_KEY = "cmdtab-website-session-id";

type AnalyticsPropertyValue = string | number | boolean | null;

type DiscoverySource =
  | "chatgpt"
  | "perplexity"
  | "microsoft_copilot"
  | "google_gemini"
  | "claude"
  | "google_search"
  | "bing_search"
  | "direct"
  | "referral";

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

function boundedCampaignValue(value: string | null) {
  const normalized = value?.trim().slice(0, 120);
  return normalized || undefined;
}

function sourceFromLabel(label: string): DiscoverySource | undefined {
  if (label.includes("chatgpt") || label.includes("openai")) return "chatgpt";
  if (label.includes("perplexity")) return "perplexity";
  if (label.includes("copilot") || label.includes("bingchat")) return "microsoft_copilot";
  if (label.includes("gemini") || label.includes("bard")) return "google_gemini";
  if (label.includes("claude") || label.includes("anthropic")) return "claude";
  if (label.includes("google")) return "google_search";
  if (label.includes("bing")) return "bing_search";
  return undefined;
}

function getDiscoveryContext(path: string) {
  const params = new URLSearchParams(window.location.search);
  const utmSource = boundedCampaignValue(params.get("utm_source"));
  const utmMedium = boundedCampaignValue(params.get("utm_medium"));
  const utmCampaign = boundedCampaignValue(params.get("utm_campaign"));
  const sourceFromUTM = sourceFromLabel(utmSource?.toLowerCase() ?? "");

  let referrerHost: string | undefined;
  try {
    referrerHost = document.referrer ? new URL(document.referrer).hostname.toLowerCase() : undefined;
  } catch {
    referrerHost = undefined;
  }

  const discoverySource =
    sourceFromUTM ??
    sourceFromLabel(referrerHost ?? "") ??
    (referrerHost ? "referral" : "direct");

  return {
    discoverySource,
    landingPath: path,
    ...(utmSource ? { utmSource } : {}),
    ...(utmMedium ? { utmMedium } : {}),
    ...(utmCampaign ? { utmCampaign } : {}),
  };
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
    eventData: getDiscoveryContext(path),
    visitorId: getVisitorId(),
    sessionId: getSessionId(),
    occurredAt: new Date().toISOString(),
  });
}
