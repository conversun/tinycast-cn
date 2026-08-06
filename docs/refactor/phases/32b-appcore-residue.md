# Phase 32b — Close the `AppCore` residue

**Milestone:** M6 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

Phase 32 moved every view off `AppCore` and deleted 45 forwarders. Three things survived it, each for a
different reason, and all three are the same finding: `AppCore` still owns something every comparable
type owns for itself. Close them together.

## Why this phase exists

Each survivor is load-bearing for a claim the refactor has already published:

1. **`QuicklinkCoordinator` is the only coordinator not handed `paletteCoordinator`.** Its six siblings
   take one; it takes `core` and reaches `core.showPalette` / `core.hidePalette`. Those two forwarders
   exist *solely* to serve that one caller — the inconsistency is what keeps them alive.
2. **`runWindowCommand` is the only feature action still implemented on `AppCore`.** Phase 25b's
   recorded note claims "`AppCore` orchestrates no feature". That is not literally true while this
   method exists, and window management is the one feature with no coordinator.
3. **`SettingsBackup.gather(from:)` / `apply(to:)` carry a `= .shared` default no caller ever supplies**,
   while its sibling `BackupActions` reaches `AppCore.shared` six times outright. Same coupling, two
   spellings — and the default form defeats the grep that is supposed to measure it.

Nothing else in the roadmap picks these up: phase 33 puts `gather`/`apply` on its own must-NOT-change
list, phase 35 touches `SettingsBackup` only for a comment, and no phase mentions window management.

## Architecture Review reference

**C-1** · **§2.3** · Roadmap W7.3 — the residue phase 32 could not reach without crossing its own
boundaries.

## Objectives

1. Hand `QuicklinkCoordinator` a `paletteCoordinator`, like its six siblings; delete the `showPalette`
   and `hidePalette` forwarders.
2. Extract `WindowCommandCoordinator`; delete `runWindowCommand` from `AppCore`.
3. Make `core` a **required** parameter on `SettingsBackup.gather` / `apply` and on the three
   `BackupActions` entry points that need it.

## Expected files to modify

| File                                             | Change                                                                                |
| ------------------------------------------------ | ------------------------------------------------------------------------------------- |
| `App/AppCore.swift`                              | Delete `showPalette`, `hidePalette`, `runWindowCommand`; wire the new coordinator.    |
| `Features/Quicklinks/UI/QuicklinkCoordinator.swift` | Take `paletteCoordinator`; call it instead of `core` for show/hide.                |
| `Features/WindowManagement/WindowCommandCoordinator.swift` | **New.** The one funnel, moved verbatim.                                    |
| `Features/Launcher/UI/LauncherCoordinator.swift` | Take `windowCommandCoordinator`; call it at the `.windowCommand` branch.              |
| `Features/Backup/Model/SettingsBackup.swift`     | Drop both `= .shared` defaults.                                                       |
| `Features/Backup/Service/BackupActions.swift`    | Take `core`; delete all six `AppCore.shared` reaches.                                 |
| `Features/Backup/Settings/BackupSettingsView.swift` | Pass `core` (already `@Environment`).                                              |
| `Features/Onboarding/OnboardingView.swift`       | Pass `core` (already `@Environment`).                                                 |

## Files that must NOT change

- `App/TinycastApp.swift` and `App/AppDelegate.swift` — their `AppCore.shared` reaches are the two
  genuinely environment-less sites and are correct
- `Palette/PaletteCoordinator.swift` — this phase changes its callers, not it
- `Features/WindowManagement/WindowCommand.swift`, `WindowLayout.swift`, `WindowActionMemory.swift` —
  Foundation + CoreGraphics and pure, for `Tools/window-command-test.swift`
- `Features/WindowManagement/WindowMover.swift` — the AX layer; the coordinator calls it unchanged
- `Features/Backup/Model/Raycast*.swift` — external format (POLICY carve-out 3)
- `DesignSystem/Scrolling/EdgeDissolve.swift`, `ThinScrollbar.swift` — off-limits by `AGENTS.md`

## Implementation boundaries

- **`runWindowCommand` moves verbatim and stays ONE funnel.** The `guard settings.windowManagementEnabled`
  and the hide-then-move focus dance move with it, unchanged. A shortcut stays registered while the
  feature is off and must move nothing — splitting the funnel per caller reopens exactly the bypass
  phase 25b's risk table flags. Both callers (the hotkey closure in `AppCore.start` and
  `LauncherCoordinator`'s `.windowCommand` branch) go through the one method.
- **`WindowCommandCoordinator` is effectful and stays out of the harness set.** It sits flat in
  `Features/WindowManagement/`, alongside `WindowMover.swift` — never in a `Model/` folder, and never
  added to `Tools/window-command-test.swift`'s compile line.
- **No new lazy cycle.** `quicklinkCoordinator` → `paletteCoordinator` → `windowController` is acyclic;
  `PaletteCoordinator` must not gain a reference to `QuicklinkCoordinator` to compensate.
- `QuicklinkCoordinator` keeps its `core` reference — it still needs the dialog façade
  (`showNotice`/`confirm`/`reportFailure`/`showMessage`) and `pendingQuicklinkEdit`. Only the two
  palette calls move.
- **Delete the defaults, do not relocate them.** `gather(from core: AppCore)` and `apply(to core: AppCore)`
  take a required argument. Do not add a `= .shared` default to `BackupActions` to make the grep pass —
  that is the failure mode this phase exists to remove.
- Do not change any coordinator method's signature beyond the injections named above.

## Detailed acceptance criteria

1. `grep -rn "AppCore.shared" Tinycast` returns **exactly six** results: `AppDelegate` (3),
   `TinycastApp` (3). No other file appears.
2. `AppCore` implements **no feature action**. Its remaining surface is stored properties, `start()`,
   `prepareForTermination()`, `handleReopen()`, `showSettings()`, and the five-method dialog façade.
3. `grep -rn "core\.showPalette\|core\.hidePalette" Tinycast` returns nothing — no coordinator reaches
   palette control through `AppCore`.
4. Coordinator count is 11. Every coordinator that needs palette control is handed `paletteCoordinator`
   at construction.
5. `grep -c "func runWindowCommand" Tinycast` is 1, and the `windowManagementEnabled` guard is inside it.
6. Neither `gather` nor `apply` has a default argument; `BackupActions` contains no `AppCore.shared`.
7. `AppCore.swift` is under 280 lines.
8. Zero behaviour change.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — all 17, with `window-command-test` and `quicklink-test` called out
- [ ] `checklists/regression.md`
- [ ] Every window command from the launcher **and** from its global hotkey — same result, same focus
      restoration, same target window
- [ ] Turn window management **off**, then fire a still-registered window-command hotkey → nothing moves
- [ ] Quicklink with an argument: palette shows the argument screen, submits, opens
- [ ] Quicklink edit from the palette → Settings opens on the Quicklinks tab with the editor up
- [ ] Settings export → import round-trips
- [ ] Raycast import from **both** the Backup pane and Onboarding

## Regression risks

| Risk                                                                     | Mitigation                                            |
| ------------------------------------------------------------------------ | ----------------------------------------------------- |
| The window-command funnel is split per caller, bypassing the feature switch | AC5 + the feature-off hotkey test                   |
| A lazy-init cycle between the quicklink and palette coordinators          | Boundary: the graph is acyclic; `PaletteCoordinator` gains nothing |
| `WindowCommandCoordinator` lands in `Model/` and breaks harness purity    | Boundary + `window-command-test`                      |
| A `= .shared` default is added to `BackupActions` to make the grep pass   | AC6 names it explicitly                               |
| Raycast import breaks in Onboarding but not the Backup pane, or vice versa | Both paths in the manual checklist                   |

## Rollback strategy

`git revert <sha>`.

## Expected commit size

~8 files, +90 / −80 lines. One new file. `AppCore` net −45 (319 → ~275).

## Suggested commit message

```
Close the AppCore residue left by phase 32

Three survivors, one finding: AppCore still owned what comparable types
own for themselves. QuicklinkCoordinator now takes a paletteCoordinator
like its six siblings, so the showPalette/hidePalette forwarders go.
runWindowCommand becomes WindowCommandCoordinator, the eleventh, so no
feature action is implemented on AppCore. SettingsBackup and
BackupActions take core as a required parameter, retiring a default
argument no caller ever supplied.
```

## Dependencies

**Phase 32 (hard).** This phase deletes what 32 could not reach without crossing its own
must-NOT-change boundaries.

**Run before phase 33.** Phase 33 freezes `gather`/`apply` and adds a harness against them; changing
their signatures afterwards fights that boundary, and 33's new harness should be written against the
final shape.

## Definition of Done

- All acceptance criteria met
- The feature-off window-command hotkey test passed
- Both Raycast import paths exercised
- Merged

## Estimated difficulty

**Low–Medium.** Three independent, small changes; the only real hazard is the window-command funnel.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- The grep in AC1 is the point of the third objective. If it returns more than six, or if it returns six
  because a default argument moved the coupling out of sight, the phase has failed.
- `runWindowCommand` should be diff-readable as a **move**. If its body changed, ask why.
- Watch for `pendingQuicklinkEdit`. It stays on `AppCore` this phase and that is deliberate — it is
  observable state a non-`@Observable` coordinator cannot host. It is the one honest remaining wart and
  it wants a `State`-suffixed home, which is a separate decision, not this phase's.
