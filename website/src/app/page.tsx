import { Ethos } from "../components/ethos";
import { Features } from "../components/features";
import { Footer } from "../components/footer";
import { Gallery } from "../components/gallery";
import { Hero } from "../components/hero";
import { Install } from "../components/install";
import { Nav } from "../components/nav";
import { Switch } from "../components/switch";
import { ScrollTop } from "../components/ui/scroll-top";

export default function HomePage() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Gallery />
        <Features />
        <Ethos />
        <Switch />
        <Install />
      </main>
      <Footer />
      <ScrollTop />
    </>
  );
}
