import Image from "next/image";

import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { siteConfig } from "@/content/site";

export function FooterSection() {
  return (
    <footer className="border-t border-white/8 px-5 py-10 sm:px-8 lg:px-10">
      <div className="mx-auto flex max-w-[1200px] flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
        <MotionReveal className="space-y-4" direction="left">
          <div className="flex items-center gap-3">
            <Image
              src="/brand/cmdtab.png"
              alt="CmdTab app icon"
              width={40}
              height={40}
              className="rounded-[12px]"
            />
            <div>
              <p className="text-lg font-medium tracking-[-0.03em] text-text">CmdTab</p>
              <p className="text-sm text-subdued">
                Better window switching for people who live in too many apps.
              </p>
            </div>
          </div>
          <p className="max-w-xl text-sm leading-7 text-subdued">
            CmdTab is in active beta. Review the trial, buy once if it sticks, and use Help if you need support later.
          </p>
        </MotionReveal>

        <MotionReveal className="flex flex-col gap-3 sm:flex-row sm:items-center" direction="right" delay={100}>
          <Button href="/trial">{siteConfig.ctas.primary}</Button>
          <Button href="/buy" variant="secondary">
            Buy and trial
          </Button>
          <Button href="/help" variant="ghost">
            Help
          </Button>
          <Button href="/privacy" variant="ghost">
            {siteConfig.ctas.tertiary}
          </Button>
        </MotionReveal>
      </div>
    </footer>
  );
}
