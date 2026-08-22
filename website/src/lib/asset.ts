// `basePath` prefixes next/link and next/image on its own, but not a raw URL
// string — the lightbox takes plain hrefs, so those have to prefix themselves.
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

/** Resolve a file in `public/` to a URL that works under the deployed subpath. */
export function asset(name: string): string {
  return `${basePath}/${name.replace(/^\//, "")}`;
}
