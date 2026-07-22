import type { ReactNode } from "react";

import { Breadcrumbs, type BreadcrumbItem } from "@/components/seo/breadcrumbs";
import { MotionReveal } from "@/components/ui/motion-reveal";

type SectionShellProps = {
  id?: string;
  eyebrow?: string;
  title?: string;
  description?: string;
  children: ReactNode;
  className?: string;
  headingAs?: "h1" | "h2";
  breadcrumbs?: ReadonlyArray<BreadcrumbItem>;
};

export function SectionShell({
  id,
  eyebrow,
  title,
  description,
  children,
  className = "",
  headingAs = "h2",
  breadcrumbs,
}: SectionShellProps) {
  const Heading = headingAs;

  return (
    <section id={id} className={`relative px-5 py-14 sm:px-8 sm:py-16 lg:px-10 lg:py-20 ${className}`}>
      <div className="mx-auto max-w-[1200px]">
        {breadcrumbs?.length ? <Breadcrumbs items={breadcrumbs} /> : null}
        {(eyebrow || title || description) && (
          <MotionReveal className="mb-8 max-w-3xl sm:mb-10" direction="up">
            {eyebrow ? <p className="type-eyebrow mb-3 text-cyan sm:mb-4">{eyebrow}</p> : null}
            {title ? <Heading className="type-section-title max-w-4xl text-text">{title}</Heading> : null}
            {description ? (
              <p className="type-body mt-3 max-w-2xl text-pretty text-muted sm:mt-4 sm:text-[1.0625rem]">
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
