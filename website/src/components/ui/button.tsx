import type { ComponentProps, ReactNode } from "react";
import { cn } from "../../lib/cn";
import { Link } from "./link";

type Variant = "primary" | "ghost" | "outline";
type Size = "sm" | "lg";

type ButtonProps = {
  children: ReactNode;
  href: string;
  variant?: Variant;
  size?: Size;
} & Omit<ComponentProps<typeof Link>, "href">;

const variants: Record<Variant, string> = {
  // The brand violet marks the one action that matters: getting the app.
  primary: "bg-violet text-white hover:bg-violet-deep",
  ghost: "text-fg-muted hover:bg-tint/5 hover:text-fg",
  outline:
    "border border-border text-fg-muted hover:border-border-strong hover:text-fg",
};

const sizes: Record<Size, string> = {
  sm: "h-7 gap-1 px-3.5 text-small",
  lg: "h-11 gap-2 px-6 text-body",
};

// A link styled as a button. Everything on this page is a link (download /
// anchor / repo), so an anchor is the honest element.
export function Button({
  children,
  href,
  variant = "primary",
  size = "sm",
  className,
  ...props
}: ButtonProps) {
  return (
    <Link
      href={href}
      className={cn(
        "inline-flex shrink-0 items-center justify-center whitespace-nowrap rounded-full font-medium transition-colors active:translate-y-px",
        variants[variant],
        sizes[size],
        className,
      )}
      {...props}
    >
      {children}
    </Link>
  );
}
