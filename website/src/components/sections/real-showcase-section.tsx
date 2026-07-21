import Link from "next/link";

import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { SectionShell } from "@/components/ui/section-shell";
import { showcaseAsset, showcaseDisclosure } from "@/content/showcase";

export function RealShowcaseSection() {
  const overview = showcaseAsset("overview");

  return (
    <SectionShell
      id="showcase"
      eyebrow="Product showcase"
      title="Watch CmdTab’s current interaction model"
      description="The overview is a polished deterministic product composite; the full showcase also includes an authentic production SwiftUI render of Radial Menu. Every asset uses controlled fixtures and a visible source label."
      className="pt-8"
    >
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1.25fr)_minmax(280px,0.55fr)] lg:items-center">
        <ShowcaseVideo asset={overview} compact />
        <div className="surface-panel p-7">
          <p className="type-eyebrow text-cyan">What is shown</p>
          <p className="mt-4 text-base leading-8 text-muted">{showcaseDisclosure}</p>
          <ul className="mt-6 space-y-3 text-sm leading-7 text-subdued">
            <li className="border-l border-cyan/35 pl-4">An authentic production SwiftUI/AppKit Radial Menu render.</li>
            <li className="border-l border-cyan/35 pl-4">Deterministic product composites for the remaining surfaces.</li>
            <li className="border-l border-cyan/35 pl-4">Silent H.264 clips and fast WebP posters with stable public URLs.</li>
          </ul>
          <Link
            href="/showcase"
            className="mt-7 inline-flex min-h-11 items-center justify-center rounded-full border border-cyan/25 bg-cyan/10 px-5 text-sm font-medium text-text transition-colors hover:bg-cyan/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
          >
            Open the full showcase
          </Link>
        </div>
      </div>
    </SectionShell>
  );
}
