"use client";

import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from "react";

/** How long each word holds before the next one swaps in. */
const HOLD_MS = 2200;

/**
 * Swaps through `words` letter by letter, once, and settles back on the first.
 * Purely visual: the caller supplies the accessible text. Reduced motion keeps
 * the first word.
 */
export function SwapWords({ words }: { words: readonly string[] }) {
  const [{ current, previous }, setShown] = useState({ current: 0, previous: -1 });
  const host = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let step = 0;
    const timer = setInterval(() => {
      step += 1;
      const next = step % words.length;
      setShown((shown) => ({ current: next, previous: shown.current }));
      if (next === 0) clearInterval(timer);
    }, HOLD_MS);
    return () => clearInterval(timer);
  }, [words.length]);

  // A pixel width lets the line glide between words; clearing it falls back to
  // the shown word's width, since hidden words are zero wide.
  useLayoutEffect(() => {
    const element = host.current;
    if (!element) return;
    const refit = () => {
      element.style.width = "";
      element.style.width = `${element.offsetWidth}px`;
    };
    refit();
    document.fonts.ready.then(refit);
    addEventListener("resize", refit);
    return () => removeEventListener("resize", refit);
  }, []);

  useLayoutEffect(() => {
    const element = host.current;
    const shown = element?.children[current];
    if (!element || previous < 0 || !(shown instanceof HTMLElement)) return;
    element.style.width = `${shown.offsetWidth}px`;
  }, [current, previous]);

  return (
    <span ref={host} className="swap-words">
      {words.map((word, index) => (
        <span
          key={word}
          className="swap-word"
          data-state={
            index === current ? "in" : index === previous ? "out" : undefined
          }
        >
          {Array.from(word, (char, position) => (
            <span key={position} style={{ "--c": position } as CSSProperties}>
              {char}
            </span>
          ))}
        </span>
      ))}
    </span>
  );
}
