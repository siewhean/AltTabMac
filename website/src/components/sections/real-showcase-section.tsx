import Link from "next/link";

import { ShowcaseVideo } from "@/components/showcase/showcase-video";
import { SectionShell } from "@/components/ui/section-shell";
import { showcaseAsset, showcaseDisclosure } from "@/content/showcase";

export function RealShowcaseSection() {
  const overview = showcaseAsset("overview");

  return (
    <SectionShell
      id="showcase"
      eyebrow="Real product footage"
      title="Watch the production switcher instead of guessing from a mockup"
      description="The short overview is rendered from CmdTab’s actual Classic Grid, Command Palette, Radial Menu, and item-mutation views with controlled fixture windows."
      className="pt-8"
    >
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1.25fr)_minmax(280px,0.55fr)] lg:items-center">
        <ShowcaseVideo asset={overview} compact />
        <div className="surface-panel p-7">
          <p className="type-eyebrow text-cyan">What is real</p>
          <p className="mt-4 text-base leading-8 text-muted">{showcaseDisclosure}</p>
          <ul className="mt-6 space-y-3 text-sm leading-7 text-subdued">
            <li className="border-l border-cyan/35 pl-4">Production selection, filtering, radial, and item-mutation views.</li>
            <li className="border-l border-cyan/35 pl-4">System application icons and deterministic privacy-safe fixture windows.</li>
            <li className="border-l border-cyan/35 pl-4">Silent H.264 clips with stable poster and video URLs.</li>
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
