import { site } from "../../data/site";
import { latestVersion } from "../../lib/version";

// Version | platform | license — the mono metadata line used under the hero
// CTAs and in the footer, so the two never drift apart.
export async function MetaStrip() {
  const version = await latestVersion();

  return (
    <p className="flex flex-wrap items-center justify-center gap-x-2.5 gap-y-1 font-mono text-caption text-fg-subtle">
      <span>{version}</span>
      <span aria-hidden="true" className="text-fg-subtle/40">
        |
      </span>
      <span>{site.platform}</span>
      <span aria-hidden="true" className="text-fg-subtle/40">
        |
      </span>
      <a
        href={site.licenseUrl}
        target="_blank"
        rel="noreferrer"
        className="transition-colors hover:text-fg"
      >
        {site.license}
      </a>
    </p>
  );
}
