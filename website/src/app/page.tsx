import { Features } from "../components/features";
import { Footer } from "../components/footer";
import { Gallery } from "../components/gallery";
import { Hero } from "../components/hero";
import { Install } from "../components/install";
import { Keyboard } from "../components/keyboard";
import { Nav } from "../components/nav";
import { Privacy } from "../components/privacy";
import { Support } from "../components/support";
import { Switch } from "../components/switch";
import { ScrollTop } from "../components/ui/scroll-top";

export default function HomePage() {
  return (
    <>
      <Nav />
      <main className="mx-auto max-w-6xl">
        <Hero />
        <Features />
        <Gallery />
        <Privacy />
        <Keyboard />
        <Switch />
        <Install />
        <Support />
      </main>
      <Footer />
      <ScrollTop />
    </>
  );
}
