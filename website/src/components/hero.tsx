import { Play } from "lucide-react";
import { hero, site } from "../data/site";
import { latestVersion } from "../lib/version";
import { PaletteDemo } from "./palette-demo";
import { Button } from "./ui/button";
import { AppleLogo } from "./ui/icon";

export async function Hero() {
  const version = await latestVersion();

  return (
    <section id="top" className="relative overflow-hidden">
      <div
        aria-hidden="true"
        className="bg-dots pointer-events-none absolute inset-0"
      />
      <div className="relative px-5 pb-20 pt-16 sm:px-10 sm:pt-24">
        <div className="mx-auto max-w-4xl text-center">
          <p className="rise flex flex-wrap items-center justify-center gap-x-2.5 gap-y-1 font-mono text-micro uppercase text-fg-muted">
            <span
              aria-hidden="true"
              className="size-1.5 rounded-full bg-violet"
            />
            <span>{version}</span>
            <span aria-hidden="true" className="text-border">
              /
            </span>
            <span>{site.platform} · Apple silicon & Intel</span>
          </p>

          <h1
            className="rise mt-6 text-display"
            style={{ animationDelay: "60ms" }}
          >
            {hero.headlineLines.map((line) => (
              <span key={line} className="block">
                {line}
              </span>
            ))}
          </h1>

          <p
            className="rise mx-auto mt-6 max-w-xl text-pretty text-body-lg text-fg-muted sm:text-subheading"
            style={{ animationDelay: "120ms" }}
          >
            {hero.sub}
          </p>

          <div
            className="rise mt-8 flex flex-wrap items-center justify-center gap-3"
            style={{ animationDelay: "180ms" }}
          >
            <Button href="/#install" size="lg">
              <AppleLogo size={16} />
              Download for Mac
            </Button>
            <Button href="/#gallery" variant="ghost" size="lg" className="px-4">
              <span className="grid size-6 place-items-center rounded-full border border-border bg-canvas">
                <Play size={12} className="translate-x-px" />
              </span>
              See it in action
            </Button>
          </div>

          <p
            className="rise mt-5 font-mono text-micro uppercase text-fg-muted/80"
            style={{ animationDelay: "240ms" }}
          >
            {hero.facts.join(" · ")}
          </p>
        </div>

        <div className="mx-auto mt-16 max-w-5xl sm:mt-24">
          <PaletteDemo />
        </div>
      </div>
    </section>
  );
}
