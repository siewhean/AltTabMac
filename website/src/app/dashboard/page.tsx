import type { Metadata } from "next";

import { DashboardShell } from "@/components/dashboard/dashboard-shell";
import { dashboardContent } from "@/content/dashboard";
import { getDashboardAuthSummary } from "@/lib/admin-store";
import {
  isComparableOptionalAnalyticsWindow,
  OPTIONAL_ANALYTICS_PRODUCTION_STARTED_AT,
} from "@/lib/analytics-measurement";
import { requireAdminSession } from "@/lib/admin-auth";
import { formatSingaporeDateTime } from "@/lib/date";
import {
  getLicenseRequestAggregateStats,
  isLicenseRequestStoreConfigured,
  listLicenseRequests,
} from "@/lib/license-request-store";
import {
  getLicenseFulfillmentAggregateStats,
  isLicenseFulfillmentStoreConfigured,
  listLicenseFulfillments,
} from "@/lib/license-fulfillment-store";
import { getAppUsageOverview, isAppUsageStoreConfigured } from "@/lib/app-usage-store";
import {
  getAnalyticsEventCount,
  getSiteAnalyticsOverview,
  isSiteAnalyticsConfigured,
  listSiteAnalyticsSeries,
  listTopAnalyticsEvents,
  listTopAnalyticsPages,
  type SiteAnalyticsOverview,
} from "@/lib/site-analytics-store";
import { getTrialClaimAggregateStats, isTrialClaimStoreConfigured } from "@/lib/trial-claim-store";
import { isWaitlistStoreConfigured, listWaitlistSubmissions } from "@/lib/waitlist-store";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Dashboard | CmdTab",
  description: "Protected waitlist and launch dashboard for CmdTab.",
  alternates: {
    canonical: "/dashboard",
  },
};

function getTopSources(
  submissions: Awaited<ReturnType<typeof listWaitlistSubmissions>>,
  limit = 4,
) {
  const counts = new Map<string, number>();

  for (const submission of submissions) {
    const label = submission.source?.trim() || "homepage_waitlist";
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }

  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit);
}

export default async function DashboardPage() {
  await requireAdminSession();

  const storeConfigured = isWaitlistStoreConfigured();
  const submissions = storeConfigured ? await listWaitlistSubmissions(100) : [];
  const authSummary = await getDashboardAuthSummary();
  const analyticsConfigured = isSiteAnalyticsConfigured();
  const licenseStoreConfigured = isLicenseRequestStoreConfigured();
  const licenseFulfillmentStoreConfigured = isLicenseFulfillmentStoreConfigured();
  const trialClaimStoreConfigured = isTrialClaimStoreConfigured();
  const appUsageStoreConfigured = isAppUsageStoreConfigured();
  const [licenseStats, licenseRequests] = licenseStoreConfigured
    ? await Promise.all([getLicenseRequestAggregateStats(), listLicenseRequests(20)])
    : [{ total: 0, delivered: 0, failed: 0, pending: 0, requests30d: 0, latestRequest: undefined }, []];
  const [licenseFulfillmentStats, licenseFulfillments] = licenseFulfillmentStoreConfigured
    ? await Promise.all([
        getLicenseFulfillmentAggregateStats(),
        listLicenseFulfillments(20),
      ])
    : [{
        total: 0,
        delivered: 0,
        failed: 0,
        pending: 0,
        refunded: 0,
        purchases30d: 0,
        latestFulfillment: undefined,
      }, []];
  const [trialClaimStats, appUsageOverview, trialDownloadClicks30d] = await Promise.all([
    trialClaimStoreConfigured
      ? getTrialClaimAggregateStats()
      : Promise.resolve({ total: 0, active: 0, expired: 0, claims30d: 0, latestClaim: undefined }),
    appUsageStoreConfigured
      ? getAppUsageOverview()
      : Promise.resolve({
          appActivations7d: 0,
          heartbeats7d: 0,
          activeInstalls7d: 0,
          licenseActivations30d: 0,
          latestActivity: undefined,
        }),
    analyticsConfigured ? getAnalyticsEventCount("trial_page_download_click", 30) : Promise.resolve(0),
  ]);
  const emptyAnalytics: SiteAnalyticsOverview = {
    pageviews24h: 0,
    pageviews7d: 0,
    visitors24h: 0,
    visitors7d: 0,
    totalEvents7d: 0,
    latestEvent: undefined,
  };
  let analyticsOverview: SiteAnalyticsOverview = emptyAnalytics;
  let analyticsSeries: Awaited<ReturnType<typeof listSiteAnalyticsSeries>> = [];
  let topPages: Awaited<ReturnType<typeof listTopAnalyticsPages>> = [];
  let topEvents: Awaited<ReturnType<typeof listTopAnalyticsEvents>> = [];
  let analyticsError = false;

  if (analyticsConfigured) {
    try {
      [analyticsOverview, analyticsSeries, topPages, topEvents] = await Promise.all([
        getSiteAnalyticsOverview(),
        listSiteAnalyticsSeries(14),
        listTopAnalyticsPages(6),
        listTopAnalyticsEvents(8),
      ]);
    } catch {
      analyticsError = true;
    }
  }

  const delivered = submissions.filter(
    (entry) => entry.notificationStatus === "delivered",
  ).length;
  const failed = submissions.filter(
    (entry) => entry.notificationStatus === "failed",
  ).length;
  const pending = submissions.length - delivered - failed;
  const namedCount = submissions.filter((entry) => Boolean(entry.name?.trim())).length;
  const latestSignup = submissions[0]?.updatedAt;
  const topSources = getTopSources(submissions);
  const peakPageviews = Math.max(...analyticsSeries.map((point) => point.pageviews), 1);
  const analyticsSevenDayWindowComparable = isComparableOptionalAnalyticsWindow(7);

  return (
    <DashboardShell
      active="/dashboard"
      title="Overview"
      description="A cleaner operational view of signups, trials, purchases, and website activity."
    >
      <div className="space-y-6">
        <section className="surface-panel p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
            Snapshot
          </p>
          <div className="mt-4 grid gap-4 xl:grid-cols-3">
            <div className="surface-muted p-5">
              <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">Waitlist</p>
              <p className="mt-3 text-3xl font-medium tracking-[-0.05em] text-text">{submissions.length}</p>
              <div className="mt-4 space-y-2 text-sm leading-6 text-muted">
                <p>Delivered: <span className="text-text">{delivered}</span></p>
                <p>Failed: <span className="text-text">{failed}</span></p>
                <p>Pending: <span className="text-text">{pending}</span></p>
                <p>Named signups: <span className="text-text">{namedCount}</span></p>
                <p>Latest signup: <span className="text-text">{latestSignup ? formatSingaporeDateTime(latestSignup) : "No submissions yet"}</span></p>
              </div>
            </div>

            <div className="surface-muted p-5">
              <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">Trials and app usage</p>
              <p className="mt-3 text-3xl font-medium tracking-[-0.05em] text-text">{trialClaimStats.total}</p>
              <div className="mt-4 space-y-2 text-sm leading-6 text-muted">
                <p>Claimed trials 30d: <span className="text-text">{trialClaimStats.claims30d}</span></p>
                <p>Active trials: <span className="text-text">{trialClaimStats.active}</span></p>
                <p>Trial downloads 30d: <span className="text-text">{trialDownloadClicks30d}</span></p>
                <p>Active installs 7d: <span className="text-text">{appUsageOverview.activeInstalls7d}</span></p>
                <p>Latest app activity: <span className="text-text">{appUsageOverview.latestActivity ? formatSingaporeDateTime(appUsageOverview.latestActivity) : "No app events yet"}</span></p>
              </div>
            </div>

            <div className="surface-muted p-5">
              <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">Commerce</p>
              <p className="mt-3 text-3xl font-medium tracking-[-0.05em] text-text">{licenseFulfillmentStats.delivered}</p>
              <div className="mt-4 space-y-2 text-sm leading-6 text-muted">
                <p>Licenses delivered: <span className="text-text">{licenseFulfillmentStats.delivered}</span></p>
                <p>Purchases 30d: <span className="text-text">{licenseFulfillmentStats.purchases30d}</span></p>
                <p>License activations 30d: <span className="text-text">{appUsageOverview.licenseActivations30d}</span></p>
                <p>Support requests 30d: <span className="text-text">{licenseStats.requests30d}</span></p>
                <p>Latest fulfillment: <span className="text-text">{licenseFulfillmentStats.latestFulfillment ? formatSingaporeDateTime(licenseFulfillmentStats.latestFulfillment) : "No purchases yet"}</span></p>
              </div>
            </div>
          </div>
        </section>

        <section className="surface-panel p-6">
          <div className="flex flex-col gap-2 border-b border-white/8 pb-5 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Website analytics
              </p>
              <h2 className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                First-party mirror of consented pageviews and tracked events
              </h2>
            </div>
            <p className="text-sm leading-6 text-muted">
              Latest tracked event:{" "}
              <span className="text-text">
                {analyticsOverview.latestEvent
                  ? formatSingaporeDateTime(analyticsOverview.latestEvent)
                  : "No analytics captured yet"}
              </span>
            </p>
          </div>

          <p className="mt-4 text-sm leading-6 text-muted">
            Only visitors who accept optional analytics appear here. Production consented
            measurement began {formatSingaporeDateTime(OPTIONAL_ANALYTICS_PRODUCTION_STARTED_AT)}.
            {analyticsSevenDayWindowComparable
              ? " The current seven-day window is fully post-consent."
              : " Seven-day pageview and visitor comparisons are unavailable until the full window is post-consent."}
          </p>

          <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            {[
              { label: "Consented pageviews 24h", value: String(analyticsOverview.pageviews24h) },
              { label: "Consented visitors 24h", value: String(analyticsOverview.visitors24h) },
              {
                label: "Consented pageviews 7d",
                value: analyticsSevenDayWindowComparable ? String(analyticsOverview.pageviews7d) : "Not comparable",
              },
              { label: "Consented tracked events 7d", value: String(analyticsOverview.totalEvents7d) },
            ].map((item) => (
              <div key={item.label} className="surface-muted p-4">
                <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">{item.label}</p>
                <p className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                  {item.value}
                </p>
              </div>
            ))}
          </div>

          <div className="mt-6 grid gap-6 xl:grid-cols-[minmax(0,1.1fr)_minmax(300px,0.9fr)]">
            <div className="space-y-3">
              <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">
                Daily consented pageviews
              </p>
              {analyticsSeries.length > 0 ? (
                analyticsSeries.map((point) => (
                  <div key={point.day} className="grid grid-cols-[72px_minmax(0,1fr)_50px] items-center gap-3">
                    <p className="text-xs text-subdued">{point.day.slice(5)}</p>
                    <div className="h-2 rounded-full bg-white/[0.06]">
                      <div
                        className="h-2 rounded-full bg-accent transition-[width] duration-500 ease-[cubic-bezier(0.22,1,0.36,1)]"
                        style={{
                          width: `${Math.max((point.pageviews / peakPageviews) * 100, point.pageviews > 0 ? 10 : 0)}%`,
                        }}
                      />
                    </div>
                    <p className="text-right text-sm text-text">{point.pageviews}</p>
                  </div>
                ))
              ) : (
                <div className="surface-muted p-5 text-sm text-muted">
                  Analytics data will appear here after visitors load the website.
                </div>
              )}
            </div>

            <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-1">
              <div>
                <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">Top pages</p>
                <div className="mt-3 space-y-2">
                  {topPages.length > 0 ? (
                    topPages.map((item) => (
                      <div key={item.label} className="flex items-center justify-between gap-3 text-sm">
                        <span className="truncate text-muted">{item.label}</span>
                        <span className="text-text">{item.count}</span>
                      </div>
                    ))
                  ) : (
                    <p className="text-sm leading-6 text-muted">No tracked pages yet.</p>
                  )}
                </div>
              </div>

              <div>
                <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">Top custom events</p>
                <div className="mt-3 space-y-2">
                  {topEvents.length > 0 ? (
                    topEvents.map((item) => (
                      <div key={item.label} className="flex items-center justify-between gap-3 text-sm">
                        <span className="truncate text-muted">{item.label}</span>
                        <span className="text-text">{item.count}</span>
                      </div>
                    ))
                  ) : (
                    <p className="text-sm leading-6 text-muted">No tracked events yet.</p>
                  )}
                </div>
              </div>

              <div className="surface-muted p-4">
                <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">Consented visitors 7d</p>
                <p className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                  {analyticsSevenDayWindowComparable ? analyticsOverview.visitors7d : "Not comparable"}
                </p>
                <p className="mt-3 text-sm leading-6 text-muted">
                  Consent-respecting website activity and click events are mirrored here for routine checks.
                </p>
              </div>
            </div>
          </div>

          {analyticsError ? (
            <div className="mt-6 rounded-[22px] border border-amber-300/18 bg-amber-300/[0.06] px-4 py-3 text-sm leading-6 text-amber-100">
              Website analytics are temporarily unavailable, but waitlist and admin data are still
              live.
            </div>
          ) : null}
        </section>

        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.15fr)_minmax(320px,0.85fr)]">
          <section className="surface-panel p-6">
            <div className="flex items-end justify-between gap-4 border-b border-white/8 pb-5">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                  Recent signups
                </p>
                <h2 className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                  Latest 100 entries
                </h2>
              </div>
              <p className="text-sm leading-6 text-muted">This stays separate from the website traffic mirror above.</p>
            </div>

            <div className="mt-6 overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-[11px] uppercase tracking-[0.22em] text-subdued">
                  <tr>
                    <th className="px-3 py-3">Email</th>
                    <th className="px-3 py-3">Name</th>
                    <th className="px-3 py-3">Source</th>
                    <th className="px-3 py-3">Status</th>
                    <th className="px-3 py-3">Updated</th>
                  </tr>
                </thead>
                <tbody>
                  {submissions.length > 0 ? (
                    submissions.map((entry) => (
                      <tr key={entry.id} className="border-t border-white/8">
                        <td className="px-3 py-3 text-text">{entry.email}</td>
                        <td className="px-3 py-3 text-muted">{entry.name ?? "—"}</td>
                        <td className="px-3 py-3 text-muted">{entry.source ?? "homepage_waitlist"}</td>
                        <td className="px-3 py-3">
                          <span
                            className={`rounded-full px-2.5 py-1 text-[11px] font-medium uppercase tracking-[0.18em] ${
                              entry.notificationStatus === "delivered"
                                ? "bg-emerald-400/10 text-emerald-200"
                                : entry.notificationStatus === "failed"
                                  ? "bg-rose-400/10 text-rose-200"
                                  : "bg-white/6 text-subdued"
                            }`}
                          >
                            {entry.notificationStatus}
                          </span>
                          {entry.notificationError ? (
                            <p className="mt-1 max-w-[320px] text-xs leading-5 text-rose-200">
                              {entry.notificationError}
                            </p>
                          ) : null}
                        </td>
                        <td className="px-3 py-3 text-muted">
                          {formatSingaporeDateTime(entry.updatedAt)}
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={5} className="px-3 py-8 text-center text-sm text-muted">
                        No stored submissions yet.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>

          <div className="space-y-6">
            <section className="surface-panel p-6">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                License delivery
              </p>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                {[
                  { label: "Orders", value: String(licenseFulfillmentStats.total) },
                  { label: "Last 30 days", value: String(licenseFulfillmentStats.purchases30d) },
                  { label: "Delivered", value: String(licenseFulfillmentStats.delivered) },
                  { label: "Failed", value: String(licenseFulfillmentStats.failed) },
                ].map((item) => (
                  <div key={item.label} className="surface-muted p-4">
                    <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">{item.label}</p>
                    <p className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                      {item.value}
                    </p>
                  </div>
                ))}
              </div>
              <div className="mt-5 space-y-2 text-sm leading-7 text-muted">
                <p>
                  Latest fulfillment:{" "}
                  <span className="text-text">
                    {licenseFulfillmentStats.latestFulfillment
                      ? formatSingaporeDateTime(licenseFulfillmentStats.latestFulfillment)
                      : "No purchases yet"}
                  </span>
                </p>
                <p>
                  Fulfillment status:{" "}
                  <span className="text-text">
                    {licenseFulfillmentStoreConfigured ? "Configured" : "Missing"}
                  </span>
                </p>
              </div>
              <div className="mt-5 space-y-3 border-t border-white/8 pt-4">
                {licenseFulfillments.length > 0 ? (
                  licenseFulfillments.slice(0, 5).map((delivery) => (
                    <div key={delivery.id} className="surface-muted p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <p className="text-sm font-medium text-text">{delivery.purchaserEmail}</p>
                          <p className="mt-1 text-sm leading-6 text-muted">
                            {delivery.productName ?? "CmdTab"} · {delivery.deliveryStatus}
                            {delivery.testMode ? " · test" : ""}
                          </p>
                        </div>
                        <span className="text-xs text-subdued">
                          {formatSingaporeDateTime(delivery.updatedAt)}
                        </span>
                      </div>
                      {delivery.deliveryError ? (
                        <p className="mt-2 text-xs leading-5 text-rose-200">{delivery.deliveryError}</p>
                      ) : null}
                    </div>
                  ))
                ) : (
                  <p className="text-sm leading-6 text-muted">
                    Purchases and automated license emails will appear here after the webhook starts receiving orders.
                  </p>
                )}
              </div>
            </section>

            <section className="surface-panel p-6">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                License support
              </p>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                {[
                  { label: "Requests", value: String(licenseStats.total) },
                  { label: "Last 30 days", value: String(licenseStats.requests30d) },
                  { label: "Delivered", value: String(licenseStats.delivered) },
                  { label: "Pending", value: String(licenseStats.pending) },
                ].map((item) => (
                  <div key={item.label} className="surface-muted p-4">
                    <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">{item.label}</p>
                    <p className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                      {item.value}
                    </p>
                  </div>
                ))}
              </div>
              <div className="mt-5 space-y-2 text-sm leading-7 text-muted">
                <p>
                  Latest request:{" "}
                  <span className="text-text">
                    {licenseStats.latestRequest
                      ? formatSingaporeDateTime(licenseStats.latestRequest)
                      : "No requests yet"}
                  </span>
                </p>
                <p>
                  Store status:{" "}
                  <span className="text-text">
                    {licenseStoreConfigured ? "Configured" : "Missing"}
                  </span>
                </p>
              </div>
              <div className="mt-5 space-y-3 border-t border-white/8 pt-4">
                {licenseRequests.length > 0 ? (
                  licenseRequests.slice(0, 5).map((request) => (
                    <div key={request.id} className="surface-muted p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <p className="text-sm font-medium text-text">{request.email}</p>
                          <p className="mt-1 text-sm leading-6 text-muted">{request.reason}</p>
                        </div>
                        <span className="text-xs text-subdued">
                          {formatSingaporeDateTime(request.updatedAt)}
                        </span>
                      </div>
                    </div>
                  ))
                ) : (
                  <p className="text-sm leading-6 text-muted">
                    License and purchase support requests will appear here.
                  </p>
                )}
              </div>
            </section>

            <section className="surface-panel p-6">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Access and setup
              </p>
              <div className="mt-5 space-y-4 text-sm leading-7 text-muted">
                <p>
                  Password source:{" "}
                  <span className="text-text">
                    {authSummary.source === "database"
                      ? "Database settings"
                      : authSummary.source === "environment"
                        ? "Environment variable"
                        : "Missing"}
                  </span>
                </p>
                <p>
                  Password last changed:{" "}
                  <span className="text-text">
                    {authSummary.updatedAt
                      ? formatSingaporeDateTime(authSummary.updatedAt)
                      : "Not changed in dashboard yet"}
                  </span>
                </p>
                <p>
                  Top sources:{" "}
                  <span className="text-text">
                    {topSources.length > 0
                      ? topSources.map(([label, count]) => `${label} (${count})`).join(", ")
                      : "No signups yet"}
                  </span>
                </p>
              </div>
            </section>

            <section className="surface-panel p-6">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Reference links
              </p>
              <div className="mt-5 space-y-4 text-sm leading-7 text-muted">
                <p>{dashboardContent.summary}</p>
                <div className="space-y-3 border-t border-white/8 pt-4">
                  {dashboardContent.sources.map((source) => (
                    <a
                      key={source.title}
                      href={source.href}
                      target="_blank"
                      rel="noreferrer"
                      className="surface-muted block p-4 transition duration-200 hover:-translate-y-0.5 hover:border-white/14"
                    >
                      <p className="text-sm font-medium text-text">{source.title}</p>
                      <p className="mt-1 text-sm leading-6 text-muted">{source.body}</p>
                    </a>
                  ))}
                </div>
                <p className="text-sm leading-6 text-subdued">{dashboardContent.privacyNote}</p>
              </div>
            </section>

            {!storeConfigured ? (
              <section className="rounded-[28px] border border-amber-300/20 bg-amber-300/[0.08] p-6 shadow-panel">
                <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-amber-200">
                  Database not configured
                </p>
                <p className="mt-4 text-base leading-7 text-text">
                  Add <code>DATABASE_URL</code> or <code>POSTGRES_URL</code> in Vercel and redeploy.
                </p>
              </section>
            ) : null}
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
