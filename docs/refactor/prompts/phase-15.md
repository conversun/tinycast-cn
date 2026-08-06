# Phase 15 kickoff — Observation: `HotKeyManager`

Read `docs/refactor/phases/15-observation-hotkey-manager.md` completely.

**Prerequisite check:** phase 06 (the in-memory binding cache) must be merged. Without it there is no
stored state for `@Observable` to observe and every solution is a workaround. If it is not merged, stop
and say so.

## Task

Migrate `HotKeyManager` to `@Observable` and delete the manual `objectWillChange.send()`.

## Hard gates

- **The observed state is phase 06's binding map.** `setBinding` mutates it; that mutation is what
  notifies. Do **not** reintroduce a manual notification and do **not** add a `revision` counter as a
  workaround — if a view is not updating, the map is not being mutated where it should be.
- **`recordingAction`'s `didSet` is load-bearing and must survive verbatim.** It pauses `HotKeyCenter`
  and `DoubleTapMonitor` and starts/stops `capture`. Without it, the shortcut being typed fires the
  binding it is replacing. `@Observable` supports `didSet` on stored properties — this is not a case for
  `withObservationTracking`.
- `capture` and `doubleTapMonitor` stay `let` properties. This phase does not touch ownership.
- Persistence, key names and the bound-ID indexes are untouched — phase 06 settled them.
- **Leave `displayName`'s `AppCore.shared` reaches exactly as they are.** They are a known inversion,
  fixed in phase 26. Fixing them here widens this diff into a second concern.
- Do not modify `HotKeyBinding.swift`, `HotKeyCenter.swift`, `DoubleTapMonitor.swift`,
  `DoubleTapDetector.swift`, `DoubleTapModifier.swift`, `KeyShortcut.swift` or `SettingsBackup.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "objectWillChange" Tinycast    # must be empty
```

Run `hotkey-test`.

**Then run the app.** Two things break here and neither shows in a diff:

1. Bind a shortcut in Settings, open the launcher — the keycap chip must appear on that row.
2. Start recording — the existing global shortcut must **not** fire while you type.

## Summarise

Use the system-prompt format. Confirm `recordingAction`'s `didSet` is intact and quote it.
