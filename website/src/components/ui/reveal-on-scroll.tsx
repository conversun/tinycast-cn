"use client";

import { useEffect } from "react";

/**
 * Plays each `[data-reveal]` element once, as it scrolls into view. Nothing is
 * hidden until this runs, so the page reads in full without JavaScript.
 */
export function RevealOnScroll() {
  useEffect(() => {
    const root = document.documentElement;
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          entry.target.setAttribute("data-revealed", "");
          observer.unobserve(entry.target);
        }
      },
      { rootMargin: "0px 0px -10% 0px" },
    );
    for (const element of document.querySelectorAll("[data-reveal]")) {
      observer.observe(element);
    }
    root.setAttribute("data-reveal-ready", "");

    return () => {
      observer.disconnect();
      root.removeAttribute("data-reveal-ready");
    };
  }, []);

  return null;
}
