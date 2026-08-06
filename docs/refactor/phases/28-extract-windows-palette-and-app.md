# Phase 28 — Extract `Windows/`, `Palette/` and `App/`

**Milestone:** M5 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

More pure moves: the non-palette AppKit surfaces into `Windows/`, the palette shell into `Palette/`, and
the composition root into `App/`. Includes lifting `AuxWindowController` out of `AboutView.swift`.

## Why this phase exists

Continues M-1. `AuxWindowController` — a 90-line `NSWindowDelegate` owning the Settings, About and
Onboarding windows and flipping `NSApp.setActivationPolicy` — currently lives at the bottom of a view
file for one of the three windows it serves.

## Architecture Review reference

**M-1**, **M-9** · §4.2

## Objectives

1. Create `Tinycast/Windows/` and move the dialog, HUD, aux-window and About code into it.
2. Create `Tinycast/Palette/` and move the palette shell into it.
3. Consolidate `Tinycast/App/`.

## Expected moves

**→ `Tinycast/Windows/`**

| From                                                                        | To                                  |
| --------------------------------------------------------------------------- | ----------------------------------- |
| `Core/Dialog/*` (3 files)                                                   | `Windows/Dialog/`                   |
| `Features/Dialog/*` (2 files)                                               | `Windows/Dialog/`                   |
| `Core/HUD/*` (4 files)                                                      | `Windows/HUD/`                      |
| `Features/HUD/*` (2 files)                                                  | `Windows/HUD/`                      |
| `AuxWindowController` — **extracted** from `Features/About/AboutView.swift` | `Windows/AuxWindowController.swift` |
| `Features/About/AboutView.swift`                                            | `Windows/About/AboutView.swift`     |

**→ `Tinycast/Palette/`**

| From                                                                    | To                                      |
| ----------------------------------------------------------------------- | --------------------------------------- |
| `Core/PalettePanel.swift`                                               | `Palette/PalettePanel.swift`            |
| `Core/PaletteWindowController.swift`                                    | `Palette/PaletteWindowController.swift` |
| `Features/RootPaletteView.swift`                                        | `Palette/RootPaletteView.swift`         |
| `Features/PaletteScreen.swift`                                          | `Palette/PaletteScreen.swift`           |
| `Features/Palette/PaletteCoordinator.swift`                             | `Palette/PaletteCoordinator.swift`      |
| `PaletteViewModel` — **extracted** from `Core/AppCore.swift`            | `Palette/PaletteViewModel.swift`        |
| `PaletteMode` + `PasteTarget` — **extracted** from `Core/AppCore.swift` | `Palette/PaletteMode.swift`             |

**→ `Tinycast/App/`**

| From                         | To                                                                         |
| ---------------------------- | -------------------------------------------------------------------------- |
| `Core/AppCore.swift`         | `App/AppCore.swift`                                                        |
| `Core/OnboardingState.swift` | `Features/Onboarding/OnboardingState.swift` _(with its view, in phase 29)_ |

## Files that must NOT change (contents)

- `Core/Dialog/*`, `Core/HUD/*` — moved, contents untouched
- `PaletteWindowController.swift` — moved, contents untouched. **It still solely owns the frame.**
- `PalettePanel.swift` — moved, contents untouched
- Every store

## Implementation boundaries

- **Moves and extractions only.** The three extractions (`AuxWindowController`, `PaletteViewModel`,
  `PaletteMode`/`PasteTarget`) are cut-and-paste, not rewrites.
- `PaletteViewModel` is renamed to `PaletteState` in **phase 30**, not here. Move it under its current
  name.
- `AboutView.swift` keeps `AboutLink` and `AboutLinkRow` — only `AuxWindowController` leaves it.
- `AppCore.swift` moves to `App/` and loses three types to `Palette/`. Nothing else about it changes.
- No harness references any file in this phase — verify that claim before assuming it, then confirm all
  17 still pass.
- Do not reorganise `Features/` — phase 29.
- Do not merge `Windows/Dialog/` and `Windows/HUD/`. They are deliberately separate: a dialog asks, a
  HUD reports, and `AGENTS.md` says a new HUD means a new presenter rather than a second shape on an
  existing controller.

## Detailed acceptance criteria

1. Every listed file is at its new path.
2. `git diff -M --stat` shows 100 % similarity for every pure move.
3. `AuxWindowController` is its own file and `AboutView.swift` no longer declares it.
4. `PaletteViewModel`, `PaletteMode` and `PasteTarget` are out of `AppCore.swift`; `AppCore.swift` is
   correspondingly shorter.
5. `PaletteWindowController` contents are byte-identical.
6. All 17 harnesses pass; no command line changed.
7. Debug and Release builds succeed; UI pixel-identical.

## Manual verification checklist

- [ ] `checklists/build.md` including the **Release build**
- [ ] `checklists/testing.md` — all 17
- [ ] `checklists/regression.md` — Core sweep + **Settings & backup** + **System actions**
- [ ] Open Settings, About and Onboarding → each window appears, is key, and is centred
- [ ] Close the last aux window → the Dock icon disappears (activation policy returns to `.accessory`)
- [ ] Open Settings, then click the Dock icon → the existing window is focused, not duplicated
- [ ] Trigger a confirmation dialog → appears above the palette, Escape cancels, ↵ confirms
- [ ] Trigger the message pill and the volume HUD → both render and fade correctly
- [ ] Palette: compact↔expanded swap, top edge anchored
- [ ] Pop to Root at two settings
- [ ] `xcodegen generate` twice → stable

## Regression risks

| Risk                                                                                                         | Mitigation                                                                    |
| ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `AuxWindowController`'s activation-policy flip breaks → a stray Dock icon or a window that never becomes key | The three aux-window checks                                                   |
| The `DispatchQueue.main.async` re-assert of key status is lost in the extraction                             | Open Settings from the menu bar specifically — that is the path it exists for |
| Palette frame behaviour changes                                                                              | AC5 — byte-identical                                                          |
| A `fileprivate` in `AboutView.swift` was relied on by `AuxWindowController`                                  | Compiler catches it; do not widen access beyond `internal`                    |

## Rollback strategy

`git revert <sha>`. Pure moves.

## Expected commit size

~20 files moved, 3 extractions. Content delta near zero.

## Suggested commit message

```
Move the window surfaces, the palette shell and the composition root

Windows/ takes the dialog, HUD, aux-window and About code — including
AuxWindowController, which had been living at the bottom of AboutView.
Palette/ takes the panel, controller, root view, screen protocol and the
palette state types extracted from AppCore. Contents unchanged.
```

## Dependencies

**Phase 27 (hard).** Blocks 29.

## Definition of Done

- All acceptance criteria met
- The three aux windows verified individually
- All 17 harnesses green
- Merged

## Estimated difficulty

**Low–Medium.**

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Test the menu-bar → Settings path specifically.** `AuxWindowController` carries a
  `DispatchQueue.main.async` re-assertion of key status precisely because `NSApp.activate` from the menu
  bar is async and the synchronous `makeKeyAndOrderFront` can land first. Losing it produces a window
  that appears but is not key — easy to miss.
- Confirm the Dock icon disappears when the last aux window closes. That is `windowWillClose` restoring
  `.accessory`.
- `git diff -M --stat` similarity check as in phase 27.
- `PaletteWindowController` must be 100 %. It is the frame owner.
