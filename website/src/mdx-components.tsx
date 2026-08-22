import defaultComponents from "fumadocs-ui/mdx";
import type { MDXComponents } from "mdx/types";
import { Kbd } from "./components/ui/kbd";

// `Kbd` is the same keycap the marketing page uses, so a shortcut looks
// identical wherever it appears. Markdown reaches it through <kbd>.
export function getMDXComponents(components?: MDXComponents): MDXComponents {
  return {
    ...defaultComponents,
    kbd: Kbd,
    ...components,
  };
}
