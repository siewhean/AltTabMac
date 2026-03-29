import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";

const navigation = [
  { href: "/dashboard", label: "Overview" },
  { href: "/dashboard/settings", label: "Settings" },
] as const;

type DashboardShellProps = {
  title: string;
  description: string;
  active: (typeof navigation)[number]["href"];
  children: ReactNode;
};

export function DashboardShell({
  title,
  description,
  active,
  children,
}: DashboardShellProps) {
  return (
    <main>
      <SectionShell
        eyebrow="Admin dashboard"
        title={title}
        description={description}
        className="pt-24"
      >
        <div className="grid gap-6 lg:grid-cols-[240px_minmax(0,1fr)]">
          <aside className="rounded-[28px] border border-white/10 bg-white/[0.04] p-4 shadow-panel backdrop-blur-xl">
            <p className="px-3 pb-3 text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              CmdTab admin
            </p>
            <nav className="space-y-2">
              {navigation.map((item) => (
                <a
                  key={item.href}
                  href={item.href}
                  className={`block rounded-2xl px-3 py-3 text-sm transition ${
                    item.href === active
                      ? "bg-white/10 text-text"
                      : "text-muted hover:bg-white/[0.05] hover:text-text"
                  }`}
                >
                  {item.label}
                </a>
              ))}
            </nav>
          </aside>

          <div className="space-y-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-end">
              <Button href="/dashboard/export" variant="secondary">
                Export CSV
              </Button>
              <form action="/dashboard/logout" method="post">
                <Button type="submit" variant="ghost">
                  Log out
                </Button>
              </form>
            </div>
            {children}
          </div>
        </div>
      </SectionShell>
    </main>
  );
}
