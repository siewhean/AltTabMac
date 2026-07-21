import type { Metadata } from "next";

import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";

export const metadata: Metadata = {
  title: "Security | CmdTab",
  description: "Security disclosure details for the CmdTab website, trial flow, and hosted purchase links.",
  alternates: {
    canonical: "/security",
  },
};

const disclosureSections = [
  {
    title: "How to report a vulnerability",
    body: [
      "Report suspected security issues privately to security@cmdtab.net.",
      "Include the affected URL or feature, clear reproduction steps, impact, and any proof-of-concept details that help the CmdTab team validate the issue quickly.",
    ],
  },
  {
    title: "What to avoid",
    body: [
      "Do not publish exploit details, publicly disclose unpatched issues, or access data that does not belong to you.",
      "Do not send large-scale denial-of-service traffic, automated abuse against the site, or destructive payloads to production.",
    ],
  },
  {
    title: "Current scope",
    body: [
      "The public web surface includes the marketing site, privacy page, security page, and hosted trial/purchase links.",
      "Report native macOS app issues through the same security contact when you find a security-sensitive problem.",
    ],
  },
];

export default function SecurityPage() {
  return (
    <main>
      <SectionShell
        eyebrow="Security"
        title="CmdTab security disclosure"
        description="Use this page to privately report security issues affecting the website, trial, purchase flow, or app."
        className="pt-24"
      >
        <div className="space-y-10">
          {disclosureSections.map((section) => (
            <section key={section.title} className="border-t border-white/8 pt-6">
              <h2 className="text-2xl font-medium tracking-[-0.03em] text-text">
                {section.title}
              </h2>
              <div className="mt-4 space-y-4">
                {section.body.map((paragraph) => (
                  <p key={paragraph} className="max-w-3xl text-base leading-8 text-muted">
                    {paragraph}
                  </p>
                ))}
              </div>
            </section>
          ))}

          <div className="flex flex-col gap-3 border-t border-white/8 pt-8 sm:flex-row">
            <Button href="mailto:security@cmdtab.net">Contact security@cmdtab.net</Button>
            <Button href="/privacy" variant="secondary">
              Read the privacy policy
            </Button>
          </div>
        </div>
      </SectionShell>
    </main>
  );
}
