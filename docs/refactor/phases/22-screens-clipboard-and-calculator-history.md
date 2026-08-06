# Phase 22 — Screens: `clipboard` and `calculatorHistory`

**Milestone:** M3 · **Effort:** M · **Risk:** Med · **Context:** High

---

## Overview

Migrate the clipboard browser and the calculator history. `calculatorHistory` is the **first screen with
the inline calculator card**, so this is where the `calcCount` offset arithmetic first moves into a
screen — and where it must be done exactly right, once, so phase 23 can reuse it.

## Why this phase exists

The clipboard screen is a split list + preview with a follow-the-moved-row behaviour that is easy to
break. The calculator-history screen carries the calc card at flat index 0, shifting every subsequent
row by one — the offset that appears in eight places today.

## Architecture Review reference

**C-2** · Roadmap W4.3

## Objectives

1. Add `ClipboardScreen` and `CalculatorHistoryScreen`.
2. Express the calculator card as **a prepended row in `rows`**, not as a separate offset variable.
3. Preserve the clipboard's follow-the-moved-row behaviour exactly.

## Expected files to modify

| File                                                         | Change                                                                                                   |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| `Tinycast/Features/Clipboard/ClipboardScreen.swift`          | **New.**                                                                                                 |
| `Tinycast/Features/Calculator/CalculatorHistoryScreen.swift` | **New.**                                                                                                 |
| `Tinycast/Features/RootPaletteView.swift`                    | Two more arms; the `clipFollow` handler moves.                                                           |
| `Tinycast/Features/Clipboard/ClipboardView.swift`            | Body + `ClipboardActionsMenu` move.                                                                      |
| `Tinycast/Features/Calculator/CalculatorHistoryView.swift`   | Body + `CalcHistoryActionsMenu` move.                                                                    |
| `Tinycast/Features/Launcher/CalculatorCardView.swift`        | `CalcActionsMenu` may move; the card view itself is shared with the launcher — **leave it where it is**. |
| `Tools/palette-selection-test.swift`                         | Calc-card-at-index-0 cases.                                                                              |

## Files that must NOT change

- `Tinycast/Core/ClipboardStore.swift` — harness-compiled
- `Tinycast/Core/Calculator/*` — harness-compiled
- `Tinycast/Core/CalculatorHistoryStore.swift`
- `Tinycast/Core/AppCore.swift`
- The launcher's arm in `RootPaletteView` — that is phase 23

## Implementation boundaries

- **The calculator card becomes a row, not an offset.** `rows` for the history screen is
  `[.calc(result)] + entries.map(Row.entry)` when a result exists. The flat selection then indexes
  `rows` directly and `calcCount` disappears from this screen. This is the pattern phase 23 reuses —
  get it right here.
- `CalculatorCardView` is **shared** with the launcher screen (still un-migrated). Do not move it, do
  not parameterise it, do not duplicate it.
- **The clipboard's follow behaviour is precise and must be copied exactly:**
  - The change key is `ClipFollowKey(id: store.items.first?.id, token: vm.followToken)` — read from the
    **store**, not from the filtered results, so typing a query never reads as a row that moved.
  - A nil `old.id` is the first load landing, not a move — it must not reposition the selection.
  - Selection only follows when the query is empty **and** the head id actually changed.
  - The scroll intent becomes `.follow` regardless.
- Clipboard chords moving into the screen: ⌘P (pin), ⌘⌫ (delete), ⌘↵ (copy without pasting).
  History chords: ⌘⌫ (delete, never the calc card), ⌘↵ (copy the expression).
- The empty-history case renders `EmptyResults` **across the whole panel**, not inside the narrow list
  column. Preserve that branch.
- Preview pane, `ClipboardInfoSection`, `AsyncThumbnail` and `DateBucket` all move with the screen
  unchanged. Do not edit them.
- An error calc card is selectable but has **no** action: it must not drive the pill, the ⌘K menu, or ↵.
  Preserve that condition.

## Detailed acceptance criteria

1. Both screens conform; both arms gone from `RootPaletteView`.
2. The history screen has no `calcCount`/offset variable — the card is `rows[0]`.
3. `palette-selection-test` covers a leading calc row and passes.
4. Clipboard: a new capture while the palette is open moves the selection to the new head row **only**
   when the query is empty.
5. Clipboard: typing a query does **not** move the selection.
6. Clipboard: pinning moves the row into Pinned and the selection follows it.
7. History: with a calculation typed, the card is row 0 and ↵ copies + records it.
8. History: ⌘⌫ never deletes the calc card.
9. An error calc card shows no primary action and ⌘K does not open an empty menu.
10. Empty clipboard history centres one message across the panel.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `palette-selection-test`, `clipboard-test`, `calc-test`
- [ ] `checklists/regression.md` — Core sweep + **Clipboard** + **Calculator & currency**
- [ ] Open clipboard history, copy something from another app → the new row appears at the top and is
      selected
- [ ] Type a query, then copy something → **the selection must not jump**
- [ ] ⌘P a row → it moves to Pinned, the highlight follows, the list scrolls to it
- [ ] ⌘⌫ deletes; ⌘↵ copies without pasting; ↵ pastes; ⌥↵ pastes keeping the window open
- [ ] Select an image row → the preview and info section render
- [ ] Clear all history → the centred empty message appears across the full panel
- [ ] Calculator History: type `12*7` → the card is at the top and selected; ↵ copies and records
- [ ] Type `12/0` or nonsense that yields an error card → the footer pill hides and ⌘K does nothing
- [ ] With a card showing, ↓ then ⌘⌫ → deletes the **history entry**, not the card
- [ ] ⌘↵ on a history row copies the expression

## Regression risks

| Risk                                                                                                               | Mitigation                                    |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------- |
| **The clipboard selection jumps while typing.** The follow key's store-vs-results distinction is exactly this bug. | AC5 + the explicit test                       |
| The first load repositions the selection                                                                           | The nil-`old.id` guard; AC4                   |
| The calc card offset is reintroduced as a variable in the new screen                                               | AC2 — this is the pattern phase 23 depends on |
| ⌘⌫ deletes the calc card                                                                                           | AC8                                           |
| An error card enables the pill or the menu                                                                         | AC9                                           |
| Preview/thumbnail code is "tidied" during the move                                                                 | Boundary — move unchanged                     |

## Rollback strategy

`git revert <sha>`.

## Expected commit size

7 files, +330 / −290 lines.

## Suggested commit message

```
Move the clipboard and calculator-history screens onto PaletteScreen

The calculator card becomes rows[0] rather than a separate offset — the
pattern phase 23 reuses to collapse the last of the eight calcCount
computations. The clipboard's follow-the-moved-row key still reads from
the store, not the filtered results, so typing never reads as a move.
```

## Dependencies

**Phase 21 (hard).** Blocks 23.

## Definition of Done

- All acceptance criteria met
- The "type a query then copy" check passed explicitly
- The calc-card-as-row pattern established and readable
- Merged

## Estimated difficulty

**Medium–High.** Two screens, one of them a split view with a subtle follow behaviour.

## Estimated Claude context usage

**High** — `ClipboardView.swift` alone is 472 lines.

## Notes for reviewers

- **The follow behaviour is the thing.** Read `ClipFollowKey`'s new home and confirm it still reads
  `store.items.first?.id`. If it reads the screen's filtered `rows`, the bug is back and it only shows
  up when a query is typed.
- Confirm `calcCount` does not appear in either new file. If it does, the phase-23 collapse gets harder.
- `CalculatorCardView` must not be duplicated — `grep -rn "struct CalculatorCard" Tinycast` returns one.
- The preview pane, `AsyncThumbnail` and `DateBucket` should show as pure moves under `git diff -M`.
