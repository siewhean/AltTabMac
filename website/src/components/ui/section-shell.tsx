import type { ReactNode } from "react";

type SectionShellProps = {
  id?: string;
  eyebrow?: string;
  title?: string;
  description?: string;
  children: ReactNode;
  className?: string;
};

export function SectionShell({
  id,
  eyebrow,
  title,
  description,
  children,
  className = "",
}: SectionShellProps) {
  return (
    <section id={id} className={`relative px-5 py-20 sm:px-8 lg:px-10 ${className}`}>
      <div className="mx-auto max-w-[1200px]">
        {(eyebrow || title || description) && (
          <div className="mb-10 max-w-3xl">
            {eyebrow ? (
              <p className="mb-4 text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
                {eyebrow}
              </p>
            ) : null}
            {title ? (
              <h2 className="max-w-4xl text-balance text-3xl font-medium tracking-[-0.04em] text-text sm:text-4xl lg:text-[2.8rem]">
                {title}
              </h2>
            ) : null}
            {description ? (
              <p className="mt-4 max-w-2xl text-pretty text-base leading-7 text-muted sm:text-lg">
                {description}
              </p>
            ) : null}
          </div>
        )}
        {children}
      </div>
    </section>
  );
}

