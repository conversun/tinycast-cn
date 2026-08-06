# Phase 23 — Screen: `launcher`, and collapsing the calc offset

**Milestone:** M3 · **Effort:** L · **Risk:** **High** · **Context:** High

---

## Overview

The last and largest screen. `launcher` owns favourites pinning, nine-section ordering, the running-app
indicator, the compact bar's overflow, the calculator card, and the flat-selection invariant that every
one of those interacts with. Migrating it collapses the last of the eight `calcCount` computations into
one and empties `RootPaletteView`'s switches.

**This is the highest-risk phase in the roadmap.** Treat it accordingly.

## Why this phase exists

Finishing M3. After this, adding a palette mode is one new file, and the flat-selection invariant is
structural rather than manually maintained in eight places.

## Architecture Review reference

**C-2** · Roadmap W4.4–W4.5 and its explicit mitigation

## Objectives

1. Add `LauncherScreen` conforming to `PaletteScreen`.
2. Remove the last arm from every switch in `RootPaletteView`; delete the now-empty switches.
3. Collapse every remaining `calcCount` / `offset` computation into the single `rows[0]` pattern.
4. Remove the `openActions()` workaround now that `orderedResults` is memoized (phase 09).

## Expected files to modify

| File                                              | Change                                                                         |
| ------------------------------------------------- | ------------------------------------------------------------------------------ |
| `Tinycast/Features/Launcher/LauncherScreen.swift` | **New.**                                                                       |
| `Tinycast/Features/RootPaletteView.swift`         | ~1126 → ~350 lines.                                                            |
| `Tinycast/Features/Launcher/LauncherView.swift`   | `LauncherList`, `AppRow`, `AppActionsMenu` move or are consumed by the screen. |
| `Tools/palette-selection-test.swift`              | Nine-section + favourites + calc-card cases.                                   |

## Files that must NOT change

- `Tinycast/Core/AppIndex.swift` — including `orderedResults` from phase 09
- `Tinycast/Core/FavoritesStore.swift`, `VisibilityStore.swift`, `RunningApps.swift`
- `Tinycast/Core/AppCore.swift`
- `Tinycast/Features/Launcher/CalculatorCardView.swift`
- Every already-migrated screen

## Implementation boundaries

- **The section table is the invariant.** `LauncherList.rows` builds nine sections in this exact order,
  and the order must match `AppIndex.publishEntries`'s slice order or the flat index breaks:
  `Favorites, Applications, System Settings, Quicklinks, Snippets, System Actions, Window Management,
Custom Commands, Commands`. Copy it verbatim. **Do not** re-derive it, sort it, or make it data-driven
  in this phase.
- The `favoriteCount` prefix logic stays: with an empty query, favourites are the leading
  `favoriteCount` entries of `results`, and `rest` is everything after — filtered by `kind` into
  sections. This is why the `AppIndex` slice order is load-bearing.
- **The calculator card is `rows[0]`**, exactly as phase 22 established. After this phase,
  `grep -rn "calcCount" Tinycast` must return nothing.
- Chords moving into the screen: ⌘↵ (Show in Finder, only when `canRevealInFinder`), ⌃⇧Q (quit, only for
  a running `.application`), ⌘1–⌘5 (compact favourite slots).
- **Palette-level things stay in `RootPaletteView`:** the header and search field, the footer bar, both
  menu overlays, ⌘K, Escape, Tab, the bare-Backspace routing, ⌘, and ⌘W, the compact/expanded frame
  sync, and `onChange(of: vm.mode)`'s session cleanup.
- The compact bar's favourite slots (`compactFavoriteSlots`, `CompactFavoritesRow`,
  `CompactFavoriteButton`) belong to the launcher screen conceptually but are rendered in the **header**,
  which is palette-level. Move the _derivation_ into the screen and let the header ask for it; do not
  duplicate it.
- `openActions()`'s `if vm.mode == .launcher` guard exists because `appResults` was unmemoized. With
  phase 09 merged, that reason is gone — remove the workaround and its comment. If phase 09 is **not**
  merged, leave the workaround and note it.
- Do not change `AppActionsMenu`'s row set, ordering or conditions.
- Do not touch the running-dot rendering or `RunningAppsMonitor` observation scope.

## Detailed acceptance criteria

1. `LauncherScreen` conforms; `RootPaletteView` contains **no** `switch vm.mode` over screens.
2. `RootPaletteView` is under ~400 lines.
3. `grep -rn "calcCount" Tinycast` returns nothing.
4. Section order is identical, verified against a pre-phase screenshot of a scrolled empty-query launcher.
5. Favourites pin to the top with an empty query, in stored order, and are excluded from later sections.
6. With a query typed, sections collapse to a single "Results" section.
7. With a calculation typed, the "Calculator" section and card lead, and the query results follow.
8. ⌘1–⌘5 launch the correct compact favourites; the "…" overflow expands.
9. ⌃⇧Q quits only a running application.
10. ⌘↵ reveals in Finder only for revealable kinds.
11. `palette-selection-test` covers nine sections + favourites + calc card and passes.
12. The `openActions` workaround is removed (or its retention is documented).

## Manual verification checklist

- [ ] `checklists/build.md` — **including the Release build** (type-checker budget: `LauncherList.rows`
      already carries an annotation because inference times out)
- [ ] `checklists/testing.md` — **all 17 harnesses**
- [ ] `checklists/regression.md` — **the full document, every section**
- [ ] Empty-query launcher, fully scrolled → screenshot matches the pre-phase screenshot section for
      section, row for row
- [ ] ↑/↓ from the very first row to the very last → the highlight is on the row the pill describes at
      **every** step (walk it slowly)
- [ ] Same walk with a calculation typed → the card is first and the offset never drifts
- [ ] Same walk with favourites set
- [ ] Same walk with a category hidden
- [ ] Type a query → single Results section; ↵ launches the highlighted entry
- [ ] Right-click any row → the correct Actions menu, header naming that row
- [ ] Compact mode: ⌘1–⌘5 launch the right apps; six+ favourites shows "…"; ↓ expands
- [ ] ⌃⇧Q on a running app quits it; on a non-running app does nothing
- [ ] ⌘↵ on an app reveals it; on a command does nothing
- [ ] Hotkey keycaps still render on rows that have a binding
- [ ] Running dots still appear and update live

## Regression risks

| Risk                                                                                                           | Mitigation                                                     |
| -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **The flat-selection index drifts.** The single worst outcome — silent, and it makes ↵ launch the wrong thing. | `palette-selection-test` + the four slow ↑/↓ walks             |
| Section order diverges from `AppIndex.publishEntries`                                                          | AC4 screenshot + the boundary forbidding re-derivation         |
| Favourites appear twice, or hidden favourites reappear                                                         | AC5                                                            |
| Release build times out type-checking the section table                                                        | Keep the existing explicit annotation; Release build is a gate |
| Compact favourites duplicated between header and screen                                                        | Boundary — derive once                                         |
| `openActions` workaround removed without phase 09 → per-render cost returns                                    | AC12                                                           |

## Rollback strategy

`git revert <sha>`.

**This is the phase most likely to be reverted.** If the ↑/↓ walk shows drift and the cause is not
obvious within ~20 minutes, revert rather than debug — the earlier screens are unaffected and the
launcher can be re-attempted with a narrower first step (e.g. migrate rendering only, leave chords in
`RootPaletteView`, then a follow-up phase for the chords).

## Expected commit size

4 files, +450 / −800 lines. **Net negative** — that is the point.

## Suggested commit message

```
Move the launcher onto PaletteScreen and collapse the calc offset

The last screen. RootPaletteView drops from ~1126 to ~350 lines and no
longer switches on the mode at all. The calculator card is rows[0]
everywhere now, so the eight independent calcCount computations that
maintained the flat-selection invariant by hand become one array index.
Section order is copied verbatim — it must match AppIndex's slice order.
```

## Dependencies

**Phase 22 (hard).** Phase 09 for AC12. Blocks all of M4.

## Definition of Done

- All acceptance criteria met
- **All four ↑/↓ walks completed slowly and by hand**
- Screenshot comparison attached to the progress file
- Release build clean
- All 17 harnesses green
- Full regression document walked
- Merged

## Estimated difficulty

**High.** The largest single diff in the roadmap, on the app's most load-bearing invariant.

## Estimated Claude context usage

**High.** Consider asking for rendering first, then chords, as two commits on one branch.

## Notes for reviewers

- **Do the ↑/↓ walks yourself, slowly, in all four configurations.** No amount of diff reading
  substitutes for it, and the harness only covers the index maths, not the wiring between the index and
  what is drawn.
- Compare the section-order screenshot before reading any code.
- `grep -rn "calcCount"` — if it returns anything, the collapse is incomplete and phase 26's cleanup
  inherits a mess.
- Confirm `RootPaletteView` still owns the header, footer, both menu overlays, and ⌘K/Escape/Tab. If any
  of those migrated into the screen, the split is in the wrong place.
- A net-negative diff is expected. A net-positive one means the switches were replaced rather than
  removed.
