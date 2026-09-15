import { Check } from "lucide-react";
import Image from "next/image";
import { migration } from "../data/migration";
import { asset } from "../lib/asset";
import { Button } from "./ui/button";
import { Section } from "./ui/section";

export function Switch() {
  return (
    <Section
      id="switch"
      index={5}
      label="Moving over"
      title={migration.title}
      intro={migration.intro}
    >
      <div className="bg-brand-gradient rounded-2xl p-4 sm:p-12">
        <div className="mx-auto max-w-3xl overflow-hidden rounded-xl shadow-palette">
          <Image
            src={asset("import.png")}
            width={1800}
            height={1192}
            alt="Tinycast's Backup settings pane with a Raycast export selected and a list of categories to import."
            className="block h-auto w-full"
          />
        </div>
      </div>

      {/* A real sequence, so these carry numbers. */}
      <ol className="mt-4 grid gap-4 md:grid-cols-3">
        {migration.steps.map((step, i) => (
          <li key={step.title} className="rounded-2xl bg-tint/4 p-5 sm:p-6">
            <span
              aria-hidden="true"
              className="flex size-7 items-center justify-center rounded-full bg-violet/15 text-small font-semibold text-violet-bright"
            >
              {i + 1}
            </span>
            <h3 className="mt-4 text-body font-medium text-fg">{step.title}</h3>
            <p className="mt-1.5 text-small text-fg-muted">{step.body}</p>
          </li>
        ))}
      </ol>

      <div className="mt-4 rounded-2xl bg-tint/4 p-5 sm:p-6">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <h3 className="text-body font-medium text-fg">What comes across</h3>
          <Button href="/docs/reference/import-from-raycast" variant="outline">
            Read the import guide
          </Button>
        </div>
        <ul className="mt-4 flex flex-wrap gap-2">
          {migration.transfers.map((item) => (
            <li
              key={item}
              className="inline-flex items-center gap-1.5 rounded-full bg-canvas px-3 py-1.5 text-small text-fg-muted"
            >
              <Check
                size={13}
                strokeWidth={2.4}
                className="text-violet-bright"
                aria-hidden="true"
              />
              {item}
            </li>
          ))}
        </ul>
      </div>
    </Section>
  );
}
