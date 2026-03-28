import type { Metadata } from "next";

import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { commerceContent } from "@/content/commerce";
import { dashboardContent } from "@/content/dashboard";
import { getCommerceConfig } from "@/lib/commerce";

export const metadata: Metadata = {
  title: "Dashboard | CmdTab",
  description: "Owner-facing launch dashboard for the CmdTab website funnel and offer setup.",
  alternates: {
    canonical: "/dashboard",
  },
};

export default function DashboardPage() {
  const commerce = getCommerceConfig();

  const configStatus = [
    {
      label: "Checkout provider",
      value: commerce.checkoutProvider ?? "Not configured",
    },
    {
      label: "Checkout URL",
      value: commerce.checkoutUrl ? "Configured" : "Missing",
    },
    {
      label: "Trial URL",
      value: commerce.trialDownloadUrl ? "Configured" : "Missing",
    },
    {
      label: "Support email",
      value: commerce.supportEmail ?? "Missing",
    },
  ];

  return (
    <main>
      <SectionShell
        eyebrow="Dashboard"
        title={dashboardContent.title}
        description={dashboardContent.summary}
        className="pt-24"
      >
        <div className="space-y-10">
          <div className="grid gap-5 lg:grid-cols-[minmax(0,0.82fr)_minmax(0,1.18fr)]">
            <section className="rounded-[28px] border border-white/10 bg-white/[0.04] p-6 shadow-panel backdrop-blur-xl">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Active offer
              </p>
              <div className="mt-5 grid gap-4 sm:grid-cols-3">
                {dashboardContent.offer.map((item) => (
                  <div
                    key={item.label}
                    className="rounded-[22px] border border-white/8 bg-white/[0.03] p-4"
                  >
                    <p className="text-[11px] uppercase tracking-[0.22em] text-subdued">
                      {item.label}
                    </p>
                    <p className="mt-3 text-2xl font-medium tracking-[-0.04em] text-text">
                      {item.value}
                    </p>
                  </div>
                ))}
              </div>
              <p className="mt-5 text-sm leading-6 text-muted">
                Founder launch is currently set to {commerceContent.founder.price}, with a
                standard one-time price of {commerceContent.standard.price} after the founder
                window.
              </p>
            </section>

            <section className="rounded-[28px] border border-white/10 bg-white/[0.03] p-6 shadow-panel backdrop-blur-xl">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Launch config status
              </p>
              <div className="mt-5 grid gap-3">
                {configStatus.map((item) => (
                  <div
                    key={item.label}
                    className="flex items-center justify-between gap-4 rounded-[18px] border border-white/8 bg-white/[0.03] px-4 py-3"
                  >
                    <p className="text-sm leading-6 text-muted">{item.label}</p>
                    <p className="text-sm font-medium text-text">{item.value}</p>
                  </div>
                ))}
              </div>
            </section>
          </div>

          <div className="grid gap-5 xl:grid-cols-3">
            {dashboardContent.funnelMetrics.map((section) => (
              <section
                key={section.title}
                className="rounded-[28px] border border-white/10 bg-white/[0.03] p-6 shadow-panel backdrop-blur-xl"
              >
                <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                  {section.title}
                </p>
                <div className="mt-5 space-y-3">
                  {section.metrics.map((metric) => (
                    <div key={metric} className="flex items-start gap-3 text-sm leading-6 text-subdued">
                      <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                      <span>{metric}</span>
                    </div>
                  ))}
                </div>
              </section>
            ))}
          </div>

          <section className="rounded-[28px] border border-cyan/20 bg-cyan/[0.07] p-6 shadow-panel">
            <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              Preference tracking
            </p>
            <p className="mt-4 max-w-4xl text-base leading-7 text-text">
              {dashboardContent.privacyNote}
            </p>
          </section>

          <div className="grid gap-5 lg:grid-cols-2">
            {dashboardContent.sources.map((source) => (
              <section
                key={source.title}
                className="rounded-[28px] border border-white/10 bg-white/[0.03] p-6 shadow-panel backdrop-blur-xl"
              >
                <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                  Data source
                </p>
                <h2 className="mt-4 text-2xl font-medium tracking-[-0.04em] text-text">
                  {source.title}
                </h2>
                <p className="mt-3 text-base leading-7 text-muted">{source.body}</p>
                <div className="mt-6">
                  <Button href={source.href} target="_blank" rel="noreferrer">
                    Open dashboard
                  </Button>
                </div>
              </section>
            ))}
          </div>
        </div>
      </SectionShell>
    </main>
  );
}
