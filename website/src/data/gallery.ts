// Drives the "Tinycast in action" gallery + lightbox. Each item is a tile in
// the grid and a slide in the lightbox. `src`/`thumb`/`poster` are URLs as
// rendered — root-absolute for `public/`, absolute for anything on R2.
// `width`/`height` are the media's real pixel size (used for lightbox aspect);
// the grid tile is always 16:9.

import { site } from "./site";

export type GalleryItem = {
  type: "image" | "video";
  // Full-size media shown in the lightbox (image src, or video file for clips).
  src: string;
  // Grid thumbnail; falls back to `poster` (video) or `src` (image).
  thumb?: string;
  // Poster frame for video tiles/slides.
  poster?: string;
  title: string;
  caption: string;
  width: number;
  height: number;
};

export const galleryItems: GalleryItem[] = [
  {
    type: "video",
    src: `${site.cdn}/tinycast-in-action.mp4`,
    poster: "/screenshot.png",
    title: "Tinycast in action",
    caption:
      "A short tour of the launcher, clipboard history, calculator and more.",
    width: 3024,
    height: 1964,
  },
  {
    type: "image",
    src: "/calculator.png",
    title: "Inline calculator",
    caption: "Answers math and converts units and currencies as you type.",
    width: 2148,
    height: 1302,
  },
  {
    type: "image",
    src: "/clipboard.png",
    title: "Clipboard history",
    caption:
      "Search the text and images you've copied. History is stored only on your Mac.",
    width: 2092,
    height: 1268,
  },
  {
    type: "image",
    src: "/unlimited-clipboard-history.png",
    title: "Keep history as long as you want",
    caption: "Choose how long history is kept, from one day to forever.",
    width: 2226,
    height: 1604,
  },
  {
    type: "image",
    src: "/emoji.png",
    title: "Emoji & symbols",
    caption: "Search every emoji. The ones you use most show up first.",
    width: 2106,
    height: 1244,
  },
  {
    type: "image",
    src: "/per-app-hotkey.png",
    title: "Per-app hotkeys",
    caption:
      "Give an app its own shortcut. Press it to bring the app forward, and again to hide it.",
    width: 2212,
    height: 1606,
  },
  {
    type: "image",
    src: "/ram-usage.png",
    title: "Light on memory",
    caption: "Stays under 100 MB of memory, no matter how long it runs.",
    width: 2558,
    height: 1754,
  },
  {
    type: "image",
    src: "/backup-import-settings.png",
    title: "Backup & import",
    caption: "Export your setup to one file and restore it on any Mac.",
    width: 2098,
    height: 1600,
  },
];
