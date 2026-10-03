// Copy for /changelog. The releases themselves are read from GitHub at build time.

export const changelogHero = {
  eyebrow: "Changelog",
  title: "What's new",
  intro: "What changed in each release of Tinycast, and who contributed.",
} as const;

export const changelogCopy = {
  description: "What changed in each Tinycast release, and who contributed.",
  jumpTo: "Versions",
  latest: "Latest",
  releaseNotes: "View on GitHub",
  compare: "View diff",
  showMore: (count: number) => `Show ${count} more`,
  contributors: (count: number) =>
    `Thanks to ${count} ${count === 1 ? "contributor" : "contributors"}`,
  earlier: {
    title: "Earlier releases",
    body: "These releases came before release notes. Each one links to its download.",
  },
  unavailable: {
    title: "Changelog unavailable",
    body: "GitHub didn't respond when this page was built. You can still find every release on GitHub.",
  },
  allReleases: "All releases on GitHub",
  install: "Get Tinycast",
} as const;
