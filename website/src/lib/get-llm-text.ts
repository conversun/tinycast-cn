import type { InferPageType } from "fumadocs-core/source";
import type { source } from "./source";

// `getText("raw")` hands back the file verbatim, frontmatter included. The
// title and description are restated as prose below, so strip the block rather
// than shipping both.
const FRONTMATTER = /^---\r?\n[\s\S]*?\r?\n---\r?\n?/;

/** The page as plain Markdown — what "Copy Markdown" and AI agents receive. */
export async function getLLMText(page: InferPageType<typeof source>) {
  const body = (await page.data.getText("raw")).replace(FRONTMATTER, "").trim();
  const description = page.data.description
    ? `\n\n> ${page.data.description}`
    : "";

  return `# ${page.data.title}${description}\n\n${body}\n`;
}
