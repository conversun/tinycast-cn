import { defineConfig, defineDocs } from "fumadocs-mdx/config";
import rehypeRaw from "rehype-raw";

// The node types fumadocs adds to the tree, which rehype-raw must not touch.
const MDX_NODES = [
  "mdxjsEsm",
  "mdxFlowExpression",
  "mdxTextExpression",
  "mdxJsxFlowElement",
  "mdxJsxTextElement",
];

export const docs = defineDocs({
  dir: "content/docs",
});

export default defineConfig({
  mdxOptions: {
    // The docs are plain Markdown, where inline HTML is dropped by default —
    // which silently swallowed every <kbd> in the shortcut tables. Parsing it
    // back into the tree is what lets the component map style those keys.
    rehypePlugins: (plugins) => [
      // `passThrough` is required: fumadocs injects MDX nodes into the tree,
      // and rehype-raw refuses to compile them unless told to leave them be.
      [rehypeRaw, { passThrough: MDX_NODES }],
      ...plugins,
    ],
    rehypeCodeOptions: {
      // Only the languages the docs actually use. Every extra grammar is dead
      // weight in the build, and highlighting runs here, never in the browser.
      langs: ["bash", "json", "markdown"],
      themes: { light: "github-light", dark: "github-dark" },
    },
  },
});
