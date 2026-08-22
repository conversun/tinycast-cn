import type { ComponentProps } from "react";
import { cn } from "../../lib/cn";

/**
 * A keyboard key or chord.
 *
 * `not-prose` is the typography plugin's own opt-out. Without it the prose
 * theme puts a border and a fixed 13px font-size on `kbd`, and every override
 * fights that rule instead of replacing it.
 *
 * All of the styling lives in the `.tc-key` rule in index.css.
 */
export function Kbd({ className, ...props }: ComponentProps<"kbd">) {
  return <kbd className={cn("not-prose tc-key", className)} {...props} />;
}
