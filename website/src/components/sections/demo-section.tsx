import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SwitcherLiveDemo } from "@/components/ui/switcher-live-demo";
import { interactiveDemoContent } from "@/content/home";

/** Interactive, no-install demo. It was the most-used asset before the site simplification dropped it. */
export function DemoSection() {
  return (
    <SectionShell
      id="demo"
      eyebrow={interactiveDemoContent.eyebrow}
      title={interactiveDemoContent.title}
      description={interactiveDemoContent.body}
    >
      <MotionReveal direction="up">
        <SwitcherLiveDemo />
      </MotionReveal>
    </SectionShell>
  );
}
