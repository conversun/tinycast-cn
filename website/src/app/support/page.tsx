import type { Metadata } from "next";
import { Footer } from "../../components/footer";
import { Nav } from "../../components/nav";
import { SupportFlow } from "../../components/support/support-flow";
import { SupporterCount } from "../../components/support/supporter-count";
import {
  reasonsLabel,
  runningCosts,
  supportHero,
  supportReasons,
} from "../../data/support";

const description =
  "Tinycast is free and open source. If you enjoy it, you can support its development monthly or once, securely through Polar.";

export const metadata: Metadata = {
  title: "Support",
  description,
  alternates: { canonical: "/support/" },
  openGraph: { title: "Support Tinycast", description, url: "/support/" },
};

function Intro() {
  return (
    <header>
      <p className="font-mono text-eyebrow uppercase text-violet-bright">
        {supportHero.eyebrow}
      </p>
      <h1 className="mt-4 text-display text-fg">{supportHero.title}</h1>
      <p className="mt-5 max-w-xl text-pretty text-body-lg text-fg-muted">
        {supportHero.intro}
      </p>
      <SupporterCount />
    </header>
  );
}

function Reasons() {
  return (
    <div>
      <p className="font-mono text-eyebrow uppercase text-fg-muted">
        {reasonsLabel}
      </p>
      <ul className="mt-4 divide-y divide-border border-y border-border">
        {supportReasons.map((reason) => (
          <li key={reason.title} className="py-5">
            <h2 className="text-body font-medium text-fg">{reason.title}</h2>
            <p className="mt-1 max-w-lg text-pretty text-small text-fg-muted">
              {reason.body}
            </p>
          </li>
        ))}
      </ul>
      <p className="mt-5 max-w-lg text-pretty text-small text-fg-subtle">
        {runningCosts}
      </p>
    </div>
  );
}

export default function SupportPage() {
  return (
    <>
      <Nav />
      <main className="mx-auto max-w-7xl px-4 pb-24 pt-12 sm:px-10 sm:pt-20">
        <SupportFlow intro={<Intro />} reasons={<Reasons />} />
      </main>
      <Footer />
    </>
  );
}
