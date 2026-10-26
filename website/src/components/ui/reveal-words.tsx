import { Fragment, type CSSProperties } from "react";

/**
 * `text` split into words that rise in one after another, inside an element
 * revealed as `words`. Screen readers get the sentence whole. `start` continues
 * the stagger from an earlier run of words in the same element.
 */
export function RevealWords({ text, start = 0 }: { text: string; start?: number }) {
  return (
    <>
      <span className="sr-only">{text}</span>
      <span aria-hidden="true">
        {text.split(" ").map((word, index) => (
          <Fragment key={index}>
            {index > 0 && " "}
            <span
              className="reveal-word"
              style={{ "--w": start + index } as CSSProperties}
            >
              {word}
            </span>
          </Fragment>
        ))}
      </span>
    </>
  );
}
