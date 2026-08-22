"use client";

import { Play } from "lucide-react";
import dynamic from "next/dynamic";
import Image from "next/image";
import { useEffect, useState } from "react";
import type { Slide } from "yet-another-react-lightbox";
import { galleryItems, type GalleryItem } from "../data/gallery";
import { asset } from "../lib/asset";
import { Reveal } from "./ui/reveal";
import { Section } from "./ui/section";

// The lightbox is ~30 KB gzipped and does nothing until a tile is clicked.
const GalleryLightbox = dynamic(() => import("./gallery-lightbox"));

// The grid thumbnail: an explicit thumb, else a video's poster, else the image.
// `unoptimized` images keep their src verbatim, so `basePath` has to be added
// here — next/image only prefixes it when the optimizer is in play.
const tileImage = (item: GalleryItem) =>
  asset(
    item.thumb ??
      (item.type === "video" ? (item.poster ?? item.src) : item.src),
  );

// One gallery item → one lightbox slide. Images carry title/description for the
// Captions plugin; videos use the Video plugin's `sources` shape.
function toSlide(item: GalleryItem): Slide {
  if (item.type === "video") {
    return {
      type: "video",
      poster: item.poster ? asset(item.poster) : undefined,
      width: item.width,
      height: item.height,
      title: item.title,
      description: item.caption,
      sources: [{ src: asset(item.src), type: "video/mp4" }],
    };
  }
  return {
    src: asset(item.src),
    title: item.title,
    description: item.caption,
    width: item.width,
    height: item.height,
  };
}

export function Gallery() {
  const [index, setIndex] = useState(-1);
  // Once opened, keep it mounted so closing and reopening costs no fetch.
  const [everOpened, setEverOpened] = useState(false);

  function open(i: number) {
    setEverOpened(true);
    setIndex(i);
  }

  // Lock scroll ourselves instead of via the lightbox's own module: it pads the
  // scrollbar width onto <body> and every fixed element (the scroll-top button
  // included, shifting its arrow). `scrollbar-gutter: stable` already reserves
  // that space, so a plain overflow:hidden lock changes no widths — no shift.
  useEffect(() => {
    if (index < 0) return;
    const html = document.documentElement;
    const previous = html.style.overflow;
    html.style.overflow = "hidden";
    return () => {
      html.style.overflow = previous;
    };
  }, [index]);

  return (
    <Section
      id="gallery"
      eyebrow="Tinycast in action"
      title="See it in motion."
      intro="A palette that stays out of your way — until you need it."
    >
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {galleryItems.map((item, i) => (
          <Reveal key={`${item.title}-${i}`} delay={i * 60}>
            <button
              type="button"
              onClick={() => open(i)}
              className="group flex h-full w-full flex-col gap-3 rounded-2xl bg-surface/40 p-3 text-left shadow-key transition-shadow duration-200 hover:shadow-key-hover"
            >
              <figure className="relative aspect-video w-full overflow-hidden rounded-xl">
                <Image
                  src={tileImage(item)}
                  alt={item.title}
                  fill
                  sizes="(min-width: 1024px) 30vw, (min-width: 640px) 45vw, 90vw"
                  className="object-cover transition-transform duration-300 group-hover:scale-[1.02]"
                />
                {item.type === "video" && (
                  <span className="absolute inset-0 flex items-center justify-center">
                    <span className="flex size-12 items-center justify-center rounded-full bg-black/40 text-white shadow-highlight backdrop-blur-sm">
                      <Play size={20} fill="currentColor" />
                    </span>
                  </span>
                )}
              </figure>
              <div className="px-1 pb-1">
                <h3 className="text-body-lg font-medium text-fg">
                  {item.title}
                </h3>
                <p className="mt-1 text-body text-fg-muted">{item.caption}</p>
              </div>
            </button>
          </Reveal>
        ))}
      </div>

      {everOpened && (
        <GalleryLightbox
          index={index}
          slides={galleryItems.map(toSlide)}
          close={() => setIndex(-1)}
        />
      )}
    </Section>
  );
}
