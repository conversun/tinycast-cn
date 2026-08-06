# Phase 32 kickoff — Retire `AppCore` forwarders, adopt `@Environment`

Read `docs/refactor/phases/32-retire-appcore-forwarders.md` completely.

## Task

Point every call site at its owning coordinator and delete the ~25 forwarders `AppCore` kept as
scaffolding, then replace the 21 view-side `AppCore.shared` reaches with `@Environment`.

## Hard gates

- **`AppCore.shared` remains legitimate in exactly three places:**
  1. `AppDelegate` — the one wiring point
  2. `TinycastApp`'s `MenuBarExtra` menu items — no environment is available in a `Scene`'s menu content
  3. `PaletteWindowController.ensurePanel()` — it _builds_ the environment

  Everywhere else it must go. Do not "fix" these three.

- **A missing `@Environment` injection is a runtime crash, not a compile error.** Enumerate what each
  view needs and confirm it is injected at one of the two injection points
  (`PaletteWindowController.ensurePanel()` and `AppCore.showSettings`).
- **Delete a forwarder only when its last call site has moved.** If one has a remaining caller, keep it
  and name the caller in your summary.
- Do not change any coordinator method's signature to make a call site prettier.
- `armedHover` currently reaches `AppCore.shared.palette.hoverHighlightArmed` from a `View` extension.
  Convert it to take the flag through the environment or as a parameter — **but do not change its
  semantics**: it must still light only on physical pointer movement, never during keyboard-driven
  scrolling under a stationary pointer.
- Do not modify any coordinator implementation, any store, `AppDelegate.swift` or `TinycastApp.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "AppCore.shared" Tinycast     # exactly 3 results, all listed above
```

Run all 17 harnesses.

**Then run the app and open ALL 14 Settings panes, plus About and Onboarding.** This is the phase where
"it builds" is worth the least — `@Environment` failures are runtime, per-view, and invisible until that
exact view is instantiated.

Also: hover a launcher row (highlight appears), then navigate with ↑/↓ so rows slide under a
**stationary** pointer (no highlight must appear).

## Summarise

Use the system-prompt format. Paste the `AppCore.shared` grep output. State `AppCore`'s final line count
— the target is under 250, containing only stored properties, `start()`, `prepareForTermination()`, and
`showNotice`/`confirm`. List every pane you opened.
