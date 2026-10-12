import type { Metadata } from "next";
import { Footer } from "../../components/footer";
import { Nav } from "../../components/nav";
import { SupportFlow } from "../../components/support/support-flow";
import { SupporterCount } from "../../components/support/supporter-count";
import { supportHero } from "../../data/support";

const description =
  "Enjoying Tinycast? Buy a premium wallpaper pack with an included Discord role. Tinycast remains free and open source.";

export const metadata: Metadata = {
  title: "Enjoying Tinycast?",
  description,
  alternates: { canonical: "/support/" },
  openGraph: { title: "Enjoying Tinycast?", description, url: "/support/" },
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

export default function SupportPage() {
  return (
    <div className="flex min-h-dvh flex-col">
      <Nav />
      <main className="mx-auto w-full max-w-7xl flex-1 px-4 pb-24 pt-12 sm:px-10 sm:pt-20">
        <SupportFlow intro={<Intro />} />
      </main>
      <Footer />
    </div>
  );
}
