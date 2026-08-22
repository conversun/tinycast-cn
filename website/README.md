# Tinycast website

The marketing page and documentation for Tinycast, at
<https://abue-ammar.github.io/tinycast/>.

Next.js (App Router) with a **static export** — there is no server behind the deployed site. Tailwind
v4 for styling, [Fumadocs](https://fumadocs.dev) for the documentation section.

## Develop

```sh
npm install
npm run dev      # http://localhost:3000/tinycast
```

`npm install` runs `fumadocs-mdx`, which generates `.source/` from `content/docs/`. That directory is
generated and not committed.

## Scripts

| Script           | Does                            |
| ---------------- | ------------------------------- |
| `npm run dev`    | Dev server                      |
| `npm run build`  | Type-check and export to `out/` |
| `npm run lint`   | oxlint                          |
| `npm run format` | Prettier                        |

## Structure

| Path               | Holds                                                                  |
| ------------------ | ---------------------------------------------------------------------- |
| `src/app/`         | Routes. `page.tsx` is the marketing page; `docs/` is the documentation |
| `src/components/`  | Page sections, with shared primitives in `ui/`                         |
| `src/data/`        | All copy and content, so components stay free of prose                 |
| `src/index.css`    | **The only design-token source.** Colors, type scale, shadows          |
| `content/docs/`    | The documentation, as plain Markdown                                   |
| `source.config.ts` | Fumadocs and Shiki configuration                                       |

## Design tokens

`src/index.css` is the single source of truth, and Tailwind's default text and shadow scales are
**disabled** there so an off-scale value cannot slip in. Use the named roles (`text-body`,
`shadow-key`) rather than raw sizes.

Token names are semantic: `canvas` is near-black in Dark and near-white in Light. Dark is the frozen
baseline and Light restates it with the ink inverted — the same rule the app itself follows.

**Any new token must also be registered in `src/lib/cn.ts`.** Its `extendTailwindMerge` call teaches
tailwind-merge about the custom groups; an unregistered `shadow-*` is misclassified as a color and
silently dropped when merged.

## Documentation

One Markdown file per page under `content/docs/`, with a `meta.json` per folder controlling sidebar
order. Adding a page means adding a file and a line.

Shiki highlighting is limited to `bash`, `json` and `markdown` in `source.config.ts`. Keep it that
way — highlighting a keyboard shortcut or a placeholder buys nothing and costs bytes. Keyboard keys
use `<kbd>`, which renders through the same keycap component as the marketing page.

## Deploy

Pushes to `main` touching `website/**` are built and published to GitHub Pages by
`.github/workflows/website.yml`.

Two things are load-bearing and easy to break:

- **`public/.nojekyll` must exist.** GitHub Pages runs Jekyll, which ignores directories starting
  with `_`. Without it, everything under `_next/` 404s and the site renders unstyled.
- **The workflow uploads `website/out`**, which is where a Next.js export lands.

The site is served from the `/tinycast/` subpath, set as `basePath` in `next.config.mjs`. `next/link`
and `next/image` prefix it automatically; a raw URL string does not, which is what `src/lib/asset.ts`
is for.

To test the real deployed shape rather than the dev server:

```sh
npm run build
mkdir -p /tmp/pages && cp -r out /tmp/pages/tinycast
cd /tmp/pages && python3 -m http.server 4321
# http://localhost:4321/tinycast/
```
