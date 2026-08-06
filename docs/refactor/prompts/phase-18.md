# Phase 18 kickoff — Observation: palette, `AppCore`, retire the Combine sinks

Read `docs/refactor/phases/18-observation-palette-core-and-combine.md` completely.

## Task

Migrate `PaletteViewModel` and `AppCore` to `@Observable`, replace the eight `settings.$…` sinks with
`withObservationTracking`, and delete the deferral `Task`s and `assumeIsolated` blocks those sinks
required.

## Hard gates

- **`withObservationTracking`'s `onChange` is a ONE-SHOT.** A naive conversion works perfectly the first
  time and then silently stops. Use a helper that **re-arms** after each change. This is the single most
  likely bug in this phase and nothing but toggling a switch twice will catch it.
- **Only the eight Combine-bridging `assumeIsolated` blocks are removed.** The ones bridging Carbon
  handlers, CGEvent taps, `DispatchSource` handlers, `Timer` blocks and `NotificationCenter` blocks are
  correct and load-bearing. Count them before and after:
  ```
  grep -rc "assumeIsolated" Tinycast --include=*.swift | awk -F: '{s+=$2} END {print s}'
  ```
  **The delta must be exactly 8.** More means you deleted a tap or timer bridge.
- **`hoverHighlightArmed` and `menuOpen` must be `@ObservationIgnored`.** They are deliberately not
  `@Published` today because they are read at event time and must never drive a re-render. Tracking them
  re-renders the palette on every mouse move.
- `menuOpen`'s `didSet` fires `onMenuOpenChanged` — keep it.
- `PalettePanel.paletteViewModel` stays `weak`, and its `didSet` installing the caret hook stays.
- `AppCore.pendingQuicklinkEdit` binds to a `.sheet(item:)` — convert to `@Bindable`.
- **Do not touch** the one-shot `Task { … }` calls in `start()` for `clipboardStore.load()`,
  `appIndex.refresh()` and `emojiIndex.load()`. Those are launches, not sinks.
- Do not modify `SnippetKeywordListener.swift`, `DoubleTapMonitor.swift`, `HotKeyCenter.swift`,
  `RunningApps.swift` or `SnippetsStore.swift` — their `assumeIsolated` blocks are C/notification
  bridges.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "cancellables" Tinycast     # must be empty
```

Run **all** harnesses.

**Then run the app and toggle each of these TWICE**, confirming the launcher reacts both times: custom
commands, snippets, window management, quicklinks, each "show in launcher" companion, search scopes, and
the Hyper Key. Once-only reaction means the tracking did not re-arm.

## Summarise

Use the system-prompt format. State the `assumeIsolated` count before and after. Describe the re-arming
mechanism you used, in two sentences.
