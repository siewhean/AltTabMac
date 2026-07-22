import Link from "next/link";

import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { SectionShell } from "@/components/ui/section-shell";
import { showcaseAsset, showcaseDisclosure } from "@/content/showcase";

export function RealShowcaseSection() {
  const overview = showcaseAsset("overview");

  return (
    <SectionShell
      id="showcase"
      eyebrow="HD product showcase"
      title="Watch CmdTab’s current interaction model in sharp detail"
      description="The overview and motion clips are deterministic 1920 × 1200 product composites rendered at 30 fps from vector source. Every asset uses controlled fixtures and a visible source label."
      className="pt-8"
    >
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1.25fr)_minmax(280px,0.55fr)] lg:items-center">
        <ShowcaseVideo asset={overview} compact />
        <div className="surface-panel p-7">
          <p className="type-eyebrow text-cyan">What is shown</p>
          <p className="mt-4 text-base leading-8 text-muted">{showcaseDisclosure}</p>
          <ul className="mt-6 space-y-3 text-sm leading-7 text-subdued">
            <li className="border-l border-cyan/35 pl-4">Five sharp 1920 × 1200 WebP posters.</li>
            <li className="border-l border-cyan/35 pl-4">Three silent H.264 motion clips at 30 fps.</li>
            <li className="border-l border-cyan/35 pl-4">Deterministic product composites generated from vector source, not upscaled low-resolution footage.</li>
          </ul>
          <Link
            href="/showcase"
            className="mt-7 inline-flex min-h-11 items-center justify-center rounded-full border border-cyan/25 bg-cyan/10 px-5 text-sm font-medium text-text transition-colors hover:bg-cyan/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
          >
            Open the full HD showcase
          </Link>
        </div>
      </div>
    </SectionShell>
  );
}
