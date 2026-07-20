import type { ReactNode } from "react";

import { MotionReveal } from "@/components/ui/motion-reveal";

type SectionShellProps = {
  id?: string;
  eyebrow?: string;
  title?: string;
  description?: string;
  children: ReactNode;
  className?: string;
  headingAs?: "h1" | "h2";
};

export function SectionShell({
  id,
  eyebrow,
  title,
  description,
  children,
  className = "",
  headingAs = "h2",
}: SectionShellProps) {
  const Heading = headingAs;

  return (
    <section id={id} className={`relative px-5 py-20 sm:px-8 lg:px-10 ${className}`}>
      <div className="mx-auto max-w-[1200px]">
        {(eyebrow || title || description) && (
          <MotionReveal className="mb-10 max-w-3xl" direction="up">
            {eyebrow ? <p className="type-eyebrow mb-4 text-cyan">{eyebrow}</p> : null}
            {title ? (
              <Heading className="type-section-title max-w-4xl text-text">
                {title}
              </Heading>
            ) : null}
            {description ? (
              <p className="type-body mt-4 max-w-2xl text-pretty text-muted sm:text-[1.0625rem]">
                {description}
              </p>
            ) : null}
          </MotionReveal>
        )}
        {children}
      </div>
    </section>
  );
}
