import { proofPoints } from "@/content/home";

export function ProofSection() {
  return (
    <section className="border-y border-white/6 bg-white/[0.02] px-5 py-6 sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-[1200px] gap-4 md:grid-cols-2 xl:grid-cols-4">
        {proofPoints.map((point) => (
          <div
            key={point}
            className="flex items-start gap-3 rounded-full border border-white/6 bg-white/[0.03] px-4 py-3 text-sm text-muted"
          >
            <span className="mt-1 h-2.5 w-2.5 rounded-full bg-cyan" />
            <span>{point}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

