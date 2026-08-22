import { Check } from "lucide-react";
import Image from "next/image";
import { migration } from "../data/migration";
import { asset } from "../lib/asset";
import { Button } from "./ui/button";
import { Reveal } from "./ui/reveal";

// Deliberately not a <Section>: the copy is left-aligned against the shot,
// and this reads as a practical note rather than a headline band.
export function Switch() {
  return (
    <section id="switch" className="container-page py-16 md:py-24">
      <Reveal>
        <div className="grid items-center gap-10 rounded-2xl bg-surface/40 p-6 shadow-key sm:p-10 lg:grid-cols-2 lg:gap-14">
          <div>
            <p className="font-mono text-eyebrow uppercase text-violet-bright">
              {migration.eyebrow}
            </p>
            <h2 className="mt-4 text-heading">{migration.title}</h2>
            <p className="mt-4 text-body text-fg-muted">{migration.intro}</p>

            <ol className="mt-7 flex flex-col gap-4">
              {migration.steps.map((step, i) => (
                <li key={step.title} className="flex gap-3">
                  <span
                    aria-hidden="true"
                    className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-violet/15 font-mono text-caption text-violet-bright"
                  >
                    {i + 1}
                  </span>
                  <span>
                    <span className="block text-body font-medium text-fg">
                      {step.title}
                    </span>
                    <span className="block text-body text-fg-muted">
                      {step.body}
                    </span>
                  </span>
                </li>
              ))}
            </ol>

            <p className="mt-7 font-mono text-eyebrow uppercase text-fg-subtle">
              Comes across
            </p>
            <ul className="mt-3 flex flex-wrap gap-2">
              {migration.transfers.map((item) => (
                <li
                  key={item}
                  className="inline-flex items-center gap-1.5 rounded-lg bg-tint/5 px-2.5 py-1.5 text-small text-fg-muted shadow-keycap"
                >
                  <Check
                    size={12}
                    strokeWidth={2.4}
                    className="text-violet-bright"
                  />
                  {item}
                </li>
              ))}
            </ul>

            <Button
              href="/docs/reference/import-from-raycast"
              variant="ghost"
              size="sm"
              className="mt-7"
            >
              Read the import guide
            </Button>
          </div>

          <figure className="overflow-hidden rounded-xl shadow-window">
            <Image
              src={asset("import.png")}
              width={1800}
              height={1192}
              alt="Tinycast's Backup settings pane with a Raycast export selected and a list of categories to import."
              className="block h-auto w-full"
            />
          </figure>
        </div>
      </Reveal>
    </section>
  );
}
