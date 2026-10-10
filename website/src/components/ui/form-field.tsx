import type { InputHTMLAttributes } from "react";

type FormFieldProps = {
  label: string;
  error?: string;
} & InputHTMLAttributes<HTMLInputElement>;

export function FormField({ label, error, id, className = "", ...props }: FormFieldProps) {
  return (
    <label className="block" htmlFor={id}>
      <span className="mb-2 block text-sm font-medium text-text">{label}</span>
      <input
        id={id}
        className={`min-h-12 w-full rounded-2xl border border-white/10 bg-white/5 px-4 text-sm text-text placeholder:text-subdued transition-[border-color,background-color,transform] duration-200 ease-[cubic-bezier(0.23,1,0.32,1)] focus:border-accent/50 focus:bg-white/8 focus:outline-hidden focus:ring-2 focus:ring-accent/20 active:scale-[0.995] ${className}`}
        {...props}
      />
      {error ? <span className="mt-2 block text-sm text-rose-300">{error}</span> : null}
    </label>
  );
}

