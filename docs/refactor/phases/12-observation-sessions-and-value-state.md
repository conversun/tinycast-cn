# Phase 12 — Observation wave A: sessions and value state

**Milestone:** M2 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

Migrate the four short-lived, single-purpose observable types: `VolumeState`,
`QuicklinkArgumentSession`, `ShortcutCaptureSession`, `UninstallSession`.

## Why this phase exists

These four hold state for one in-progress flow rather than persisted data. They have no manual
`objectWillChange`, no cross-store fan-out, and few consumers — which makes them the safest group to
migrate after the pilot, and a good check that the recipe generalises beyond a plain store.

## Architecture Review reference

**C-3** · Roadmap W2 wave A

## Objectives

Migrate, in this order, verifying each before starting the next:

1. `VolumeState` — 14 lines, 2 properties, consumed by `VolumeSlider` and `VolumeHUDView`
2. `QuicklinkArgumentSession` — consumed by `RootPaletteView` and `QuicklinkArgumentsView`
3. `ShortcutCaptureSession` — consumed by `ShortcutRecorder` / `ShortcutRecorderPopover`
4. `UninstallSession` — consumed by `RootPaletteView` and `UninstallView`

## Expected files to modify

| File                                                        | Change                                  |
| ----------------------------------------------------------- | --------------------------------------- |
| `Tinycast/Core/VolumeState.swift`                           | `@Observable`.                          |
| `Tinycast/Core/Quicklinks/QuicklinkArgumentSession.swift`   | `@Observable`.                          |
| `Tinycast/Core/HotKey/ShortcutCaptureSession.swift`         | `@Observable`.                          |
| `Tinycast/Core/Uninstall/UninstallSession.swift`            | `@Observable`.                          |
| `Tinycast/Features/Dialog/VolumeSlider.swift`               | `@ObservedObject` → plain `let`.        |
| `Tinycast/Features/HUD/VolumeHUDView.swift`                 | Same.                                   |
| `Tinycast/Features/Quicklinks/QuicklinkArgumentsView.swift` | `@EnvironmentObject` → `@Environment`.  |
| `Tinycast/Features/Uninstall/UninstallView.swift`           | Same.                                   |
| `Tinycast/Features/Settings/ShortcutRecorder.swift`         | Consumption updated.                    |
| `Tinycast/Features/Settings/ShortcutRecorderPopover.swift`  | Consumption updated.                    |
| `Tinycast/Features/RootPaletteView.swift`                   | Two `@EnvironmentObject`s converted.    |
| `Tinycast/Core/PaletteWindowController.swift`               | Two injection sites converted.          |
| `Tinycast/Core/Dialog/DialogController.swift`               | Only where it constructs `VolumeState`. |

## Files that must NOT change

- Any store not in the list of four
- `Tinycast/Core/HotKeyManager.swift` — it _owns_ `ShortcutCaptureSession` but is migrated in phase 15
- `Tinycast/Core/Uninstall/UninstallScanner.swift` and the five pure uninstall files
- `Tinycast/Core/VolumeLevel.swift` — harness-compiled, and not observable

## Implementation boundaries

- Follow the recipe recorded in phase 11's progress file, unchanged. If a type needs a deviation, note
  it and say why.
- `VolumeState` is the one type here that is **not** `@MainActor`. Keep it that way — `DialogController`
  and `VolumeHUDController` both construct it and the HUD observes it across a fade. Do not add
  isolation it did not have.
- `UninstallSession.state` is an `enum` carrying an `UninstallPlan`. Its `Equatable` conformance is what
  suppresses redundant updates today; keep it.
- `ShortcutCaptureSession` is held by `HotKeyManager` as a `let` and read by views. Its consumers reach
  it via `AppCore.shared.hotKeys.capture` today — leave that reach in place; phase 32 addresses it.
- Do not change any published property's access control, type or name.
- Do not migrate `HotKeyManager` itself. That is phase 15 and it has a hard prerequisite.

## Detailed acceptance criteria

1. All four types are `@Observable`; none retains `ObservableObject` or `@Published`.
2. Every consumer compiles without an optional `@Environment` lookup.
3. The volume dialog's slider tracks a drag and updates the readout live.
4. The volume HUD animates its bar in place on a repeat command rather than replaying the entrance.
5. The quicklink argument prompt advances through arguments and steps back on Backspace.
6. The shortcut recorder shows held modifiers live and flashes a conflict for ~1.5 s.
7. The uninstall screen transitions idle → scanning → ready, and the checkbox toggles update the summary
   line.
8. No other type's observation mechanism changed.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `volume-test`, `uninstall-test`, `quicklink-test`, `hotkey-test`
- [ ] `checklists/regression.md` — Core sweep + **Uninstall** + **Quicklinks** + **Hotkeys** +
      **System actions & window management**
- [ ] Run "Set Volume": drag the slider — the number tracks; ←/→ step it; ↵ applies
- [ ] Trigger Volume Up three times quickly — the HUD bar slides, it does not re-enter each time
- [ ] Open a quicklink with two `{argument}`s — both prompts appear in order; Backspace refills the first
- [ ] Record a shortcut — modifiers appear live in the callout as you hold them
- [ ] Record a conflicting shortcut — the conflict message names the owner and clears after ~1.5 s
- [ ] Uninstall an app — placeholder → list; toggling a checkbox updates "N of M files selected · size"
- [ ] Escape mid-scan — the screen closes and the session resets

## Regression risks

| Risk                                                                       | Mitigation                                                            |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| The recorder callout stops updating as modifiers are held                  | AC6 — this is the most timing-sensitive observation in the app        |
| The volume HUD re-enters instead of animating in place                     | AC4 — `VolumeHUDController` relies on the view observing shared state |
| The uninstall summary line goes stale on toggle                            | AC7                                                                   |
| `VolumeState` gains `@MainActor` and breaks the HUD's cross-controller use | Explicit boundary                                                     |
| The argument prompt loses its per-argument re-render                       | AC5                                                                   |

## Rollback strategy

`git revert <sha>`. All four types are in-memory session state; nothing persists.

**If a single type of the four is problematic**, it is legitimate to drop it from this phase and give it
its own follow-up phase. Record that in the progress file and update `ROADMAP.md`.

## Expected commit size

13 files, +45 / −50 lines.

## Suggested commit message

```
Migrate the session and value-state types to @Observable

VolumeState, QuicklinkArgumentSession, ShortcutCaptureSession and
UninstallSession — four short-lived types with no manual objectWillChange
and few consumers. Follows the phase-11 recipe.
```

## Dependencies

Phase 11 (the recipe).

## Definition of Done

- All acceptance criteria met
- All four interactive flows verified by hand
- Any recipe deviations recorded
- Merged

## Estimated difficulty

**Low–Medium.** Four small types; the recorder is the only fiddly one.

## Estimated Claude context usage

**Medium** — 13 files, but most are one-line edits.

## Notes for reviewers

- The shortcut recorder is the highest-frequency observable in the app: `heldModifiers` updates on every
  `flagsChanged`. If it lags or stops updating, that is the regression to catch.
- Check `VolumeState` did **not** gain `@MainActor`. Two different controllers construct it and the HUD
  observes it while a fade animation runs.
- Confirm `PaletteWindowController` converted exactly two of its injection calls.
- If a type was dropped from the phase, make sure `ROADMAP.md` records the new follow-up phase rather
  than leaving it implicit.
