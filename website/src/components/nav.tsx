import { BookOpen } from "lucide-react";
import { nav, site } from "../data/site";
import { Button } from "./ui/button";
import { DiscordLogo, GitHubLogo, Logo } from "./ui/icon";
import { Link } from "./ui/link";

const iconButtonClass =
  "flex size-8 items-center justify-center rounded-full text-fg-muted transition-colors hover:bg-tint/5 hover:text-fg";

// A full-width bar that is see-through over the hero and turns to glass once
// the page scrolls. Phones get icons instead of a menu: the section links are
// a scroll away, and a drawer is one more thing to open.
export function Nav() {
  return (
    <header className="header-veil sticky top-0 z-50">
      <div className="mx-auto flex h-16 max-w-6xl items-center gap-6 px-5">
        <Link href="/" className="flex items-center gap-2">
          <Logo size={26} />
          <span className="text-body font-semibold tracking-tight text-fg">
            {site.name}
          </span>
        </Link>

        <nav
          aria-label="Sections"
          className="hidden items-center gap-0.5 md:flex"
        >
          {nav.map((item) => (
            <Link
              key={item.label}
              href={item.href}
              className="rounded-full px-3.5 py-1.5 text-small font-medium text-fg-muted transition-colors hover:bg-tint/5 hover:text-fg"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-1">
          <Link
            href="/docs"
            aria-label="Documentation"
            className={`${iconButtonClass} md:hidden`}
          >
            <BookOpen size={16} />
          </Link>
          <a
            href={site.repo}
            target="_blank"
            rel="noreferrer"
            aria-label="View source on GitHub"
            title="View source on GitHub"
            className={iconButtonClass}
          >
            <GitHubLogo size={16} />
          </a>
          <a
            href={site.community.discord}
            target="_blank"
            rel="noreferrer"
            aria-label="Join the Discord"
            title="Join the Discord"
            className={iconButtonClass}
          >
            <DiscordLogo size={16} />
          </a>
          <Button href="/#install" className="ml-2 h-8 px-4">
            Download
          </Button>
        </div>
      </div>
    </header>
  );
}
