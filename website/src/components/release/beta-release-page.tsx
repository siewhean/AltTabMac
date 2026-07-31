import Link from "next/link";
import { notFound } from "next/navigation";

import { betaNavigation } from "@/content/beta";
import { siteConfig } from "@/content/site";
import { getBetaReleaseManifest } from "@/lib/stable-release";

type BetaPageKind =
  | "download"
  | "installation"
  | "limitations"
  | "permissions"
  | "updates"
  | "support"
  | "security"
  | "license-recovery";

const content: Record<BetaPageKind, { title: string; description: string; body: readonly string[] }> = {
  download: {
    title: "CmdTab public beta",
    description: "Download the signed CmdTab beta for Apple silicon Macs running macOS 13 Ventura or later.",
    body: [
      "This is the CmdTab beta channel. Stable downloads and stable updates are not published during beta.",
      "The beta is a direct DMG download for Apple silicon only. It does not offer a checkout or take payment.",
    ],
  },
  installation: {
    title: "Install the CmdTab beta",
    description: "Open the verified beta DMG, drag CmdTab to Applications, then grant the macOS permissions the switcher needs.",
    body: [
      "Open the downloaded DMG and drag CmdTab.app into Applications. Open the copied app from Applications rather than running it from the disk image.",
      "CmdTab asks for Accessibility to switch exact windows. Screen Recording enables window previews; when it is unavailable, eligible windows remain represented with an icon or placeholder.",
    ],
  },
  limitations: {
    title: "CmdTab beta limitations",
    description: "The beta is Apple-silicon-only and does not claim coverage for configurations that have not completed clean-machine acceptance.",
    body: [
      "Intel Macs, untested display topologies, Stage Manager edge cases, and untested macOS configurations are not supported by this beta claim.",
      "A beta download does not replace the documented real-machine acceptance matrix for permissions, Spaces, fullscreen, sleep and wake, or update rollback.",
    ],
  },
  permissions: {
    title: "CmdTab beta permissions",
    description: "Understand the beta’s Accessibility and Screen Recording permissions before installing it.",
    body: [
      "Accessibility is used for shortcut handling, eligible-window inspection, and exact-window activation. Screen Recording is used only to render local previews.",
      "The published telemetry boundary excludes window titles, previews, screenshots, keystrokes, file names, clipboard contents, and search queries.",
    ],
  },
  updates: {
    title: "CmdTab beta updates",
    description: "Beta builds use the isolated beta appcast. Stable update endpoints remain unavailable until general availability.",
    body: [
      "Only signed beta updates from the beta channel are eligible. Do not point a beta install at a stable feed or a third-party download.",
      "If an update is interrupted, rejected, or unavailable, keep the currently installed beta and contact support instead of using an unverified replacement.",
    ],
  },
  support: {
    title: "CmdTab beta support",
    description: "Contact CmdTab support for installation, permission, beta-update, or recovery guidance.",
    body: [
      `Email ${siteConfig.contactEmail} with your CmdTab version, macOS version, Mac type, and a concise description of the issue. Do not include credentials or private window content.`,
      "Support is provided without a guaranteed response time. Use the security path for a suspected vulnerability.",
    ],
  },
  security: {
    title: "Report a CmdTab beta security issue",
    description: "Report suspected vulnerabilities privately without accessing data that is not yours or disrupting service.",
    body: [
      `Send a private report to ${siteConfig.contactEmail} with the affected build, macOS version, reproduction steps, and impact. Do not send secrets or other people’s data.`,
      "Do not publish unpatched details, alter production data, use social engineering, or perform sustained denial-of-service testing.",
    ],
  },
  "license-recovery": {
    title: "CmdTab beta licence recovery",
    description: "The public beta has no purchase or payment path. Existing licence holders can ask for recovery guidance without disclosing account credentials.",
    body: [
      `For an existing licence recovery issue, email ${siteConfig.contactEmail} from the address associated with the purchase and include only the information needed to locate the record. CmdTab will never ask for your password.`,
      "No beta user can buy, renew, or otherwise pay for CmdTab from this site. The planned US$12 personal licence is for general availability only.",
    ],
  },
};

export function BetaReleasePage({ kind }: { kind: BetaPageKind }) {
  const release = getBetaReleaseManifest();
  if (!release) notFound();
  const page = content[kind];

  return (
    <main className="mx-auto min-h-screen max-w-4xl px-5 py-12 text-text sm:px-8">
      <header className="border-b border-white/10 pb-6">
        <Link href="/" className="text-sm font-semibold text-cyan">CmdTab</Link>
        <h1 className="mt-4 text-4xl font-semibold tracking-[-0.05em]">{page.title}</h1>
        <p className="mt-4 max-w-3xl text-lg leading-8 text-muted">{page.description}</p>
      </header>
      <nav aria-label="CmdTab beta" className="flex flex-wrap gap-x-4 gap-y-2 border-b border-white/10 py-4 text-sm text-cyan">
        {betaNavigation.map((item) => <Link key={item.href} href={item.href}>{item.label}</Link>)}
      </nav>
      <section className="space-y-5 py-8 text-base leading-8 text-muted">
        {page.body.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
        {kind === "download" ? (
          <div className="rounded-2xl border border-cyan/20 bg-cyan/[0.06] p-6">
            <a className="text-lg font-semibold text-cyan underline" href={release.dmgURL}>Download CmdTab {release.version} (DMG)</a>
            <dl className="mt-5 grid gap-2 text-sm sm:grid-cols-[10rem_1fr]">
              <dt>Build</dt><dd>{release.build}</dd>
              <dt>Minimum macOS</dt><dd>{release.minimumMacOS} (Ventura) or later</dd>
              <dt>Architecture</dt><dd>Apple silicon (arm64) only</dd>
              <dt>SHA-256</dt><dd className="break-all font-mono text-xs">{release.sha256}</dd>
              <dt>Source commit</dt><dd className="break-all font-mono text-xs">{release.sourceSHA}</dd>
            </dl>
          </div>
        ) : null}
        {kind === "support" || kind === "security" || kind === "license-recovery" ? (
          <p><a className="text-cyan underline" href={`mailto:${siteConfig.contactEmail}`}>Email {siteConfig.contactEmail}</a></p>
        ) : null}
      </section>
    </main>
  );
}
