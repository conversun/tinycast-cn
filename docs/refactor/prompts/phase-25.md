# Phase 25 kickoff — Palette, SystemAction, Uninstall and CustomCommand coordinators

Read `docs/refactor/phases/25-remaining-coordinators.md` completely.

Extract them **one at a time**, in this order, verifying between each: `PaletteCoordinator`,
`SystemActionCoordinator`, `UninstallCoordinator`, `CustomCommandCoordinator`. Four commits on one
branch is ideal.

## Hard gates

- **`PaletteWindowController` must not appear in the diff.** It solely owns the palette frame —
  `applyCollapsed`, `positionPanel`, `resolveAnchor` and `sizingOptions = []` do not move and are not
  touched. `PaletteCoordinator` decides _which mode to show_; the controller decides _where and how big_.
  Splitting frame ownership produces the drifting-top-edge bug `AGENTS.md` names.
- Pop-to-root (`consumePreservedState`, the timer) stays in `PaletteWindowController`.
- `paletteIsCollapsed` stays the single source of truth for compact vs expanded.
- **The funnel invariant applies to all four**: `runSystemAction`, `runCustomCommand` and
  `runWindowCommand` are each the one path for both palette activation and a global hotkey, so
  confirmation gates and feature switches cannot be bypassed.
- **Leave `runWindowCommand` on `AppCore`.** It is ~10 lines; one method does not need a coordinator.
- The target-app resolution idiom
  (`windowController.isVisible ? windowController.previousApp : NSWorkspace.shared.frontmostApplication`)
  may become **one** helper on `PaletteCoordinator`. Do not generalise further.
- **`DialogController` stays single-owned.** `grep -c "DialogController()" Tinycast` must stay 1.
- `SystemActionCoordinator` keeps `showsVolumeFeedback` as a `static let Set` and the volume/message HUD
  branch as written.
- `UninstallCoordinator.performUninstall` keeps its exact sequence: guard → confirm → quit if running →
  `setTrashing(true)` → trash → `setTrashing(false)` → cleanup → refresh → `prepare(mode: .launcher)` →
  report.
- Code moves verbatim. Keep `AppCore` forwarders; phase 32 deletes them.
- Do not touch `SystemActionRunner`, `SystemAction`, `Core/Uninstall/*`, `CustomCommand`,
  `ShellCommandRunner`, `Core/Dialog/*`, `Core/HUD/*`, or `AboutView.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only | grep PaletteWindowController    # must be empty
grep -c "DialogController()" Tinycast -r                # must be 1
```

Run `system-action-test`, `uninstall-test`, `custom-command-test`, `volume-test`, `window-command-test`.

**Then run the app**: (1) type in compact mode and confirm the top edge does not move; (2) hold a bound
system-action hotkey and confirm dialogs do **not** stack.

## Summarise

Use the system-prompt format. State `AppCore`'s final line count — the target is under 300.
