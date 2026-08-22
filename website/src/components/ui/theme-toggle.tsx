"use client";

import { Monitor, Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useSyncExternalStore } from "react";
import { cn } from "../../lib/cn";

// The same three choices the app's Appearance setting offers, in the same
// order, so the site and Settings › General read as one product.
const options = [
  { value: "system", label: "System", Icon: Monitor },
  { value: "light", label: "Light", Icon: Sun },
  { value: "dark", label: "Dark", Icon: Moon },
] as const;

const noop = () => () => {};

export function ThemeToggle({ className }: { className?: string }) {
  const { theme, setTheme } = useTheme();
  // The server can't know the stored choice, so the selected state only appears
  // after hydration — otherwise it renders against the wrong option and flips.
  const mounted = useSyncExternalStore(
    noop,
    () => true,
    () => false,
  );

  return (
    <div
      className={cn(
        "inline-flex items-center gap-0.5 rounded-lg border border-border p-0.5",
        className,
      )}
      role="radiogroup"
      aria-label="Appearance"
    >
      {options.map(({ value, label, Icon }) => {
        const active = mounted && theme === value;
        return (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={active}
            aria-label={label}
            title={label}
            onClick={() => setTheme(value)}
            className={cn(
              "flex size-7 items-center justify-center rounded-md transition-colors",
              active
                ? "bg-tint/8 text-fg"
                : "text-fg-subtle hover:bg-tint/5 hover:text-fg",
            )}
          >
            <Icon size={15} strokeWidth={1.9} />
          </button>
        );
      })}
    </div>
  );
}
