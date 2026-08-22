"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { cn } from "../../lib/cn";

type RevealProps = {
  children: ReactNode;
  className?: string;
  /** Transition delay in ms — stagger siblings by passing multiples. */
  delay?: number;
};

// Scroll-triggered rise: content sits hidden until it scrolls into view, then
// eases up once. The visual states live in index.css (.reveal / .reveal-shown)
// so they respect prefers-reduced-motion with the rest of the motion system.
export function Reveal({ children, className, delay = 0 }: RevealProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setShown(true);
          io.disconnect();
        }
      },
      { rootMargin: "0px 0px -10% 0px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return (
    <div
      ref={ref}
      className={cn("reveal", shown && "reveal-shown", className)}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </div>
  );
}
