# Phase 20 kickoff — Screens: `quicklinkArguments` and `uninstall`

Read `docs/refactor/phases/20-screens-quicklink-arguments-and-uninstall.md` completely.

## Task

The first two adopters of `PaletteScreen`. Add `QuicklinkArgumentsScreen` and `UninstallScreen`, and
remove those two arms from each of `RootPaletteView`'s eight switches.

## Hard gates

- **`RootPaletteView` keeps its switches for the five un-migrated modes.** A hybrid `RootPaletteView` is
  the expected intermediate state through phases 20–23. Do not migrate anything else.
- **Behaviour is copied verbatim.** Specifically preserve:
  - `quicklinkArguments`: an options argument filters by the field and renders rows; a free-text one
    renders none and keeps selection at 0. ↵ submits. The pill reads "Next" or "Open Quicklink"
    depending on `isLastArgument`. **There is no Actions menu** — `actions(for:)` returns nil.
  - `uninstall`: the filter matches `name` **or** `locationLabel`. The summary string is
    `"N of M files selected · size"`. ⌘↵ toggles unless locked. ↵ calls `performUninstall`. All four
    `state` cases render as today.
- **Every user-visible string is character-identical**, including placeholders and empty states.
- `UninstallActionsMenu` **moves**; its row set and ordering do not change.
- **Leave the `onChange(of: vm.mode)` cleanup in `RootPaletteView`** — the calls to `uninstall.cancel()`
  and `core.cancelQuicklinkArguments()`. Moving lifecycle into screens is phase 23's cleanup.
- Do not touch anything under `Core/Uninstall/` or `Core/Quicklinks/`, or `AppCore.swift`.
- If the protocol needs a sixth member or a changed signature, change it — **but state the reason**.
  Discovering that is part of this phase's job. "It was easier" is not a reason.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff -M    # moved bodies should show as moves, not rewrites
```

Extend `Tools/palette-selection-test.swift` with these two row shapes and run it, plus `quicklink-test`
and `uninstall-test`.

## Summarise

Use the system-prompt format. State `RootPaletteView`'s line count before and after. If you changed the
protocol, quote the change and justify it in two sentences.
