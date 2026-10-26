import type { CSSProperties } from "react";

/**
 * How a block enters when it scrolls into view: `text` rises out of a blur,
 * `words` does the same one word at a time (pair it with `RevealWords`), and
 * `content` rises without the blur, which is too costly over images and cards.
 */
export type RevealKind = "text" | "words" | "content";

/** Spread onto an element to reveal it; `order` staggers it after its siblings. */
export function reveal(kind: RevealKind, order = 0) {
  return {
    "data-reveal": kind,
    style: { "--i": order } as CSSProperties,
  };
}
