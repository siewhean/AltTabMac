import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { faqItems } from "@/content/faq";

export function FaqSection() {
  return (
    <SectionShell
      id="faq"
      eyebrow="FAQ"
      title="Direct answers about CmdTab"
      description="Compatibility, window ordering, permissions, Spaces, trial terms, and support in one factual reference."
      className="pt-8"
    >
      <div className="divide-y divide-white/8 border-t border-white/8">
        {faqItems.map((item, index) => (
          <MotionReveal
            key={item.question}
            delay={index * 35}
            direction="up"
            className="border-b-0"
          >
            <details className="group py-6">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-left text-lg font-medium tracking-[-0.03em] text-text">
                <span>{item.question}</span>
                <span className="text-subdued transition-transform duration-200 group-open:rotate-45">
                  +
                </span>
              </summary>
              <p className="mt-4 max-w-3xl text-base leading-7 text-muted">{item.answer}</p>
            </details>
          </MotionReveal>
        ))}
      </div>
    </SectionShell>
  );
}
