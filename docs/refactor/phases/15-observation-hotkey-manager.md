# Phase 15 — Observation: `HotKeyManager`

**Milestone:** M2 · **Effort:** M · **Risk:** Med · **Context:** Med

> **Compatibility policy applies.** See [`../POLICY.md`](../POLICY.md). The persisted format is not a constraint here; it is
> phase 35's to change.

---

## Overview

The one wave-C case. `HotKeyManager` calls `objectWillChange.send()` manually because its state lives in
`UserDefaults` rather than in a stored property. Phase 06 gave it a real in-memory binding map; this
phase makes that map the observed state.

## Why this phase exists

`objectWillChange.send()` has no `@Observable` equivalent — Observation tracks _property access_, so a
type with no stored state cannot notify anything. This is why phase 06 had to land first, and why this
type gets its own phase rather than riding along in a wave.

## Architecture Review reference

**C-3** wave C · **M-4** · §6.2 K-1

## Objectives

1. Migrate `HotKeyManager` to `@Observable`.
2. Delete the manual `objectWillChange.send()`.
3. Confirm every consumer that re-renders on a binding change still does.

## Expected files to modify

| File                                                       | Change                                                                                   |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `Tinycast/Core/HotKeyManager.swift`                        | `@Observable`; drop `@Published` on `recordingAction`; delete `objectWillChange.send()`. |
| `Tinycast/Core/PaletteWindowController.swift`              | `.environmentObject(core.hotKeys)` → `.environment(…)`.                                  |
| `Tinycast/Features/Launcher/LauncherView.swift`            | `AppRow`'s `@EnvironmentObject private var hotKeys`.                                     |
| `Tinycast/Features/Settings/ShortcutRecorder.swift`        | Consumption.                                                                             |
| `Tinycast/Features/Settings/ShortcutRecorderPopover.swift` | Consumption.                                                                             |

## Files that must NOT change

- `Tinycast/Core/HotKey/HotKeyBinding.swift` — phase 35 changes it, not this phase
- `Tinycast/Core/HotKey/HotKeyCenter.swift`
- `Tinycast/Core/HotKey/DoubleTapMonitor.swift`, `DoubleTapDetector.swift`, `DoubleTapModifier.swift`
- `Tinycast/Core/HotKey/KeyShortcut.swift`
- `Tinycast/Core/Backup/SettingsBackup.swift`

## Implementation boundaries

- **The observed state is the phase-06 binding map.** `setBinding` mutates it; that mutation is what
  notifies. Do not reintroduce a manual notification, and do not add a `revision` counter as a
  workaround — if a view is not updating, the map is not being mutated where it should be.
- `recordingAction`'s `didSet` is load-bearing: it pauses `HotKeyCenter` and `DoubleTapMonitor`, and
  starts/stops `capture`. **Keep the `didSet` exactly.** `@Observable` supports `didSet` on stored
  properties; this is not a case for `withObservationTracking`.
- `capture` (a `ShortcutCaptureSession`, migrated in phase 12) stays a `let`. Views observe it directly.
- `doubleTapMonitor` stays a `let` and is not observed by `HotKeyManager`.
- Persistence, key names and the bound-ID indexes are untouched here — phase 06 settled them and
  phase 35 reshapes them.
- Do not change `conflictOwner`, `candidateActions` or `displayName`. The `AppCore.shared` reach inside
  `displayName` is a known inversion, fixed in **phase 26**, not here.

## Detailed acceptance criteria

1. `HotKeyManager` is `@Observable`; `objectWillChange.send()` appears nowhere.
2. `recordingAction`'s `didSet` is intact and still pauses both engines.
3. A launcher row's keycap chip appears the moment a shortcut is bound in Settings, with the palette
   open on another display or reopened.
4. Clearing a binding removes the keycap.
5. The recorder's own display updates as the binding changes.
6. Bindings survive a quit and relaunch within this build.
7. `SettingsBackup.gather` output is unchanged.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `hotkey-test`
- [ ] `checklists/regression.md` — Core sweep + **Hotkeys** in full
- [ ] Bind a shortcut to an app in Settings ▸ Applications → open the launcher → **the keycap chip is on
      that row**
- [ ] Clear it → reopen the launcher → the chip is gone
- [ ] Start recording → confirm the existing global shortcut does **not** fire while recording
- [ ] Press Escape → recording cancels, the old binding fires again
- [ ] Press plain Delete while recording → the binding is cleared
- [ ] Record a conflicting binding → rejected, owner named
- [ ] Bind a double-tap → it fires
- [ ] Change the Hyper Key ✦ display setting → launcher keycaps re-render
- [ ] Quit and relaunch → every binding still fires
- [ ] Export a settings backup, wipe the Dev channel, import → every binding returns

## Regression risks

| Risk                                                                                                                                       | Mitigation                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| **Launcher keycaps go stale** — the classic symptom of losing the manual notification                                                      | AC3/AC4                                                                   |
| `recordingAction.didSet` is lost, so recording no longer pauses the engines and the shortcut being typed fires the binding it is replacing | AC2 + the "does not fire while recording" check                           |
| A `revision` hack is added instead of observing the map                                                                                    | Boundary + review                                                         |
| The bound-ID indexes drift                                                                                                                 | Covered by phase 06's tests; re-verify by deleting a bound custom command |

## Rollback strategy

`git revert <sha>`. Safe — `UserDefaults` remains the source of truth. No data risk under
[`POLICY.md`](../POLICY.md).

**Note:** if phase 06 is also reverted, revert this first. `ROADMAP.md` records the dependency.

## Expected commit size

5 files, +18 / −22 lines.

## Suggested commit message

```
Migrate HotKeyManager to @Observable

The last manual objectWillChange.send() in the app. Phase 06's in-memory
binding map is now the observed state. recordingAction's didSet — which
pauses both hotkey engines while recording — is unchanged.
```

## Dependencies

**Phase 06 (hard prerequisite)** and phase 11 (recipe). Phase 12 if `ShortcutCaptureSession` moved first.

## Definition of Done

- All acceptance criteria met
- Recording pause behaviour verified explicitly
- Keycap freshness verified in the launcher
- Merged

## Estimated difficulty

**Medium.**

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **The two things that break here are keycap freshness and the recording pause.** Test both by hand;
  neither shows up in a diff read.
- If phase 06 is not merged, stop. Without the in-memory map there is nothing for `@Observable` to
  observe and any solution will be a workaround.
- Confirm `displayName`'s `AppCore.shared` reaches are still present and unchanged — they are phase 26's
  problem, and fixing them here would widen this diff into a second concern.
