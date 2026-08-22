import { ArrowUpRight } from "lucide-react";
import Link from "next/link";
import { features } from "../data/features";
import type { Feature } from "../data/features";
import { featureIcons } from "./ui/feature-icons";
import { Reveal } from "./ui/reveal";
import { Section } from "./ui/section";

function FeatureCard({ icon, title, body, href }: Feature) {
  const Icon = featureIcons[icon];
  return (
    <Link
      href={href}
      className="group flex h-full flex-col gap-4 rounded-2xl bg-surface/40 p-4 shadow-key transition-shadow duration-200 hover:shadow-key-hover sm:p-6"
    >
      <span className="flex size-11 items-center justify-center rounded-full bg-tint/5 text-violet-bright shadow-highlight transition-colors group-hover:bg-violet/10">
        <Icon size={22} strokeWidth={1.6} />
      </span>
      <h3 className="flex items-center gap-1.5 text-subheading font-medium text-fg">
        {title}
        <ArrowUpRight
          size={16}
          strokeWidth={2}
          aria-hidden="true"
          className="text-fg-subtle opacity-0 transition-opacity group-hover:opacity-100"
        />
      </h3>
      <p className="text-body text-fg-muted">{body}</p>
    </Link>
  );
}

export function Features() {
  return (
    <Section
      id="features"
      eyebrow="What it does"
      title="Everything you reach for, one keystroke away."
      intro="One palette, and everything in it is off until you ask for it. Every card links to its documentation."
    >
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {features.map((feature, i) => (
          <Reveal
            key={feature.title}
            delay={Math.min(i, 6) * 60}
            className={feature.wide ? "sm:col-span-2" : undefined}
          >
            <FeatureCard {...feature} />
          </Reveal>
        ))}
      </div>
    </Section>
  );
}
