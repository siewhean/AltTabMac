import { MotionReveal } from "@/components/ui/motion-reveal";
import { ScreenshotFrame } from "@/components/ui/screenshot-frame";
import { SectionShell } from "@/components/ui/section-shell";
import { permissionsContent } from "@/content/home";

export function PermissionsSection() {
  return (
    <SectionShell
      eyebrow={permissionsContent.eyebrow}
      title={permissionsContent.title}
      description={permissionsContent.summary}
    >
      <div className="grid items-center gap-8 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
        <MotionReveal className="space-y-4" direction="left">
          {permissionsContent.notes.map((note, index) => (
            <MotionReveal
              key={note}
              delay={index * 70}
              direction="up"
              className="flex items-start gap-3 border-t border-white/8 py-4 text-base leading-7 text-muted"
            >
              <span className="mt-2 h-2.5 w-2.5 rounded-full bg-cyan" />
              <span>{note}</span>
            </MotionReveal>
          ))}
        </MotionReveal>
        <MotionReveal direction="right" delay={120}>
          <ScreenshotFrame assetId={permissionsContent.screenshotId as never} />
        </MotionReveal>
      </div>
    </SectionShell>
  );
}
