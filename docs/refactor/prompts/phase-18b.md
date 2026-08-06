# Phase 18b kickoff — Observation: the remaining `ObservableObject` types

Read `docs/refactor/phases/18b-observation-remaining-types.md` completely, and follow the
`## The migration recipe` from `docs/refactor/progress/11-observation-pilot-favorites-store.md`.

## Task

Migrate the seven `ObservableObject` types phases 11–18 left behind — `LauncherRankingStore`,
`CustomCommandStore`, `SnippetKeywordListener`, `HyperKeyTap`, `DoubleTapMonitor`, `OnboardingModel`,
`ArgumentValues` — and delete the last `.environmentObject` in the tree.

## Hard gates

- **`LauncherRankingStore.lookup` must be `@ObservationIgnored`.** It is assigned inside
  `boosts(query:)`, which reaches `RootPaletteView.body` through `AppIndex.orderedResults`. Tracked, it
  throws *"Modifying state during view update"* on the first launcher render — and **builds green and
  passes every harness anyway.** This is the defect to avoid.
- **`revision` stays tracked.** `AppIndex`'s memo key reads `ranking.revision` and, on a hit, reads
  nothing else. Ignoring it stalls the launcher list after a visit or a reset.
- **Migrate a harness-compiled type first, then run its harness immediately.**
  `ranking-test`, `custom-command-test` and `snippets-test` each compile one of these files standalone.
  **No command line in `docs/development.md` may change** — `@Observable` needs no import.
- **Event-time state takes `@ObservationIgnored`**: `HyperKeyTap`'s `hyperActive`, `hyperDownAt`,
  `otherKeyPressed`, `key`; `DoubleTapMonitor`'s `detector`. These are written from CGEvent tap
  callbacks on every keystroke.
- **Both `isolated deinit`s stay**, and every field they touch is ignored — `HyperKeyTap.hidConnect`,
  `DoubleTapMonitor.tapPort` / `runLoopSource` / `sessionTokens`. Teardown must not enter the registrar.
  `grep -rn "isolated deinit" Tinycast` must still return **6**.
- **`DoubleTapMonitor.isPaused`'s `didSet` resets the detector — keep it.**
- Retained handles and callbacks take `@ObservationIgnored`: `CustomCommandStore.onChange`,
  `SnippetKeywordListener.observers` / `onMatch` / `healthTicker`, `DoubleTapMonitor.onDoubleTap`,
  `HyperKeyTap.sessionTokens` / `healthTicker`.
- **Amend `AGENTS.md` in the same commit.** Its `CustomCommand.swift` clause names *"Combine for
  `ObservableObject`"* as a required dependency. That stops being true here. Amend the clause; keep the
  invariant, whose real content is "no AppKit, no SwiftUI".
- **Do not touch** `DoubleTapModifier.swift`, `DoubleTapDetector.swift`, `HotKeyCenter.swift`,
  `ShortcutCaptureSession.swift`, `ShellCommandRunner.swift`, `HealthTicker.swift`, or any type migrated
  in phases 11–18.
- **The `NSAlert` in `SnippetArgumentsPrompt` is out of scope** — phase 04's follow-up, not this one.
  Migrate the model, leave `runModal()` alone.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "ObservableObject" Tinycast                                              # must be empty
grep -rn "@Published" Tinycast                                                    # must be empty
grep -rn "@EnvironmentObject\|@ObservedObject\|@StateObject\|environmentObject" Tinycast   # must be empty
grep -rn "import Combine" Tinycast          # must be PermissionsSettingsView.swift alone
grep -rcn "isolated deinit" Tinycast        # must still total 6
```

Run **all** harnesses, with the three gates run first and individually.

**Then run the app**, launch something twice to exercise learned ranking, and **watch the console for
"Modifying state during view update"** — that is what a tracked `lookup` looks like. Open Settings ▸
General, Commands and Snippets; press a Hyper Key and a double-tap binding; expand a snippet with two
`{argument}`s.

## Summarise

Use the system-prompt format. Quote the four greps from AC1–AC4 verbatim, list every field you gave
`@ObservationIgnored` with the reason in three words, and state whether the "Modifying state during view
update" check was actually run or only reasoned about.
