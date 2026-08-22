import { createMDX } from "fumadocs-mdx/next";

const withMDX = createMDX();

// The site lives at abue-ammar.github.io/tinycast, not at a domain root.
// Exported to the client too, because `basePath` only auto-prefixes next/link
// and next/image — a raw URL handed to the lightbox has to prefix itself.
const basePath = "/tinycast";

/** @type {import('next').NextConfig} */
const config = {
  // GitHub Pages serves plain files — there is no Node process behind this site.
  output: "export",
  basePath,
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
  // The Image Optimization API needs a server, which an export does not have.
  images: { unoptimized: true },
  // Emits /docs/palette/index.html, the only shape a static host can serve.
  trailingSlash: true,
  reactCompiler: true,
};

export default withMDX(config);
