import Link from "next/link";
import Image from "next/image";
import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";

const navigation = [
  { href: "/dashboard", label: "Overview" },
  { href: "/dashboard/discovery", label: "Search and AI discovery" },
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
        headingAs="h1"
        eyebrow="Admin dashboard"
        title={title}
        description={description}
        className="pt-24"
      >
        <div className="grid gap-6 lg:grid-cols-[250px_minmax(0,1fr)]">
          <aside className="surface-panel p-4">
            <div className="flex items-center gap-3 px-3 pb-4">
              <Image
                src="/brand/cmdtab.png"
                alt="CmdTab logo"
                width={36}
                height={36}
                className="rounded-[12px]"
              />
              <div>
                <p className="text-sm font-medium tracking-[-0.03em] text-text">CmdTab admin</p>
                <p className="text-xs text-subdued">Private operations view</p>
              </div>
            </div>
            <nav aria-label="Dashboard navigation" className="space-y-2">
              {navigation.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`block rounded-2xl px-3 py-3 text-sm transition duration-200 ${
                    item.href === active
                      ? "bg-white/10 text-text"
                      : "text-muted hover:bg-white/[0.05] hover:text-text"
                  }`}
                >
                  {item.label}
                </Link>
              ))}
            </nav>
            <div className="mt-6 space-y-3 border-t border-white/8 px-3 pt-5 text-sm leading-6 text-muted">
              <p>Overview covers the operating funnel. Discovery isolates search and AI-assisted referrals without storing user search queries.</p>
              <p className="text-subdued">Use Vercel and webmaster platforms for deeper crawl, field-performance, and index diagnostics.</p>
            </div>
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
