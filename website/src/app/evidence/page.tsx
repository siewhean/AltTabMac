import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { evidenceLedger } from "@/content/evidence";
import { createPageMetadata } from "@/lib/seo";
import {
  createArticleStructuredData,
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab testing, evidence, and validation boundaries";
const description =
  "Review CmdTab's automated exact-window MRU and completeness evidence, download the public test artifacts, and see which macOS desktop behaviors still require manual validation.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Testing and evidence", path: "/evidence" as const },
];
const publicArtifactUrls = evidenceLedger.publicArtifacts.map(
  (artifact) => `https://cmdtab.net${artifact.href}`,
);

export const metadata = createPageMetadata({
  title,
  description,
  path: "/evidence",
  imageAlt: "CmdTab testing evidence and validation boundaries",
});

export default function EvidencePage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/evidence",
          dateModified: evidenceLedger.reviewedAt,
        })}
      />
      <JsonLd
        data={createArticleStructuredData({
          headline: title,
          description,
          path: "/evidence",
          datePublished: evidenceLedger.reviewedAt,
          dateModified: evidenceLedger.reviewedAt,
          about: [
            "CmdTab",
            "macOS window switching",
            "software testing",
            "exact-window recent-use ordering",
            "window-switcher completeness",
          ],
          citation: publicArtifactUrls,
        })}
      />

      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Evidence ledger"
        title="What CmdTab has proved—and what it has not"
        description="This page separates reproducible automation from real-desktop acceptance work. The goal is not to turn test counts into marketing claims; it is to make the evidence and its limits inspectable."
        className="pt-14"
      >
        <div className="mb-10 flex flex-col gap-3 border-b border-white/8 pb-8 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={evidenceLedger.reviewedAt} />
          <p className="text-sm text-subdued">
            Product alignment commit:{" "}
            <code className="font-mono text-text">
              {evidenceLedger.productAlignmentCommit.slice(0, 12)}
            </code>
          </p>
        </div>

        <section aria-labelledby="automated-evidence">
          <div className="max-w-3xl">
            <p className="type-eyebrow text-cyan">Automated evidence</p>
            <h2
              id="automated-evidence"
              className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
            >
              Repeated checks that block regressions
            </h2>
            <p className="mt-4 text-base leading-8 text-muted">
              Each item below is exercised by committed tests or verification scripts. A green
              check means the defined contract passed in that environment; it does not convert a
              simulator, model, or CI host into proof of every macOS desktop state.
            </p>
          </div>

          <div className="mt-8 grid gap-5 md:grid-cols-2">
            {evidenceLedger.automated.map((item) => (
              <article key={item.title} className="surface-panel p-7">
                <h3 className="text-xl font-medium tracking-[-0.03em] text-text">
                  {item.title}
                </h3>
                <p className="mt-4 text-sm leading-7 text-muted">{item.result}</p>
                <p className="mt-5 border-t border-white/8 pt-4 text-xs leading-6 text-subdued">
                  Environment: {item.environment}
                </p>
              </article>
            ))}
          </div>
        </section>

        <section aria-labelledby="public-artifacts" className="mt-16 border-t border-white/8 pt-12">
          <div className="max-w-3xl">
            <p className="type-eyebrow text-cyan">Downloadable artifacts</p>
            <h2
              id="public-artifacts"
              className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
            >
              Inspect the model, matrix, and execution plan
            </h2>
            <p className="mt-4 text-base leading-8 text-muted">
              These files are published from the same repository blobs used by the protected
              switcher review. The website build fails if the public model or matrix diverges from
              its canonical QA source.
            </p>
          </div>

          <div className="mt-8 grid gap-4">
            {evidenceLedger.publicArtifacts.map((artifact) => (
              <a
                key={artifact.href}
                href={artifact.href}
                className="surface-muted group grid gap-3 p-6 transition-transform duration-200 hover:-translate-y-0.5 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center"
              >
                <span>
                  <span className="block text-lg font-medium text-text">{artifact.label}</span>
                  <span className="mt-2 block text-sm leading-7 text-muted">
                    {artifact.description}
                  </span>
                </span>
                <span className="text-sm font-medium text-cyan group-hover:text-text">
                  Open artifact →
                </span>
              </a>
            ))}
          </div>
        </section>

        <section aria-labelledby="manual-boundary" className="mt-16 border-t border-white/8 pt-12">
          <div className="max-w-3xl">
            <p className="type-eyebrow text-cyan">Manual boundary</p>
            <h2
              id="manual-boundary"
              className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
            >
              Real macOS conditions that automation does not honestly replace
            </h2>
            <p className="mt-4 text-base leading-8 text-muted">
              These scenarios require an interactive Mac, real permissions, real Spaces and
              displays, and focused-window evidence. Until each relevant row is executed, the
              public claim is limited to the automated contract above.
            </p>
          </div>

          <ul className="mt-8 grid gap-4 md:grid-cols-2">
            {evidenceLedger.manualBoundary.map((item) => (
              <li
                key={item}
                className="rounded-[22px] border border-white/10 bg-white/[0.03] px-5 py-4 text-sm leading-7 text-muted"
              >
                {item}
              </li>
            ))}
          </ul>
        </section>

        <section aria-labelledby="interpretation" className="mt-16 border-t border-white/8 pt-12">
          <div className="max-w-3xl">
            <p className="type-eyebrow text-cyan">How to interpret the numbers</p>
            <h2
              id="interpretation"
              className="mt-4 text-3xl font-medium tracking-[-0.05em] text-text"
            >
              State-space counts are not field failure rates
            </h2>
            <p className="mt-4 text-base leading-8 text-muted">
              The model counts every selected configuration in a deliberately small synthetic
              universe. Its 3,900 selection mismatches and 120 completeness failures describe the
              old rules inside that universe. They do not mean that 20% or 95% of real CmdTab use
              failed. Their value is reproducibility: the repaired implementation must satisfy the
              explicit invariants for every covered state.
            </p>
          </div>
        </section>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
