# Phase 20 — Screens: `quicklinkArguments` and `uninstall`

**Milestone:** M3 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

The first two adopters of `PaletteScreen`. Chosen because `quicklinkArguments` is the smallest screen in
the app (no Actions menu at all) and `uninstall` has no calculator card and a single flat list — so
neither exercises the hard parts, and both prove the protocol.

## Why this phase exists

Phase 19 designed the protocol without an adopter. This phase finds out whether it was designed right,
on the two screens where being wrong is cheapest to correct.

## Architecture Review reference

**C-2** · Roadmap W4.1–W4.2

## Objectives

1. Add `QuicklinkArgumentsScreen` and `UninstallScreen` conforming to `PaletteScreen`.
2. Remove their arms from `RootPaletteView`'s eight switches.
3. Amend the protocol if adoption reveals a genuine gap — and say so explicitly.

## Expected files to modify

| File                                                          | Change                                            |
| ------------------------------------------------------------- | ------------------------------------------------- |
| `Tinycast/Features/Quicklinks/QuicklinkArgumentsScreen.swift` | **New.**                                          |
| `Tinycast/Features/Uninstall/UninstallScreen.swift`           | **New.**                                          |
| `Tinycast/Features/PaletteScreen.swift`                       | Only if adoption reveals a real gap.              |
| `Tinycast/Features/RootPaletteView.swift`                     | Two arms removed from each of the eight switches. |
| `Tinycast/Features/Quicklinks/QuicklinkArgumentsView.swift`   | May move into the screen or stay as its body.     |
| `Tinycast/Features/Uninstall/UninstallView.swift`             | Same; `UninstallActionsMenu` moves to the screen. |
| `Tools/palette-selection-test.swift`                          | Add cases for these two row shapes.               |

## Files that must NOT change

- Any other screen's code paths in `RootPaletteView` — the remaining five arms stay exactly as they are
- `Tinycast/Core/Uninstall/*` — every file
- `Tinycast/Core/Quicklinks/*` — every file
- `Tinycast/Core/AppCore.swift`

## Implementation boundaries

- **`RootPaletteView` keeps its switches for the un-migrated modes.** This is a partial migration by
  design; a hybrid `RootPaletteView` is the expected intermediate state through phases 20–23.
- Behaviour is copied **verbatim**. Specifically:
  - `quicklinkArguments`: an options argument filters by the field and renders rows; a free-text one
    renders none and keeps selection at 0. ↵ submits; the pill reads "Next" or "Open Quicklink"
    depending on `isLastArgument`. **There is no Actions menu** — `actions(for:)` returns nil.
  - `uninstall`: filter matches `name` **or** `locationLabel`. The summary line format is
    `"N of M files selected · size"`. ⌘↵ toggles a candidate unless locked. ↵ calls `performUninstall`.
    The four `state` cases (idle/scanning/failed/ready) all render as today.
- Do not change any user-visible string, including the placeholder text and the empty-state messages.
- Do not change `UninstallActionsMenu`'s row set or ordering — move it, do not edit it.
- The `onChange(of: vm.mode)` cleanup in `RootPaletteView` — which calls `uninstall.cancel()` and
  `core.cancelQuicklinkArguments()` when leaving those modes — **stays in `RootPaletteView`** for now.
  Moving lifecycle into the screens is phase 23's cleanup, not this one.
- If the protocol needs a sixth member or a changed signature, change it — but state the reason in the
  summary. Discovering that is part of this phase's job.

## Detailed acceptance criteria

1. Both screens conform to `PaletteScreen`; neither mode has an arm left in `RootPaletteView`'s switches.
2. `RootPaletteView` line count drops by ~90.
3. `palette-selection-test` covers both row shapes and passes.
4. The argument prompt: two-argument quicklink prompts in order; Backspace steps back and refills; ↵ on
   the last opens.
5. An options-bearing argument filters its choices by the field.
6. The uninstall screen shows all four states correctly and its summary line is character-identical.
7. ⌘↵ toggles an unlocked candidate; a locked one is unaffected.
8. Every string is unchanged.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `palette-selection-test`, `quicklink-test`, `uninstall-test`
- [ ] `checklists/regression.md` — Core sweep + **Uninstall** + **Quicklinks**
- [ ] Quicklink with two `{argument}`s → both prompts, in order, correct labels
- [ ] Quicklink with `{argument name="x" options="a,b,c"}` → the three options render and filter
- [ ] Free-text argument → no rows, ↵ submits the field text
- [ ] Backspace on an empty field steps back and refills the previous answer
- [ ] Escape mid-flow → the pending open is abandoned, no quicklink opens
- [ ] Uninstall a heavyweight app → scanning placeholder → list → summary line matches the pre-phase
      screenshot **character for character**
- [ ] Filter by a folder name and by a location → both match
- [ ] ⌘↵ on a normal row toggles; on a locked row does nothing
- [ ] ↵ → confirmation dialog → Trash

## Regression risks

| Risk                                                        | Mitigation                                                                               |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Row order or selection index shifts                         | `palette-selection-test` + interactive ↑/↓ walk                                          |
| The uninstall summary string changes                        | AC6, compared against a screenshot                                                       |
| The argument form's "no rows but ↵ still works" case breaks | AC4/5 — this is the one screen where `resultCount` can be 0 and the pill must still show |
| Mode-exit cleanup is moved prematurely and a session leaks  | Boundary: cleanup stays in `RootPaletteView`                                             |
| The protocol is bent to fit rather than fixed               | Summary must state any protocol change and why                                           |

## Rollback strategy

`git revert <sha>`. `RootPaletteView` returns to a seven-arm switch; the two new files disappear.

## Expected commit size

7 files, +200 / −150 lines.

## Suggested commit message

```
Move the quicklink-argument and uninstall screens onto PaletteScreen

First two adopters — the smallest screen in the app and the only flat
list with no calculator card. RootPaletteView keeps its switches for the
five modes still to migrate. Behaviour and strings copied verbatim.
```

## Dependencies

**Phase 19 (hard).** Blocks 21.

## Definition of Done

- All acceptance criteria met
- Any protocol amendment documented with its reason
- `palette-selection-test` extended and green
- Merged

## Estimated difficulty

**Medium.**

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- Diff the _moved_ code against its original with `git diff -M` — the bodies should be byte-identical
  apart from indentation and the `self.` prefix changes adoption forces.
- The uninstall summary line is assembled from three pieces (`selectedCount`, `plan.removableIDs.count`,
  `MeasuredSize.formatted`). Compare the rendered string, not the code.
- If the protocol changed, read the reason critically. "It was easier" is not a reason; "an options
  argument has zero rows but a live primary action, which `rows.isEmpty` cannot express" is.
- Confirm the remaining five switch arms in `RootPaletteView` are untouched.
