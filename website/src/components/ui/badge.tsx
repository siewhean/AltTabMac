import type { ReactNode } from "react";

export function Badge({
  children,
  tone = "default",
}: {
  children: ReactNode;
  tone?: "default" | "success";
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-3 py-1 leading-none text-[11px] font-semibold uppercase tracking-[0.24em] ${
        tone === "success"
          ? "border-success/30 bg-success/10 text-success"
          : "border-white/10 bg-white/[0.04] text-muted"
      }`}
    >
      {children}
    </span>
  );
}
