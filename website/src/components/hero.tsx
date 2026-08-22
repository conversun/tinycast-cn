import { hero, site } from "../data/site";
import { AppShot } from "./app-shot";
import { Button } from "./ui/button";
import { AppleLogo, GitHubLogo } from "./ui/icon";
import { MetaStrip } from "./ui/meta-strip";

// The one place the system breaks its own austerity: a soft violet/cyan
// atmospheric wash borrowed from the app icon, then the page goes quiet.
// The glow styles live in index.css so they derive from the color tokens.
function Atmosphere() {
  return (
    <div
      className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
      aria-hidden="true"
    >
      <div className="hero-glow-violet" />
      <div className="hero-glow-cyan" />
      <div className="hero-fade" />
    </div>
  );
}

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden pb-8 pt-36 md:pt-48">
      <Atmosphere />
      <div className="container-page flex flex-col items-center text-center">
        <p
          className="rise font-mono text-eyebrow uppercase text-fg-muted"
          style={{ animationDelay: "0ms" }}
        >
          {hero.eyebrow}
        </p>

        <h1
          className="rise mt-6 max-w-3xl text-display"
          style={{ animationDelay: "80ms" }}
        >
          {hero.headline}
        </h1>

        <p
          className="rise mt-6 max-w-lg text-body-lg text-fg-muted"
          style={{ animationDelay: "160ms" }}
        >
          {hero.sub}
        </p>

        <div
          className="rise mt-9 flex flex-wrap items-center justify-center gap-3"
          style={{ animationDelay: "240ms" }}
        >
          <Button href="/#install" className="gap-1">
            <AppleLogo size={20} />
            Download for Mac
          </Button>
          <Button
            href={site.repo}
            variant="ghost"
            target="_blank"
            rel="noreferrer"
          >
            <GitHubLogo size={20} />
            View source
          </Button>
        </div>

        <div className="rise mt-2" style={{ animationDelay: "300ms" }}>
          <MetaStrip />
        </div>

        <div
          className="rise mt-12 flex w-full flex-col items-center md:mt-16"
          style={{ animationDelay: "380ms" }}
        >
          <AppShot />
          {/* Tinycast ships no default shortcut — the user records one on first
              run — so this must not name a specific chord. */}
          <p className="mt-5 text-small text-fg-subtle">
            Pick a shortcut on first run, then summon it from anywhere.
          </p>
        </div>
      </div>
    </section>
  );
}
