import { site } from "../data/site";

// Resolve the API URL from the repo link, so there's still a single source of
// truth (site.repo) rather than a second hardcoded slug.
const match = site.repo.match(/github\.com\/([^/]+)\/([^/]+)/);
export const repoApiUrl = match
  ? `https://api.github.com/repos/${match[1]}/${match[2]}`
  : null;

/**
 * Read one GitHub API resource at build time. CI passes its token, because an
 * anonymous build shares 60 requests an hour with whatever else is on the
 * runner's IP; a local build without one still works.
 */
export async function readRepoJson(url: string): Promise<unknown> {
  const token = process.env.GITHUB_TOKEN;
  const res = await fetch(url, {
    headers: {
      Accept: "application/vnd.github+json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!res.ok) throw new Error(`GitHub API ${res.status}`);
  return res.json();
}
