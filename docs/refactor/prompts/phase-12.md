# Phase 12 kickoff — Observation wave A: sessions and value state

Read `docs/refactor/phases/12-observation-sessions-and-value-state.md` completely, **and read the
`### Migration recipe` section of `docs/refactor/progress/11-observation-pilot-favorites-store.md`**.
Follow that recipe unchanged.

## Task

Migrate four types to `@Observable`, in this order, verifying each before starting the next:

1. `VolumeState`
2. `QuicklinkArgumentSession`
3. `ShortcutCaptureSession`
4. `UninstallSession`

## Hard gates

- **`VolumeState` must NOT gain `@MainActor`.** Two different controllers construct it and the HUD
  observes it across a fade animation. Leave its isolation exactly as it is.
- `UninstallSession.state`'s `Equatable` conformance suppresses redundant updates — keep it.
- `ShortcutCaptureSession` stays a `let` on `HotKeyManager`. Its consumers reach it via
  `AppCore.shared.hotKeys.capture`; **leave that reach in place**, phase 32 addresses it.
- **Do not migrate `HotKeyManager`.** That is phase 15 and it has a hard prerequisite.
- Do not change any property's access control, type or name.
- Do not touch the pure uninstall files or `UninstallScanner.swift`.
- Do not touch `VolumeLevel.swift` — harness-compiled.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run `volume-test`, `uninstall-test`, `quicklink-test`, `hotkey-test`.

**Then run the app** and exercise: the Set Volume slider, a two-argument quicklink prompt, a shortcut
recorder showing held modifiers, and an uninstall scan's state transitions. The shortcut recorder is the
highest-frequency observable in the app — if it lags or stops updating, that is the regression.

## Summarise

Use the system-prompt format. Note any deviation from the phase-11 recipe and why. If one of the four
types proved problematic, say so — dropping it to a follow-up phase is a legitimate outcome.
