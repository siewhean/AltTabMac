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
    "border border-accent/50 bg-accent text-slate-950 shadow-halo hover:bg-cyan hover:border-cyan",
  secondary:
    "border border-white/12 bg-white/6 text-text hover:border-white/22 hover:bg-white/10",
  ghost:
    "border border-transparent bg-transparent text-muted hover:text-text",
} as const;

const baseClassName =
  "inline-flex min-h-11 items-center justify-center gap-2 rounded-full px-5 py-3 text-sm font-medium tracking-[-0.01em] transition-[transform,background-color,border-color,color,opacity] duration-200 ease-[cubic-bezier(0.23,1,0.32,1)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60 focus-visible:ring-offset-2 focus-visible:ring-offset-ink active:scale-[0.97]";

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
