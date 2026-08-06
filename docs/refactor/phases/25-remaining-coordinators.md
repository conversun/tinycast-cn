# Phase 25 — Palette, SystemAction, Uninstall and CustomCommand coordinators

**Milestone:** M4 · **Effort:** L · **Risk:** Med · **Context:** High

---

## Overview

The remaining four coordinator extractions, ~370 lines total. After this, `AppCore` is the composition
root and nothing else.

## Why this phase exists

Completes C-1. `AppCore` goes from ~1,000 lines (post phase 24) to ~250: object ownership, `start()`
wiring, and the dialog façade.

## Architecture Review reference

**C-1** · Roadmap W5.3–W5.6

## Objectives

Extract, in this order, verifying each before the next:

1. **`PaletteCoordinator`** (~110 lines) — `togglePalette`, `toggleClipboard`, `toggleEmoji`,
   `showPalette`, `hidePalette`, `paletteIsCollapsed`, `expandFromCompact`, `syncPaletteSize`,
   `handleReopen`, and the aux-window show methods.
2. **`SystemActionCoordinator`** (~95 lines) — `runSystemAction`, `perform`, `presentFailure`,
   `quitAllApps`, `showsVolumeFeedback`, the volume-HUD choice.
3. **`UninstallCoordinator`** (~90 lines) — `beginUninstall`, `performUninstall`, the copy/reveal/info
   actions, `removeUninstalledReferences`, `presentUninstallReport`.
4. **`CustomCommandCoordinator`** (~75 lines) — CRUD, `runCustomCommand`,
   `removeCustomCommandReferences`, `presentCustomCommandFailure`, presence reconciliation.

## Expected files to modify

| File                                                              | Change                                          |
| ----------------------------------------------------------------- | ----------------------------------------------- |
| `Tinycast/Features/Palette/PaletteCoordinator.swift`              | **New.**                                        |
| `Tinycast/Features/SystemActions/SystemActionCoordinator.swift`   | **New.**                                        |
| `Tinycast/Features/Uninstall/UninstallCoordinator.swift`          | **New.**                                        |
| `Tinycast/Features/CustomCommands/CustomCommandCoordinator.swift` | **New.**                                        |
| `Tinycast/Core/AppCore.swift`                                     | −370 lines; +4 properties; forwarders retained. |

## Files that must NOT change

- `Tinycast/Core/PaletteWindowController.swift` — **the frame owner. Do not move frame logic into the
  coordinator.**
- `Tinycast/Core/SystemActionRunner.swift`, `Core/SystemAction.swift`
- `Tinycast/Core/Uninstall/*`
- `Tinycast/Core/CustomCommand.swift`, `Core/ShellCommandRunner.swift`
- `Tinycast/Core/Dialog/*`, `Core/HUD/*`
- `Tinycast/Features/About/AboutView.swift` — `AuxWindowController` stays put until phase 28

## Implementation boundaries

- **`PaletteWindowController` keeps sole ownership of the palette frame.** `PaletteCoordinator` decides
  _what mode to show_; the controller decides _where and how big_. `applyCollapsed`, `positionPanel`,
  `resolveAnchor` and `sizingOptions = []` do not move and are not touched.
- **`paletteIsCollapsed` stays the single source of truth** for compact vs expanded, wherever it lives.
  The window controller and the view must never be able to disagree.
- Pop-to-root (`consumePreservedState`, the timer) stays in `PaletteWindowController`. The coordinator
  calls it.
- **The funnel invariant applies to all four**: `runSystemAction`, `runWindowCommand`,
  `runCustomCommand` and `openQuicklink` (phase 24) are each the one path for both palette activation
  and a global hotkey, so confirmation gates and feature switches cannot be bypassed.
- `runWindowCommand` is small (~10 lines) and has no coordinator of its own. **Leave it on `AppCore`** —
  a coordinator for one method is over-engineering.
- The target-app resolution idiom repeats in three places:
  ```
  windowController.isVisible ? windowController.previousApp : NSWorkspace.shared.frontmostApplication
  ```
  It may be extracted to **one** helper on `PaletteCoordinator`. Do not generalise further.
- All four coordinators present through `AppCore.showNotice` / `confirm` / the message HUD.
  **`DialogController` stays single-owned.**
- `SystemActionCoordinator` keeps `showsVolumeFeedback` as a `static let Set` and the volume/message HUD
  branch exactly as written.
- `UninstallCoordinator.performUninstall` keeps its exact sequence: guard → confirm → quit if running →
  `setTrashing(true)` → trash → `setTrashing(false)` → cleanup → refresh → `prepare(mode: .launcher)` →
  report.
- Code moves verbatim.

## Detailed acceptance criteria

1. All four coordinators exist, are `@MainActor`, and reference no `AppCore.shared`.
2. `AppCore.swift` is under ~300 lines.
3. `grep -c "DialogController()" Tinycast` is 1.
4. `PaletteWindowController` is unchanged.
5. Every palette summon path works: hotkey, menu bar, Dock reopen, "Open Tinycast", command entries.
6. Compact↔expanded still swaps with the top edge anchored.
7. Pop to Root Search still behaves at every timeout setting.
8. Every system action still confirms where it confirmed before, with the same icon.
9. Uninstall end to end, including the post-uninstall reference cleanup and index refresh.
10. Custom commands: confirmation gate, success pill, failure dialog with the shell-environment hint.

## Manual verification checklist

- [ ] `checklists/build.md` including **startup timing**
- [ ] `checklists/testing.md` — `system-action-test`, `uninstall-test`, `custom-command-test`,
      `volume-test`, `window-command-test`
- [ ] `checklists/regression.md` — **the full document**
- [ ] Summon the palette by hotkey, by menu bar, by Dock reopen, and by ⌘-Tab-then-hotkey
- [ ] Compact mode: type to expand → **the top edge does not move**; clear the query → it collapses
- [ ] Toggle compact mode in Settings while the palette is closed → next open is correctly sized
- [ ] Pop to Root: set "Immediately", "After 5 seconds" and "After 30 seconds" → each behaves correctly
- [ ] Open a sub-screen, close the palette, reopen within the timeout → state preserved
- [ ] Restart / Shut Down / Log Out → each confirms with **its own** glyph
- [ ] Quit All → confirms with a count, and quits exactly that set
- [ ] Set Volume → slider dialog → HUD shows the level
- [ ] Volume Up ×3 → HUD animates in place
- [ ] Empty Trash on an empty Trash → "Trash Is Already Empty" pill, not an error
- [ ] Uninstall an app fully → its hotkey, favourite and ranking references are gone; the launcher
      refreshes
- [ ] Custom command with confirmation → runs; with an invalid command → failure dialog; status 127 →
      the "turn on Load Shell Environment" hint appears
- [ ] Hold a bound system-action hotkey → **dialogs do not stack**

## Regression risks

| Risk                                                                       | Mitigation                                                 |
| -------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **Frame ownership splits** and the top edge drifts on the compact swap     | `PaletteWindowController` on the must-not-change list; AC6 |
| A confirmation gate is bypassed from the hotkey path                       | AC8 + the funnel boundary                                  |
| A second `DialogController` appears and held hotkeys stack dialogs         | AC3 + the hold test                                        |
| Pop-to-root state preservation breaks                                      | AC7 at three settings                                      |
| Uninstall's step order changes and cleanup runs before the trash completes | Boundary spells the sequence out                           |
| A coordinator is created for `runWindowCommand`                            | Boundary — leave it on `AppCore`                           |

## Rollback strategy

`git revert <sha>`. Consider four separate commits on one branch, one per coordinator, so a single
problematic extraction can be dropped without losing the other three.

## Expected commit size

5 files, +420 / −380 lines. `AppCore` net −370.

## Suggested commit message

```
Extract the palette, system-action, uninstall and custom-command coordinators

Completes the AppCore decomposition: ~250 lines remain, all of it object
ownership and start() wiring. PaletteWindowController keeps sole ownership
of the frame — the coordinator decides which mode to show, never where or
how big. DialogController stays single-owned so a held hotkey still cannot
stack dialogs. runWindowCommand stays on AppCore; one method does not need
a coordinator.
```

## Dependencies

**Phase 24 (hard).** Blocks 26 and 32.

## Definition of Done

- All acceptance criteria met
- `AppCore` under ~300 lines
- Full regression document walked
- Merged

## Estimated difficulty

**High** by volume.

## Estimated Claude context usage

**High.** Ask for one coordinator at a time within the conversation.

## Notes for reviewers

- **Check `PaletteWindowController.swift` is absent from the diff.** Frame ownership splitting is the
  failure mode that produces the drifting-top-edge bug `AGENTS.md` calls out by name.
- Count `DialogController()` — exactly one.
- The hold-a-hotkey test is quick and catches the dialog-stacking regression that the whole
  `DialogController` design exists to prevent.
- If `AppCore` is still over 350 lines, ask what is left and why. The target is ownership and wiring
  only.
