import type { Metadata } from "next";

import { DashboardShell } from "@/components/dashboard/dashboard-shell";
import { requireAdminSession } from "@/lib/admin-auth";
import {
  getAIDiscoveryOverview,
  isDiscoveryAnalyticsConfigured,
} from "@/lib/discovery-analytics-store";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Search and AI discovery | CmdTab dashboard",
  description: "Private CmdTab search and AI-assisted referral analytics.",
};

const sourceLabels: Record<string, string> = {
  chatgpt: "ChatGPT",
  perplexity: "Perplexity",
  microsoft_copilot: "Microsoft Copilot",
  google_gemini: "Google Gemini",
  claude: "Claude",
};

export default async function DiscoveryDashboardPage() {
  await requireAdminSession();

  const configured = isDiscoveryAnalyticsConfigured();
  const overview = await getAIDiscoveryOverview(30);

  return (
    <DashboardShell
      active="/dashboard/discovery"
      title="Search and AI discovery"
      description="First-party referral evidence for ChatGPT, Perplexity, Copilot, Gemini, and Claude landing sessions."
    >
      {!configured ? (
        <section className="surface-panel p-6 text-sm leading-7 text-muted">
          Configure the website database to store first-party discovery events.
        </section>
      ) : null}

      <section className="grid gap-4 md:grid-cols-2">
        <div className="surface-panel p-6">
          <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">AI-assisted pageviews · 30d</p>
          <p className="mt-3 text-4xl font-medium tracking-[-0.06em] text-text">
            {overview.pageviews30d}
          </p>
        </div>
        <div className="surface-panel p-6">
          <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">AI-assisted visitors · 30d</p>
          <p className="mt-3 text-4xl font-medium tracking-[-0.06em] text-text">
            {overview.visitors30d}
          </p>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-2">
        <div className="surface-panel p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
            Discovery sources
          </p>
          <div className="mt-5 space-y-3">
            {overview.sources.length > 0 ? (
              overview.sources.map((item) => (
                <div key={item.label} className="flex items-center justify-between gap-4 text-sm">
                  <span className="text-muted">{sourceLabels[item.label] ?? item.label}</span>
                  <span className="text-text">{item.count}</span>
                </div>
              ))
            ) : (
              <p className="text-sm leading-7 text-muted">No classified AI-assisted referrals recorded yet.</p>
            )}
          </div>
        </div>

        <div className="surface-panel p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
            AI-assisted landing pages
          </p>
          <div className="mt-5 space-y-3">
            {overview.landingPages.length > 0 ? (
              overview.landingPages.map((item) => (
                <div key={item.label} className="flex items-center justify-between gap-4 text-sm">
                  <span className="truncate text-muted">{item.label}</span>
                  <span className="text-text">{item.count}</span>
                </div>
              ))
            ) : (
              <p className="text-sm leading-7 text-muted">No classified landing pages recorded yet.</p>
            )}
          </div>
        </div>
      </section>

      <section className="surface-panel p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
          Measurement boundaries
        </p>
        <div className="mt-4 space-y-3 text-sm leading-7 text-muted">
          <p>
            A session is classified from a recognized referrer hostname or a bounded <code className="text-text">utm_source</code> label. CmdTab does not store the visitor's prompt or search query.
          </p>
          <p>
            Missing referrers, privacy tools, copied links, in-app browsers, and platform redirectors can undercount or misclassify discovery. Use this dashboard with Google Search Console's generative-AI reports, Bing Webmaster Tools AI Performance, and platform-specific referral data rather than treating one source as complete.
          </p>
        </div>
      </section>
    </DashboardShell>
  );
}
