import { site } from "../data/site";

// Resolve the releases API URL from the repo link, so there's still a single
// source of truth (site.repo) rather than a second hardcoded slug.
const match = site.repo.match(/github\.com\/([^/]+)\/([^/]+)/);
const apiUrl = match
  ? `https://api.github.com/repos/${match[1]}/${match[2]}/releases/latest`
  : null;

/**
 * The latest published release tag, read once at build time and baked into the
 * HTML. Doing this on the server rather than in the browser keeps the number
 * honest: an unauthenticated client fetch is rate-limited at 60/hr per IP, so
 * the old client-side version of this showed a stale fallback most of the time.
 */
export async function latestVersion(): Promise<string> {
  if (!apiUrl) return site.fallbackVersion;
  try {
    const res = await fetch(apiUrl, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) throw new Error(`GitHub API ${res.status}`);
    const data: unknown = await res.json();
    const tag =
      data && typeof data === "object" && "tag_name" in data
        ? String((data as { tag_name: unknown }).tag_name)
        : "";
    return tag || site.fallbackVersion;
  } catch {
    // A build must not fail because GitHub is unreachable or rate-limiting.
    return site.fallbackVersion;
  }
}
