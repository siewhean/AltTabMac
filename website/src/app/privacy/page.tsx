import { JsonLd } from "@/components/seo/json-ld";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { privacyContent } from "@/content/legal";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = createPageMetadata({
  title: "CmdTab privacy policy",
  description:
    "Review privacy details for the CmdTab website, trial flow, hosted purchase links, analytics, and support requests.",
  path: "/privacy",
  imageAlt: "CmdTab privacy policy",
});

export default function PrivacyPage() {
  return (
    <main>
      <JsonLd
        data={createBreadcrumbStructuredData([
          { name: "Home", path: "/" },
          { name: "Privacy", path: "/privacy" },
        ])}
      />
      <SectionShell
        headingAs="h1"
        eyebrow="Privacy"
        title="CmdTab website privacy"
        description={privacyContent.intro}
        className="pt-24"
      >
        <div className="space-y-10">
          {privacyContent.sections.map((section) => (
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
            <Button href="/">Back to the site</Button>
            <Button href="mailto:tohsh17@gmail.com" variant="secondary">
              Contact tohsh17@gmail.com
            </Button>
            <Button href="/security" variant="secondary">
              View security policy
            </Button>
          </div>
        </div>
      </SectionShell>
    </main>
  );
}
