# Phase 21 — Screens: `quicklinks` and `emoji`

**Milestone:** M3 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

Migrate the quicklinks list and the emoji grid. The emoji screen is the first with **two-dimensional
navigation** — its ↑/↓ move by grid row, not by list index — so it is the first real test of whether the
protocol handles more than a flat list.

## Why this phase exists

Continues the incremental migration on the two screens that between them add: a per-row Actions menu, a
⌘P chord, a ⌘⌫ chord, a ⌘↵ chord, and grid geometry. None involves the calculator card, which stays for
phases 22–23.

## Architecture Review reference

**C-2** · Roadmap W4.2

## Objectives

1. Add `QuicklinkListScreen` and `EmojiScreen` conforming to `PaletteScreen`.
2. Move their keyboard chords out of `RootPaletteView`'s global handlers into the screens.
3. Remove their arms from the remaining switches.

## Expected files to modify

| File                                                     | Change                                                |
| -------------------------------------------------------- | ----------------------------------------------------- |
| `Tinycast/Features/Quicklinks/QuicklinkListScreen.swift` | **New.**                                              |
| `Tinycast/Features/Emoji/EmojiScreen.swift`              | **New.**                                              |
| `Tinycast/Features/PaletteScreen.swift`                  | Likely gains a `move(_:from:)` hook — see boundaries. |
| `Tinycast/Features/RootPaletteView.swift`                | Two more arms out of each switch; chord routing.      |
| `Tinycast/Features/Quicklinks/QuicklinkListView.swift`   | Body + `QuicklinkActionsMenu` move into the screen.   |
| `Tinycast/Features/Emoji/EmojiGridView.swift`            | Body + `EmojiActionsMenu` move into the screen.       |
| `Tools/palette-selection-test.swift`                     | Add grid-geometry cases.                              |

## Files that must NOT change

- `Tinycast/Core/Emoji/EmojiGridGeometry.swift` — **harness-compiled and pure.** The grid maths is
  already correct and already tested; the screen _calls_ it.
- `Tinycast/Core/Emoji/EmojiCatalog.swift`, `EmojiData.generated.swift`
- `Tinycast/Core/Quicklinks/*`
- `Tinycast/Core/AppCore.swift`
- The three not-yet-migrated modes' arms

## Implementation boundaries

- **The protocol likely needs a navigation hook.** `RootPaletteView` currently branches
  `if vm.mode == .emoji { moveEmojiRow(delta) } else { move(delta) }`, and the emoji screen also handles
  ← / → while every other screen leaves them to the field editor. Add a single optional member — e.g.
  `func move(_ delta: Int, axis: PaletteAxis, from: Int) -> Int?` returning nil to mean "use the default
  linear move". **One member. Do not build a navigation subsystem.**
- `EmojiGridGeometry` is used exactly as today: constructed from `sections.map(\.entries.count)` and
  `EmojiGrid.columns`, then `up(from:)` / `down(from:)`. Do not reimplement it.
- Chords that move into the screens:
  - quicklinks: ⌘P (pin), ⌘⌫ (delete), ⌘↵ (open with default, only when `openWithBundleID != nil`)
  - emoji: ⌘↵ (copy), ⌥↵ (paste keeping the window open), ← / →
- **⌘K, Escape, Tab and the menu-navigation keys stay in `RootPaletteView`.** They are palette-level, not
  screen-level.
- The emoji screen's flat selection indexes `sections.flatMap(\.entries)` — that mapping is the
  invariant and must not change.
- Empty-state strings stay: "No quicklinks yet" / "No matching quicklinks" / "Loading emoji…" /
  "No emoji found", with the same conditions choosing between them.
- Do not change the `.emoji` skin-tone application — it happens at render and at copy time via
  `settings.emojiSkinTone`, and both stay.

## Detailed acceptance criteria

1. Both screens conform; both modes are gone from `RootPaletteView`'s switches.
2. Any protocol addition is a single member, justified in the summary.
3. Emoji ↑/↓ move one visual grid row, spilling into the neighbouring section while keeping the column.
4. Emoji ← / → move one cell and are consumed (they do not reach the field editor).
5. In every other screen, ← / → still move the text caret.
6. Quicklink ⌘P pins and the row moves to the top of the list.
7. Quicklink ⌘⌫ deletes, honouring the "confirm before deleting" setting.
8. Quicklink ⌘↵ opens with the default app only when a handler override is set.
9. `palette-selection-test` covers grid row movement.
10. Emoji skin tone still applies to rendered glyphs and to copied text.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `palette-selection-test`, `emoji-test`, `quicklink-test`
- [ ] `checklists/regression.md` — Core sweep + **Quicklinks**
- [ ] Emoji grid: ↓ from the last row of a section lands in the same column of the next section
- [ ] ↑ from the first row of a section lands in the same column of the previous section
- [ ] ← / → step one cell and wrap across rows exactly as before
- [ ] In the launcher, ← / → still move the caret in the search field
- [ ] Emoji ⌘↵ copies with the configured skin tone; ⌥↵ pastes and the palette stays open
- [ ] Change the skin tone in Settings → the grid re-renders with the new tone
- [ ] Quicklinks: ⌘P pins → the row jumps to the top; ⌘P again unpins
- [ ] ⌘⌫ with "confirm before deleting" on → dialog; off → immediate
- [ ] ⌘↵ on a quicklink with an "open with" app → opens in the default browser instead
- [ ] ⌘↵ on one without → does nothing
- [ ] Right-click a row in both screens → the correct Actions menu

## Regression risks

| Risk                                                                                           | Mitigation                                                      |
| ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| **Emoji grid navigation breaks.** The column-preserving spill is subtle and easy to get wrong. | AC3/AC4 + `EmojiGridGeometry` staying untouched + harness cases |
| ← / → get consumed in non-emoji screens, breaking the caret                                    | AC5 — test in the launcher explicitly                           |
| A chord moves to the screen but is not routed, so it silently does nothing                     | Every chord in the checklist                                    |
| The protocol grows a navigation framework                                                      | AC2 — one member                                                |
| Skin tone is applied at only one of the two points                                             | AC10                                                            |

## Rollback strategy

`git revert <sha>`.

## Expected commit size

7 files, +260 / −220 lines.

## Suggested commit message

```
Move the quicklinks and emoji screens onto PaletteScreen

The emoji grid is the first screen with two-dimensional navigation, so
PaletteScreen gains one optional move hook; EmojiGridGeometry — pure and
harness-tested — is called, not reimplemented. Screen-level chords (⌘P,
⌘⌫, ⌘↵, ⌥↵, ←/→) move into their screens; the palette-level keys stay.
```

## Dependencies

**Phase 20 (hard).** Blocks 22.

## Definition of Done

- All acceptance criteria met
- Grid navigation verified by hand in all four directions across a section boundary
- ← / → verified to still work in the launcher
- Merged

## Estimated difficulty

**Medium.** The navigation hook is the design decision.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Grid navigation is the thing to test by hand**, at a section boundary specifically. The harness can
  cover the index maths; only you can confirm it feels the same.
- Verify `EmojiGridGeometry.swift` is absent from the diff.
- Read the new protocol member. If it is more than one function returning an optional index, ask why.
- Check the ⌘↵ guard on quicklinks: it must remain conditional on `openWithBundleID != nil`, otherwise
  the chord starts doing something on rows where it previously did nothing.
