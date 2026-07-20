import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab security disclosure policy";
const description =
  "Review how to report security issues affecting the CmdTab website, analytics, trial delivery, purchase and licensing flow, or native macOS app, including current scope and safe-testing boundaries.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Security", path: "/security" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/security",
  imageAlt: "CmdTab security disclosure policy",
});

const disclosureSections = [
  {
    title: "How to report a vulnerability",
    body: [
      `Report suspected security issues privately to ${productFacts.contactEmail}.`,
      "Include the affected URL, app version or build, macOS version, feature, clear reproduction steps, impact, logs that do not expose other people's data, and a minimal proof of concept when one is needed to validate the issue.",
    ],
  },
  {
    title: "Current scope",
    body: [
      "In scope: the cmdtab.net website and APIs, dashboard authentication, analytics ingestion, trial registration, checkout and webhook handling, license generation and delivery, the native CmdTab app, update and release packaging, and the public repository configuration.",
      "Third-party platforms such as Vercel, Resend, GitHub, and the configured commerce provider are governed by their own disclosure programs unless the issue is caused by CmdTab's integration or configuration.",
    ],
  },
  {
    title: "Safe testing boundaries",
    body: [
      "Do not access data that is not yours, publish an unpatched vulnerability, destroy or alter production data, send malware, conduct social engineering, or perform sustained denial-of-service testing.",
      "Use the minimum traffic and data needed to demonstrate the issue. Stop testing and report immediately if you encounter personal, licensing, or payment information belonging to another user.",
    ],
  },
  {
    title: "Response and remediation",
    body: [
      "Reports are reviewed for reproducibility, affected versions, user impact, and available mitigations. CmdTab may request clarification or a safer proof of concept before confirming the issue.",
      "No guaranteed response time or public bug-bounty payment is promised today. Coordinated disclosure timing should be agreed before technical details are published.",
    ],
  },
];

export default function SecurityPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/security",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Security"
        title="CmdTab security disclosure"
        description="Use this page to report security issues privately and understand which systems, versions, and testing methods are currently in scope."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} />
          <p className="text-sm text-subdued">Current documented app: {productFacts.currentVersion}</p>
        </div>
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
            <Button href={`mailto:${productFacts.contactEmail}`}>Report privately</Button>
            <Button href={productFacts.sourceRepository} target="_blank" rel="noreferrer" variant="secondary">
              Review public source
            </Button>
            <Button href="/privacy" variant="secondary">
              Read the privacy policy
            </Button>
          </div>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
