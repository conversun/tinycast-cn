# Phase 32b kickoff — Close the `AppCore` residue

Read `docs/refactor/phases/32b-appcore-residue.md` completely.

## Task

Three survivors of phase 32, one finding — `AppCore` still owns what comparable types own for
themselves. Hand `QuicklinkCoordinator` a `paletteCoordinator`, extract `WindowCommandCoordinator`, and
make `core` a required parameter on the two backup types.

## Hard gates

- **`AppCore.shared` survives in exactly two files:** `AppDelegate` and `TinycastApp`'s `MenuBarExtra`
  menu items. Six results total. Do not "fix" those.
- **`runWindowCommand` moves verbatim and stays ONE funnel.** The `windowManagementEnabled` guard and
  the hide-then-move focus dance move with it, unchanged. Both callers — the hotkey closure in
  `AppCore.start` and `LauncherCoordinator`'s `.windowCommand` branch — go through the one method. A
  shortcut stays registered while the feature is off and must move nothing.
- **`WindowCommandCoordinator` is effectful.** It sits flat in `Features/WindowManagement/` beside
  `WindowMover.swift`. Never in a `Model/` folder, never added to `Tools/window-command-test.swift`.
- **Do not add a `= .shared` default to `BackupActions`.** Deleting the two that already exist on
  `SettingsBackup.gather` / `apply` is objective 3. A default argument that hides the coupling from grep
  is the failure mode this phase removes.
- `QuicklinkCoordinator` keeps its `core` reference for the dialog façade and `pendingQuicklinkEdit`.
  Only the two palette calls move.
- Do not modify `PaletteCoordinator`, `WindowMover`, `AppDelegate.swift` or `TinycastApp.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "AppCore.shared" Tinycast              # exactly 6, in AppDelegate and TinycastApp only
grep -rn "core\.showPalette\|core\.hidePalette" Tinycast   # empty
grep -rc "func runWindowCommand" Tinycast       # 1
grep -n "= .shared" Tinycast/Features/Backup/Model/SettingsBackup.swift   # empty
```

Run all 17 harnesses. `window-command-test` and `quicklink-test` are the named gates.

**Then run the app.** Fire every window command from the launcher and from its global hotkey, and
confirm the same target window, the same focus restoration. **Turn window management off and fire a
still-bound window-command hotkey — nothing may move.** Exercise a quicklink with an argument, a
quicklink edit from the palette, a settings export → import round-trip, and a Raycast import from
**both** the Backup pane and Onboarding.

## Summarise

Use the system-prompt format. Paste the four greps above. State `AppCore`'s final line count — the
target is under 280, containing only stored properties, `start()`, `prepareForTermination()`,
`handleReopen()`, `showSettings()` and the dialog façade. Confirm the coordinator count is 11.
