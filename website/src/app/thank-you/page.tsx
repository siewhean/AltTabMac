import { createPageMetadata } from "@/lib/seo";
import { JsonLd } from "@/components/seo/json-ld";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";
import Link from "next/link";
import { Suspense } from "react";
import { SectionShell } from "@/components/ui/section-shell";
import { Button } from "@/components/ui/button";

const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Thank You", path: "/thank-you" as const },
];

export const metadata = createPageMetadata({
  title: "Thank You for Purchasing CmdTab — Next-Generation Window Switcher for Mac",
  description: "Your purchase is complete. Activate CmdTab on your Mac with one click.",
  path: "/thank-you",
  noIndex: true,
});

export default function ThankYouPage({
  searchParams,
}: {
  searchParams: Promise<{ key?: string }>;
}) {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <Suspense fallback={<ThankYouLoading />}>
        <ThankYouContent searchParams={searchParams} />
      </Suspense>
    </main>
  );
}

function ThankYouLoading() {
  return (
    <SectionShell eyebrow="Purchase Complete" title="Thank you for buying CmdTab!">
      <div className="surface-panel p-8 text-center text-muted">
        Loading purchase receipt...
      </div>
    </SectionShell>
  );
}

async function ThankYouContent({
  searchParams,
}: {
  searchParams: Promise<{ key?: string }>;
}) {
  const resolvedParams = await searchParams;
  const rawKey = resolvedParams.key || "";
  const licenseKey = rawKey.trim();
  const deepLink = licenseKey
    ? `cmdtab://activate?key=${encodeURIComponent(licenseKey)}`
    : "cmdtab://activate";

  return (
    <SectionShell
      headingAs="h1"
      eyebrow="Purchase Complete"
      title="Thank you for choosing CmdTab!"
      description="Your license key is ready. Activate it directly in the app or copy it below."
    >
      <div className="mx-auto max-w-2xl space-y-8">
        <div className="surface-panel space-y-6 p-8">
          <div className="flex items-center gap-3 text-cyan">
            <svg
              className="h-6 w-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <h2 className="text-xl font-medium text-text">License Issued Successfully</h2>
          </div>

          <div className="rounded-lg border border-amber-500/20 bg-amber-500/10 p-4 text-xs text-amber-200">
            <span className="font-semibold">Purchasing from an iPhone, iPad, or Windows device?</span> We also emailed your key to your inbox. Open this page or your confirmation email on your Mac to activate CmdTab with one click.
          </div>

          {licenseKey ? (
            <div className="space-y-4">
              <p className="text-sm text-muted">
                Click the button below to automatically activate CmdTab on this Mac:
              </p>
              <a
                href={deepLink}
                className="inline-flex h-12 w-full items-center justify-center rounded-lg bg-cyan font-semibold text-slate-950 transition-opacity hover:opacity-90"
              >
                Activate CmdTab Now
              </a>

              <div className="space-y-2 pt-4">
                <label className="text-xs font-semibold uppercase tracking-wider text-muted">
                  Your License Key
                </label>
                <div className="rounded-lg border border-white/10 bg-black/40 p-4 font-mono text-xs text-cyan break-all">
                  {licenseKey}
                </div>
              </div>
            </div>
          ) : (
            <div className="space-y-4 text-sm text-muted">
              <p>
                Your license key has been emailed to your purchasing inbox.
              </p>
              <p>
                Once you copy your key, open <strong>CmdTab Settings → Licensing</strong> and paste it to activate.
              </p>
            </div>
          )}
        </div>

        <div className="surface-panel space-y-4 p-6">
          <h3 className="font-medium text-text">Manual Activation Steps</h3>
          <ol className="list-decimal space-y-2 pl-5 text-sm text-muted">
            <li>Launch CmdTab from your Applications folder.</li>
            <li>Click the menu bar icon (or open Settings) and select <strong>Licensing</strong>.</li>
            <li>Paste your license key and click <strong>Activate</strong>.</li>
          </ol>
        </div>

        <div className="flex justify-center gap-4">
          <Link href="/">
            <Button variant="ghost">Return Home</Button>
          </Link>
          <Link href="/help">
            <Button variant="ghost">Need Support?</Button>
          </Link>
        </div>
      </div>
    </SectionShell>
  );
}
