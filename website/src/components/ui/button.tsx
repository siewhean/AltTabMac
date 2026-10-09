import type {
  AnchorHTMLAttributes,
  ButtonHTMLAttributes,
  ReactNode,
  ReactElement,
} from "react";

type SharedProps = {
  children: ReactNode;
  className?: string;
  variant?: "primary" | "secondary" | "ghost";
};

type LinkButtonProps = SharedProps &
  AnchorHTMLAttributes<HTMLAnchorElement> & {
    href: string;
  };

type NativeButtonProps = SharedProps & ButtonHTMLAttributes<HTMLButtonElement>;

const variants = {
  primary:
    "border border-accent/45 bg-accent text-slate-950 hover:-translate-y-0.5 hover:border-cyan/80 hover:bg-cyan",
  secondary:
    "border border-white/12 bg-white/[0.05] text-text hover:-translate-y-0.5 hover:border-white/18 hover:bg-white/[0.08]",
  ghost:
    "border border-transparent bg-transparent text-muted hover:text-text",
} as const;

const baseClassName =
  "inline-flex min-h-12 items-center justify-center gap-2 whitespace-nowrap rounded-full px-6 py-3 text-[0.9375rem] font-medium tracking-[-0.01em] transition-[transform,background-color,border-color,color,opacity] duration-200 ease-[cubic-bezier(0.22,1,0.36,1)] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-accent/60 focus-visible:ring-offset-2 focus-visible:ring-offset-ink active:translate-y-px disabled:cursor-not-allowed disabled:opacity-60";

export function Button(props: LinkButtonProps): ReactElement;
export function Button(props: NativeButtonProps): ReactElement;
export function Button(props: LinkButtonProps | NativeButtonProps) {
  if ("href" in props) {
    const { children, className = "", variant = "primary", href, ...anchorProps } = props;
    const composedClassName = `${baseClassName} ${variants[variant]} ${className}`;
    return (
      <a {...anchorProps} href={href} className={composedClassName}>
        {children}
      </a>
    );
  }

  const {
    children,
    className = "",
    variant = "primary",
    type = "button",
    ...buttonProps
  } = props;
  const composedClassName = `${baseClassName} ${variants[variant]} ${className}`;

  return (
    <button {...buttonProps} type={type} className={composedClassName}>
      {children}
    </button>
  );
}
