"use client";

import { ArrowUp } from "lucide-react";
import { useEffect, useState } from "react";
import { cn } from "../../lib/cn";

// A floating "back to top" control that fades + rises into view once you've
// scrolled past the first screen, then eases away near the top. Chrome matches
// the nav (glass over the canvas, hairline border, keycap lift) so it reads as
// part of the same system. Motion respects prefers-reduced-motion.
export function ScrollTop() {
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const onScroll = () => setShown(window.scrollY > 600);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  function toTop() {
    const reduce = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
  }

  return (
    <button
      type="button"
      onClick={toTop}
      aria-label="Back to top"
      aria-hidden={!shown}
      tabIndex={shown ? 0 : -1}
      className={cn(
        "group fixed bottom-6 right-6 z-40 flex size-11 items-center justify-center rounded-full border border-border bg-canvas/60 text-fg-muted shadow-key backdrop-blur-2xl transition-all duration-300 ease-out hover:border-border-strong hover:text-fg hover:shadow-key-hover",
        shown
          ? "translate-y-0 scale-100 opacity-100"
          : "pointer-events-none translate-y-4 scale-90 opacity-0",
      )}
    >
      <ArrowUp
        size={19}
        strokeWidth={2}
        className="transition-transform duration-200 group-hover:-translate-y-0.5"
      />
    </button>
  );
}
