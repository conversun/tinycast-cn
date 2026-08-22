import { clsx, type ClassValue } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

// tailwind-merge must be taught the custom theme from index.css: without this
// it would classify `text-body` as a text *color* and wrongly drop it when
// merged with `text-white`, and it wouldn't dedupe the custom shadows.
const twMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      "font-size": [
        {
          text: [
            "eyebrow",
            "caption",
            "key",
            "small",
            "body",
            "body-lg",
            "subheading",
            "stat",
            "heading",
            "display",
          ],
        },
      ],
      shadow: [
        {
          shadow: ["key", "key-hover", "highlight", "keycap", "cta", "window"],
        },
      ],
    },
  },
});

// Compose class names with correct Tailwind override semantics: later classes
// win over earlier ones, so a `className` prop can actually override defaults.
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
