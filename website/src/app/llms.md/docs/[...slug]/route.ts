import { notFound } from "next/navigation";
import { getLLMText } from "../../../../lib/get-llm-text";
import { MARKDOWN_LEAF, source } from "../../../../lib/source";

// Serves each page as raw Markdown, for the Copy Markdown button and for AI
// agents. Static, like everything else here — files are written at export time.
export const dynamic = "force-static";
export const revalidate = false;

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ slug: string[] }> },
) {
  const { slug } = await params;
  const page = source.getPage(slug.slice(0, -1));
  if (!page) notFound();

  return new Response(await getLLMText(page), {
    headers: { "Content-Type": "text/markdown; charset=utf-8" },
  });
}

export function generateStaticParams() {
  return source
    .generateParams()
    .map(({ slug }) => ({ slug: [...(slug ?? []), MARKDOWN_LEAF] }));
}
