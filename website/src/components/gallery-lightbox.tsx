"use client";

import Lightbox, { type Slide } from "yet-another-react-lightbox";
import Captions from "yet-another-react-lightbox/plugins/captions";
import Thumbnails from "yet-another-react-lightbox/plugins/thumbnails";
import Video from "yet-another-react-lightbox/plugins/video";
import "yet-another-react-lightbox/styles.css";
import "yet-another-react-lightbox/plugins/captions.css";
import "yet-another-react-lightbox/plugins/thumbnails.css";

// Split out so the lightbox and its three plugins load on the first tile click
// rather than on page load — nothing here is needed to render the grid.
export default function GalleryLightbox({
  index,
  slides,
  close,
}: {
  index: number;
  slides: Slide[];
  close: () => void;
}) {
  return (
    <Lightbox
      open={index >= 0}
      index={index}
      close={close}
      slides={slides}
      plugins={[Video, Captions, Thumbnails]}
      controller={{ closeOnBackdropClick: true }}
      noScroll={{ disabled: true }}
      // Muted autoplay is the only cross-browser-reliable autoplay; the
      // (now unobstructed) controls let viewers unmute.
      video={{ autoPlay: true, muted: true, controls: true, playsInline: true }}
      thumbnails={{
        position: "bottom",
        width: 140,
        height: 90,
        border: 1,
        borderRadius: 10,
        gap: 12,
        padding: 4,
      }}
    />
  );
}
