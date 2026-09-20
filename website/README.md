# Tinycast website

The marketing page and documentation for Tinycast, at <https://tinycast.dev>.

Next.js (App Router) with a static export, Tailwind v4 for styling, and
[Fumadocs](https://fumadocs.dev) for the documentation section. A small Worker in `worker/` serves
the `/support` API.

## Develop

```sh
npm install
npm run dev      # http://localhost:3000
```

`npm install` runs `fumadocs-mdx`, which generates `.source/` from `content/docs/`. That directory is
generated and not committed.

## Scripts

| Script            | Does                                              |
| ----------------- | ------------------------------------------------- |
| `npm run dev`     | Dev server                                        |
| `npm run build`   | Type-check and export to `out/`                   |
| `npm run preview` | Build, then serve with the Worker, for `/support` |
| `npm run lint`    | oxlint                                            |
| `npm run format`  | Prettier                                          |

## Structure

| Path               | Holds                                                                  |
| ------------------ | ---------------------------------------------------------------------- |
| `src/app/`         | Routes. `page.tsx` is the marketing page; `docs/` is the documentation |
| `worker/`          | The Worker behind `/support`'s API                                     |
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

## Support page

`/support` needs the Worker, which `next dev` does not run. Without Polar credentials the page
still renders, with checkout disabled. To try it against Polar's sandbox, copy `.dev.vars.example`
to `.dev.vars` (gitignored), fill it in, and run `npm run preview` (http://localhost:8787).
`npm run check:worker` type-checks the Worker; its types are generated on install.

## Media

Files over 25 MiB cannot ship in `public/`. Put them in `media/` and reference them as
`` `${site.cdn}/<name>` ``; they are uploaded on push. A new file extension also needs its content
type added to `Scripts/upload-website-media.sh`.

## Deploy

Pushing to `main` deploys the site. To check the exported build locally:

```sh
npm run build
cd out && python3 -m http.server 4321   # http://localhost:4321/
```
