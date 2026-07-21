import Link from "next/link";

import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";

const resources = [
  {
    href: "/features/window-switcher",
    eyebrow: "Product behavior",
    title: "How the exact-window switcher works",
    body: "Review multiple windows per app, global recent-use ordering, preview fallback, Spaces, displays, and activation behavior.",
  },
  {
    href: "/guides/switch-between-windows-on-mac",
    eyebrow: "Mac guide",
    title: "Choose between Cmd+Tab, Cmd+`, Mission Control, and CmdTab",
    body: "Match the native shortcut or CmdTab workflow to the switching problem you actually need to solve.",
  },
  {
    href: "/compare/cmdtab-vs-macos-command-tab",
    eyebrow: "Fair comparison",
    title: "CmdTab versus the built-in macOS switcher",
    body: "Compare apps, individual windows, previews, search, permissions, quick actions, and setup without pretending one option fits everyone.",
  },
  {
    href: "/privacy",
    eyebrow: "Trust",
    title: "Read the exact privacy and telemetry contract",
    body: "See which website and app fields are recorded, which local window data is excluded, and why Accessibility and Screen Recording are used.",
  },
] as const;

export function DiscoveryResourcesSection() {
  return (
    <SectionShell
      eyebrow="Authoritative resources"
      title="Verify the product instead of relying on a slogan"
      description="CmdTab publishes separate factual pages for product behavior, native macOS workflows, comparison, compatibility, permissions, and privacy."
      className="pt-8"
    >
      <div className="grid gap-5 md:grid-cols-2">
        {resources.map((resource, index) => (
          <MotionReveal key={resource.href} direction="up" delay={index * 60}>
            <Link
              href={resource.href}
              className="surface-panel group block h-full p-7 transition-transform duration-200 hover:-translate-y-0.5"
            >
              <p className="type-eyebrow text-cyan">{resource.eyebrow}</p>
              <h2 className="mt-4 text-2xl font-medium tracking-[-0.04em] text-text">
                {resource.title}
              </h2>
              <p className="mt-4 text-sm leading-7 text-muted">{resource.body}</p>
              <p className="mt-6 text-sm font-medium text-cyan transition-colors group-hover:text-text">
                Read the source →
              </p>
            </Link>
          </MotionReveal>
        ))}
      </div>
    </SectionShell>
  );
}
