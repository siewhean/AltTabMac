import type { Metadata } from "next";
import Image from "next/image";

import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { getAdminAuthMode, hasAdminSession, isAdminAuthConfigured } from "@/lib/admin-auth";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Dashboard Login | CmdTab",
  description: "Protected access page for the CmdTab admin dashboard.",
};

export default async function DashboardLoginPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  if (await hasAdminSession()) {
    return (
      <main>
        <SectionShell className="pt-24">
          <div className="mx-auto flex min-h-[60vh] max-w-[420px] flex-col items-center justify-center text-center">
            <Image
              src="/brand/cmdtab.png"
              alt="CmdTab"
              width={84}
              height={84}
              className="mb-6 rounded-[22px]"
              priority
            />
            <h1 className="text-3xl font-medium tracking-[-0.05em] text-text">
              Dashboard unlocked
            </h1>
            <div className="mt-6">
              <Button href="/dashboard">Open dashboard</Button>
            </div>
          </div>
        </SectionShell>
      </main>
    );
  }

  const params = (await searchParams) ?? {};
  const error = typeof params.error === "string" ? params.error : undefined;
  const authConfigured = await isAdminAuthConfigured();
  const authMode = getAdminAuthMode();

  return (
    <main>
      <SectionShell className="pt-24">
        <div className="mx-auto flex min-h-[60vh] max-w-[460px] flex-col items-center justify-center">
          <div className="mb-8 flex flex-col items-center text-center">
            <Image
              src="/brand/cmdtab.png"
              alt="CmdTab"
              width={92}
              height={92}
              className="mb-6 rounded-[24px]"
              priority
            />
            <h1 className="text-4xl font-medium tracking-[-0.06em] text-text">CmdTab</h1>
          </div>

          <div className="w-full rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl">
          {authConfigured && authMode === "auth0" ? (
            <div className="space-y-5">
              <p className="text-sm leading-7 text-muted">
                Continue through CmdTab&apos;s hosted owner login. Multi-factor authentication is
                required before the dashboard accepts the configured owner identity.
              </p>
              {error ? (
                <p className="rounded-2xl border border-rose-400/20 bg-rose-400/8 px-4 py-3 text-sm text-rose-100">
                  Dashboard sign-in could not be verified. Start a new login and try again.
                </p>
              ) : null}
              <Button href="/dashboard/auth/login" className="w-full">
                Continue with secure login
              </Button>
            </div>
          ) : authConfigured && authMode === "legacy" ? (
            <form action="/dashboard/login/submit" method="post" className="space-y-5">
              <div className="space-y-2">
                <label
                  htmlFor="password"
                  className="text-[11px] font-semibold uppercase tracking-[0.22em] text-cyan"
                >
                  Password
                </label>
                <input
                  id="password"
                  name="password"
                  type="password"
                  required
                  className="w-full rounded-[18px] border border-white/10 bg-white/[0.03] px-4 py-3 text-sm text-text outline-hidden transition focus:border-cyan/40"
                />
              </div>

              {error === "invalid" ? (
                <p className="rounded-2xl border border-rose-400/20 bg-rose-400/8 px-4 py-3 text-sm text-rose-100">
                  Incorrect password.
                </p>
              ) : null}

              <Button type="submit" className="w-full">
                Continue
              </Button>
            </form>
          ) : (
            <div className="rounded-2xl border border-rose-400/20 bg-rose-400/8 px-4 py-3 text-sm text-rose-100">
              Dashboard login is unavailable because its production security configuration is
              incomplete.
            </div>
          )}
        </div>
      </div>
      </SectionShell>
    </main>
  );
}
