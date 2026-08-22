import Image from "next/image";
import { asset } from "../lib/asset";

// The real Tinycast launcher, captured over the macOS desktop. Framed as a
// floating window so it reads as a product shot rather than a flat image.
// The source of record is docs/screenshot.png; public/screenshot.png is a copy.
export function AppShot() {
  return (
    <figure className="w-full overflow-hidden rounded-2xl shadow-window">
      <Image
        src={asset("screenshot.png")}
        width={2451}
        height={1510}
        alt="Tinycast's launcher floating over the macOS desktop, showing grouped Favorites and Applications with Ghostty selected and an Open Application action."
        className="block h-auto w-full"
        priority
      />
    </figure>
  );
}
