import type { Metadata } from "next";

import { DashboardShell } from "@/components/dashboard/dashboard-shell";
import { dashboardContent } from "@/content/dashboard";
import { getDashboardAuthSummary } from "@/lib/admin-store";
import { requireAdminSession } from "@/lib/admin-auth";
import { formatSingaporeDateTime } from "@/lib/date";
import {
  getLicenseRequestAggregateStats,
  isLicenseRequestStoreConfigured,
  listLicenseRequests,
} from "@/lib/license-request-store";
import {
  getSiteAnalyticsOverview,
  isSiteAnalyticsConfigured,
  listSiteAnalyticsSeries,
  listTopAnalyticsEvents,
  listTopAnalyticsPages,
  type SiteAnalyticsOverview,
} from "@/lib/site-analytics-store";
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
  const [licenseStats, licenseRequests] = licenseStoreConfigured
    ? await Promise.all([getLicenseRequestAggregateStats(), listLicenseRequests(20)])
    : [{ total: 0, delivered: 0, failed: 0, pending: 0, requests30d: 0, latestRequest: undefined }, []];
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

  return (
    <DashboardShell
      active="/dashboard"
      title="Waitlist and website analytics"
      description="A stable operational view of live signups, delivery health, and first-party website analytics mirrored into your own dashboard."
    >
      <div className="space-y-6">
        <section className="surface-panel p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
            Status
          </p>
          <div className="mt-4 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
            {[
              { label: "Database", value: storeConfigured ? "Configured" : "Missing" },
              { label: "Submissions", value: String(submissions.length) },
              { label: "Delivered", value: String(delivered) },
              { label: "Failed", value: String(failed) },
              { label: "Pending", value: String(pending) },
            ].map((item) => (
              <div key={item.label} className="surface-muted p-4">
                <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">{item.label}</p>
                <p className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                  {item.value}
                </p>
              </div>
            ))}
          </div>
          <div className="mt-5 text-sm leading-7 text-muted">
            <p>
              Latest signup:{" "}
              <span className="text-text">
                {latestSignup ? formatSingaporeDateTime(latestSignup) : "No submissions yet"}
              </span>
            </p>
            <p>
              Named signups: <span className="text-text">{namedCount}</span>
            </p>
          </div>
        </section>

        <section className="surface-panel p-6">
          <div className="flex flex-col gap-2 border-b border-white/8 pb-5 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Website analytics
              </p>
              <h2 className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                First-party mirror of pageviews and tracked events
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

          <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
            {[
              { label: "Pageviews 24h", value: String(analyticsOverview.pageviews24h) },
              { label: "Visitors 24h", value: String(analyticsOverview.visitors24h) },
              { label: "Pageviews 7d", value: String(analyticsOverview.pageviews7d) },
              { label: "Visitors 7d", value: String(analyticsOverview.visitors7d) },
              { label: "Tracked events 7d", value: String(analyticsOverview.totalEvents7d) },
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
                Daily pageviews
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
            </div>
          </div>

          {analyticsError ? (
            <div className="mt-6 rounded-[22px] border border-amber-300/18 bg-amber-300/[0.06] px-4 py-3 text-sm leading-6 text-amber-100">
              Website analytics are temporarily unavailable, but waitlist and admin data are still
              live.
            </div>
          ) : null}
        </section>

        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_minmax(300px,0.8fr)]">
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
                Access and storage
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
                Website signals
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
