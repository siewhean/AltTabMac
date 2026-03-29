import type { Metadata } from "next";

import { DashboardShell } from "@/components/dashboard/dashboard-shell";
import { getDashboardAuthSummary } from "@/lib/admin-store";
import { requireAdminSession } from "@/lib/admin-auth";
import { formatSingaporeDateTime } from "@/lib/date";
import { isWaitlistStoreConfigured, listWaitlistSubmissions } from "@/lib/waitlist-store";

export const metadata: Metadata = {
  title: "Dashboard | CmdTab",
  description: "Protected waitlist and launch dashboard for CmdTab.",
  alternates: {
    canonical: "/dashboard",
  },
};

export default async function DashboardPage() {
  await requireAdminSession();

  const storeConfigured = isWaitlistStoreConfigured();
  const submissions = storeConfigured ? await listWaitlistSubmissions(100) : [];
  const deliveredCount = submissions.filter((entry) => entry.notificationStatus === "delivered").length;
  const failedCount = submissions.filter((entry) => entry.notificationStatus === "failed").length;
  const pendingCount = submissions.filter((entry) => entry.notificationStatus === "stored").length;
  const latestSignup = submissions[0]?.updatedAt;
  const authSummary = await getDashboardAuthSummary();
  const sourceBreakdown = Array.from(
    submissions.reduce((map, entry) => {
      const key = entry.source ?? "homepage_waitlist";
      map.set(key, (map.get(key) ?? 0) + 1);
      return map;
    }, new Map<string, number>()),
  ).sort((a, b) => b[1] - a[1]);

  return (
    <DashboardShell
      active="/dashboard"
      title="Waitlist submissions and delivery status"
      description="Track beta demand, check delivery health, and manage owner access from one private dashboard."
    >
      <div className="space-y-6">
        <div className="grid gap-5 lg:grid-cols-4">
          {[
            { label: "Database", value: storeConfigured ? "Configured" : "Missing" },
            { label: "Submissions", value: String(submissions.length) },
            { label: "Delivered", value: String(deliveredCount) },
            { label: "Pending / failed", value: String(pendingCount + failedCount) },
          ].map((item) => (
            <section
              key={item.label}
              className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl"
            >
              <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">{item.label}</p>
              <p className="mt-3 text-3xl font-medium tracking-[-0.05em] text-text">
                {item.value}
              </p>
            </section>
          ))}
        </div>

        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.4fr)_minmax(320px,0.8fr)]">
          <section className="rounded-[28px] border border-white/10 bg-white/[0.03] p-6 shadow-panel backdrop-blur-xl">
            <div className="flex flex-col gap-2 border-b border-white/8 pb-5 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                  Recent signups
                </p>
                <h2 className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                  Latest waitlist entries
                </h2>
              </div>
              <p className="text-sm leading-6 text-muted">
                Latest activity: {latestSignup ? formatSingaporeDateTime(latestSignup) : "No submissions yet"}
              </p>
            </div>

            <div className="mt-5 overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-[11px] uppercase tracking-[0.22em] text-subdued">
                  <tr>
                    <th className="px-3 py-3">Email</th>
                    <th className="px-3 py-3">Name</th>
                    <th className="px-3 py-3">Source</th>
                    <th className="px-3 py-3">Notification</th>
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
            <section className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Delivery health
              </p>
              <div className="mt-5 space-y-4 text-sm leading-7 text-muted">
                <p>
                  Delivered notifications: <span className="text-text">{deliveredCount}</span>
                </p>
                <p>
                  Failed notifications: <span className="text-text">{failedCount}</span>
                </p>
                <p>
                  Stored without delivery: <span className="text-text">{pendingCount}</span>
                </p>
              </div>
            </section>

            <section className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl">
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
                  Stored sources:{" "}
                  <span className="text-text">
                    {sourceBreakdown.length > 0
                      ? sourceBreakdown.map(([source, count]) => `${source} (${count})`).join(", ")
                      : "No signups yet"}
                  </span>
                </p>
              </div>
            </section>

            {!storeConfigured ? (
              <section className="rounded-[28px] border border-amber-300/20 bg-amber-300/[0.08] p-6 shadow-panel">
                <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-amber-200">
                  Database not configured
                </p>
                <p className="mt-4 max-w-3xl text-base leading-7 text-text">
                  Add <code>DATABASE_URL</code> or <code>POSTGRES_URL</code> in Vercel and redeploy.
                  Until then, the waitlist can only notify by email and the admin panel cannot show stored signups.
                </p>
              </section>
            ) : null}
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
