# Phase 28 kickoff — Extract `Windows/`, `Palette/` and `App/`

Read `docs/refactor/phases/28-extract-windows-palette-and-app.md` completely. The move table in it is
the specification.

## Task

Pure moves, plus three extractions:

- `AuxWindowController` out of `Features/About/AboutView.swift`
- `PaletteViewModel` out of `Core/AppCore.swift`
- `PaletteMode` and `PasteTarget` out of `Core/AppCore.swift`

## Hard gates

- **Moves and cut-and-paste extractions only.** No rewrites, no renames.
- **`PaletteViewModel` keeps its current name here.** It becomes `PaletteState` in phase 30.
- **`PaletteWindowController.swift` contents must be byte-identical.** It is the frame owner.
  `git diff -M` must show it at 100 %.
- `AboutView.swift` keeps `AboutLink` and `AboutLinkRow`; only `AuxWindowController` leaves it.
- **`AuxWindowController`'s `DispatchQueue.main.async` re-assertion of key status must survive the
  extraction.** It exists because `NSApp.activate` from the menu bar is async and the synchronous
  `makeKeyAndOrderFront` can land first. Losing it produces a Settings window that appears but is not
  key — easy to miss, annoying to diagnose.
- `windowWillClose`'s activation-policy restore to `.accessory` must survive.
- **Do not merge `Windows/Dialog/` and `Windows/HUD/`.** They are deliberately separate: a dialog asks,
  a HUD reports, and `AGENTS.md` says a new HUD means a new presenter, not a second shape on an existing
  controller.
- Do not reorganise `Features/` — phase 29.
- Verify no harness references a file moving in this phase before assuming it, then confirm all 17 pass.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release CODE_SIGNING_ALLOWED=NO
git diff -M --stat
xcodegen generate      # twice; stable
```

Run all 17 harnesses.

**Then run the app**: open Settings **from the menu bar** specifically, and confirm the window is key
(you can type in it immediately). Close the last aux window and confirm the Dock icon disappears.

## Summarise

Use the system-prompt format. Confirm `PaletteWindowController.swift` shows 100 % similarity, and quote
the `DispatchQueue.main.async` re-assertion from its new location.
