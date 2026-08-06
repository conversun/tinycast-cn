# Phase 09 — `Memo` primitive and launcher result memoization

**Milestone:** M1 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

One logical objective: **eliminate repeated per-render work behind a single memo primitive.** Introduce
a tiny `Memo<Key, Value>`, adopt it at the four non-harness memo sites, and use the same primitive to
close the last unmemoized path — the launcher's visibility + favourites chain.

## Why this phase exists

Six hand-rolled one-entry caches exist, each with a different invalidation mechanism: a `didSet`, an
explicit `= nil` in `persist()`, a revision counter, a manual clear in `record()`. Each is correct
today; the seventh will be the one that forgets.

Separately, `RootPaletteView.appResults` and `compactFavoriteSlots` run an unmemoized
`.filter(visibility.isVisible)` plus a full dictionary build over ~300–400 entries on every render. That
cost is already being worked around — `openActions()` carries a comment explaining that non-launcher
modes skip the walk deliberately.

## Architecture Review reference

**M-7** (the primitive) · **M-3** (the launcher chain) · §6 P-6

## Objectives

1. Add `Tinycast/Core/Memo.swift`: a ~20-line single-slot memo whose key bundles every dependency.
2. Adopt it in `AppIndex.matchCache`, `CalculatorHistoryStore.searchCache`, `EmojiIndex.searchCache`,
   `FrequentEmojiStore.sortedGlyphs`.
3. Add `revision` counters to `VisibilityStore` and `FavoritesStore`, mirroring
   `LauncherRankingStore.revision`.
4. Add `AppIndex.orderedResults(query:visibility:favorites:)`, memoized on
   `(query, rankingRevision, visibilityRevision, favoritesRevision)`.
5. Point `RootPaletteView.appResults`, `compactFavoriteSlots`, `selectedAppEntry` and `actionsContent`
   at it.

## Expected files to modify

| File                                           | Change                                       |
| ---------------------------------------------- | -------------------------------------------- |
| `Tinycast/Core/Memo.swift`                     | **New.**                                     |
| `Tinycast/Core/AppIndex.swift`                 | `matchCache` → `Memo`; add `orderedResults`. |
| `Tinycast/Core/CalculatorHistoryStore.swift`   | `searchCache` → `Memo`.                      |
| `Tinycast/Core/Emoji/EmojiIndex.swift`         | `searchCache` → `Memo`.                      |
| `Tinycast/Core/Emoji/FrequentEmojiStore.swift` | `sortedGlyphs` → `Memo`.                     |
| `Tinycast/Core/VisibilityStore.swift`          | Add `revision`.                              |
| `Tinycast/Core/FavoritesStore.swift`           | Add `revision`.                              |
| `Tinycast/Features/RootPaletteView.swift`      | Four call sites read `orderedResults`.       |

## Files that must NOT change

- `Tinycast/Core/ClipboardStore.swift` — **harness-compiled.** Its `searchCache` and `orderedCache` stay
  exactly as they are. Adding `Memo` to it would require adding a file to the `clipboard-test` command
  line, which is a separate `AGENTS.md` decision and not this phase.
- `Tinycast/Core/LauncherRankingStore.swift` — harness-compiled; its `revision` is the pattern to copy
- `Tinycast/Core/SearchRelevance.swift` — harness-compiled
- `Tinycast/Features/Launcher/LauncherView.swift`

## Implementation boundaries

- `Memo` is a `struct` with one optional `(key, value)` slot and one `mutating func value(for:build:)`.
  **No LRU, no size limit, no expiry, no generics beyond `Key: Equatable` and `Value`.**
- Adopting `Memo` must not change _what_ is cached or _when_ it is invalidated — only how. Each
  adoption's key must encode exactly the dependencies its old invalidation covered. Where the old code
  cleared a cache in `persist()`, the new key must include whatever `persist()` changed.
- `revision` on `VisibilityStore` and `FavoritesStore` uses `&+=` and increments on **every** mutation
  that could change the visible set — including `replace(…)` and `removeItemKeys(…)`.
- `orderedResults` performs exactly the current chain in the current order:
  `matches(query)` → `.filter(visibility.isVisible)` → if query is empty and favourites exist,
  `favorites.ordered(base)` → `favorites + rest`. **Do not reorder or "optimise" the chain.**
- Do not delete the `openActions()` workaround comment or its `if vm.mode == .launcher` guard in this
  phase — that cleanup belongs with the palette split (phase 23).
- Do not touch `SearchRelevance` or the ranking maths.

## Detailed acceptance criteria

1. `Memo.swift` is Foundation-only, under 30 lines, with no state beyond the single slot.
2. All four named adoptions compile and behave identically.
3. `ClipboardStore` is untouched.
4. `orderedResults` returns a result identical to the current `appResults` chain for: empty query with
   favourites, empty query without favourites, non-empty query, and a query with hidden items.
5. Toggling a favourite, hiding an item, hiding a category, or recording a launch each invalidate the
   memo — the launcher list updates on the very next render.
6. `compactFavoriteSlots` no longer builds a dictionary per render.
7. The launcher's section order and favourite pinning are unchanged.
8. `AppIndex.rank` signpost shows no regression; per-render allocation drops.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `fuzz-test`, `ranking-test`, `emoji-test`, `clipboard-test`
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons** + **Clipboard** + **Calculator**
- [ ] Empty-query launcher: Favorites section present, correct order, correct contents
- [ ] Add a favourite from the Actions menu → it moves to the Favorites section **immediately**
- [ ] Remove a favourite → it leaves immediately
- [ ] Hide an item in Settings ▸ Applications → it disappears from the launcher on the next open
- [ ] Hide a whole category → the section disappears
- [ ] Launch an app to teach the ranking → its position updates for that query
- [ ] Compact mode with 6+ favourites: five slots plus the "…" overflow; ⌘1–⌘5 launch the right apps
- [ ] Emoji search still ranks identically; frequently-used section unchanged
- [ ] Calculator history search still filters correctly

## Regression risks

| Risk                                                                         | Mitigation                                                                              |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **A stale memo shows the wrong list** — e.g. a favourite added but not shown | AC5, and the specific favourite/hide checks above                                       |
| A `revision` counter misses a mutation path                                  | Enumerate every mutating method on both stores in review                                |
| The chain is subtly reordered and hidden favourites reappear                 | AC4; the review's note that visibility filtering stays _downstream_ of `matches` is why |
| `ClipboardStore` gets "helpfully" included                                   | AC3, and `clipboard-test`                                                               |
| Memo grows into a general cache                                              | AC1's line budget                                                                       |

## Rollback strategy

`git revert <sha>`. Purely in-memory. No persistence, no migration.

## Expected commit size

8 files, +110 / −70 lines.

## Suggested commit message

```
Add a one-slot Memo and memoize the launcher result chain

Four hand-rolled memo caches, each with its own invalidation, become one
primitive whose key states its dependencies. The launcher's visibility +
favourites chain — the last unmemoized path feeding the flat selection
index — goes through it too, keyed on the ranking, visibility and
favourites revisions. ClipboardStore is untouched: it is harness-compiled.
```

## Dependencies

Phase 01. **Should land before phase 17** (which migrates `AppIndex` to `@Observable`).

## Definition of Done

- All acceptance criteria met
- Favourite/hide/rank invalidation verified interactively
- Merged

## Estimated difficulty

**Medium.** The primitive is trivial; getting four invalidation policies encoded correctly into keys is
where the care goes.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- For each of the four adoptions, ask: _what invalidated the old cache, and is every one of those things
  in the new key?_ `FrequentEmojiStore.sortedGlyphs` is cleared in `record()`; `CalculatorHistoryStore`
  clears in `persist()`. Both need a mutation counter in the key, not just the query.
- `revision` must increment in `FavoritesStore.replace`, `.remove` and `.toggle`; in
  `VisibilityStore.replace`, `.setItemVisible`, `.removeItemKeys` and `.setKindVisible`. Count them in
  the diff.
- If `ClipboardStore` appears in `git diff --name-only`, revert.
- Confirm `Memo` did not acquire a capacity, an expiry or a thread-safety story. It is a struct on a
  `@MainActor` type; it needs none.
