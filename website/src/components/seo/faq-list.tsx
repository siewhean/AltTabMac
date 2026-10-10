import { MotionReveal } from "@/components/ui/motion-reveal";

export function FaqList({
  items,
}: {
  items: ReadonlyArray<{ question: string; answer: string }>;
}) {
  return (
    <div className="divide-y divide-white/8 border-t border-white/8">
      {items.map((item, index) => (
        <MotionReveal
          key={item.question}
          delay={index * 30}
          direction="up"
        >
          <details className="group py-6">
            <summary className="flex min-h-11 cursor-pointer list-none items-center justify-between gap-4 text-left text-lg font-medium tracking-[-0.03em] text-text [&::-webkit-details-marker]:hidden">
              <span>{item.question}</span>
              <span
                aria-hidden="true"
                className="text-subdued transition-transform duration-200 group-open:rotate-45"
              >
                +
              </span>
            </summary>
            <p className="mt-4 max-w-3xl text-base leading-7 text-muted">{item.answer}</p>
          </details>
        </MotionReveal>
      ))}
    </div>
  );
}
