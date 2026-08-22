import { loader } from "fumadocs-core/source";
import { docs } from "../../.source/server";

// `/docs` is the only doc tree; the marketing page owns everything above it.
export const source = loader({
  baseUrl: "/docs",
  source: docs.toFumadocsSource(),
});

/**
 * Every page's raw Markdown is emitted as `<page path>/index.md`.
 *
 * A static export writes one file per route, so a page that is also a folder —
 * `/docs/launcher`, which has children — cannot be a file and a directory at
 * the same path. Giving every page a leaf file removes the class of collision
 * rather than special-casing the pages that happen to have children today.
 */
export const MARKDOWN_LEAF = "index.md";
