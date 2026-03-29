import type { Metadata } from "next";

import { DashboardShell } from "@/components/dashboard/dashboard-shell";
import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { getDashboardAuthSummary } from "@/lib/admin-store";
import { requireAdminSession } from "@/lib/admin-auth";
import { formatSingaporeDateTime } from "@/lib/date";
import { isDatabaseConfigured } from "@/lib/postgres";

export const metadata: Metadata = {
  title: "Dashboard Settings | CmdTab",
  description: "Admin settings for the CmdTab dashboard.",
  alternates: {
    canonical: "/dashboard/settings",
  },
};

export default async function DashboardSettingsPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireAdminSession();

  const params = (await searchParams) ?? {};
  const status = typeof params.status === "string" ? params.status : undefined;
  const error = typeof params.error === "string" ? params.error : undefined;
  const databaseConfigured = isDatabaseConfigured();
  const authSummary = await getDashboardAuthSummary();

  return (
    <DashboardShell
      active="/dashboard/settings"
      title="Dashboard settings"
      description="Manage admin access, confirm database state, and keep the owner dashboard private."
    >
      <section className="grid gap-5 lg:grid-cols-3">
        {[
          { label: "Database", value: databaseConfigured ? "Connected" : "Missing" },
          {
            label: "Password source",
            value:
              authSummary.source === "database"
                ? "Database"
                : authSummary.source === "environment"
                  ? "Environment"
                  : "Missing",
          },
          {
            label: "Password updated",
            value: authSummary.updatedAt
              ? formatSingaporeDateTime(authSummary.updatedAt)
              : "Not changed yet",
          },
        ].map((item) => (
          <section
            key={item.label}
            className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl"
          >
            <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">{item.label}</p>
            <p className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">{item.value}</p>
          </section>
        ))}
      </section>

      <section className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl">
        <div className="border-b border-white/8 pb-5">
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
            Security
          </p>
          <h2 className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
            Change dashboard password
          </h2>
          <p className="mt-3 max-w-2xl text-sm leading-7 text-muted">
            The first change moves dashboard login off the Vercel environment password and into the
            database so you can rotate it directly from this page.
          </p>
        </div>

        <form action="/dashboard/settings/update-password" method="post" className="mt-6 space-y-5">
          <FormField
            id="currentPassword"
            label="Current password"
            name="currentPassword"
            type="password"
            autoComplete="current-password"
            required
          />
          <FormField
            id="newPassword"
            label="New password"
            name="newPassword"
            type="password"
            autoComplete="new-password"
            minLength={12}
            required
          />
          <FormField
            id="confirmPassword"
            label="Confirm new password"
            name="confirmPassword"
            type="password"
            autoComplete="new-password"
            minLength={12}
            required
          />

          {status === "updated" ? (
            <p className="rounded-2xl border border-emerald-400/20 bg-emerald-400/[0.08] px-4 py-3 text-sm text-emerald-100">
              Dashboard password updated.
            </p>
          ) : null}

          {error === "current" ? (
            <p className="rounded-2xl border border-rose-400/20 bg-rose-400/[0.08] px-4 py-3 text-sm text-rose-100">
              The current password was incorrect.
            </p>
          ) : null}

          {error === "mismatch" ? (
            <p className="rounded-2xl border border-rose-400/20 bg-rose-400/[0.08] px-4 py-3 text-sm text-rose-100">
              The new password and confirmation did not match.
            </p>
          ) : null}

          {error === "length" ? (
            <p className="rounded-2xl border border-rose-400/20 bg-rose-400/[0.08] px-4 py-3 text-sm text-rose-100">
              Use at least 12 characters for the new dashboard password.
            </p>
          ) : null}

          <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
            <Button type="submit">Save new password</Button>
            <p className="text-sm leading-6 text-subdued">
              This updates admin login immediately for future dashboard sessions.
            </p>
          </div>
        </form>
      </section>

      <section className="rounded-[28px] border border-white/10 bg-white/[0.03] p-6 shadow-panel backdrop-blur-xl">
        <div className="border-b border-white/8 pb-5">
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
            Operational notes
          </p>
          <h2 className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
            Admin environment status
          </h2>
        </div>
        <div className="mt-5 space-y-3 text-sm leading-7 text-muted">
          <p>
            The dashboard uses the connected Postgres database to store waitlist entries and, after
            your first password change, the dashboard login hash.
          </p>
          <p>
            If you ever need to invalidate access manually, rotate the dashboard password here and
            old sessions will naturally expire within twelve hours.
          </p>
        </div>
      </section>
    </DashboardShell>
  );
}
