# Phase 18b — Observation: the remaining `ObservableObject` types

**Milestone:** M2 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

The seven `ObservableObject` types phases 11–18 left behind. Finishing them retires Combine's
observation machinery from the app entirely.

## Why this phase exists

**C-3 scoped the whole tree** — _"26 `ObservableObject` classes, ~120 `@Published` properties, 0 uses of
`@Observable`"_ — but the roadmap enumerated phases 11–18 against a subset and never scheduled the
remainder. M2 therefore closes with seven conformances still live, which makes the milestone's stated
deliverable ("Observation") false and leaves phase 34 unable to report the finding as closed.

None of the seven was deferred for a reason recorded anywhere. They are simply the ones nobody listed.
Five carry a single `@Published` property and one consumer each.

This phase is **not on the critical path.** Phase 19 depends on 18, not on this, and nothing in M3–M7
reads these types' observation mechanism. Run it whenever convenient after 18.

## Architecture Review reference

**C-3** · the balance of it, after waves A–C

## Objectives

1. Migrate all seven remaining `ObservableObject` types to `@Observable`.
2. Delete the last `.environmentObject` / `@EnvironmentObject` / `@ObservedObject` / `@StateObject`
   pair in the tree.
3. Drop `import Combine` wherever it becomes orphaned, and correct the one `AGENTS.md` clause that
   names Combine as a required dependency.

## The seven

| Type                     | File                                          | Tracked state                     | Consumer                                        | Harness      |
| ------------------------ | --------------------------------------------- | --------------------------------- | ----------------------------------------------- | ------------ |
| `LauncherRankingStore`   | `Core/LauncherRankingStore.swift`             | `records`                         | `GeneralSettingsView`                           | `ranking-test` |
| `CustomCommandStore`     | `Core/CustomCommand.swift`                    | `commands`                        | `CommandsSettingsView` + `AppCore.showSettings` | `custom-command-test` |
| `SnippetKeywordListener` | `Core/Snippets/SnippetKeywordListener.swift`  | `status`                          | `SnippetsSettingsView`                          | `snippets-test` |
| `HyperKeyTap`            | `Core/HotKey/HyperKeyTap.swift`               | `status`                          | `GeneralSettingsView`                           | —            |
| `DoubleTapMonitor`       | `Core/HotKey/DoubleTapMonitor.swift`          | `needsAccessibility`              | `ShortcutRecorder`                              | —            |
| `OnboardingModel`        | `Features/Onboarding/OnboardingView.swift`    | 6 properties, two bound two-way   | `OnboardingView` (`@StateObject`)               | —            |
| `ArgumentValues`         | `Features/Snippets/SnippetArgumentsPrompt.swift` | `entries`                      | `SnippetArgumentsForm` (file-private)           | —            |

## Expected files to modify

| File                                                       | Change                                                                             |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `Tinycast/Core/LauncherRankingStore.swift`                 | `@Observable`; `lookup` takes `@ObservationIgnored` — see boundaries.               |
| `Tinycast/Core/CustomCommand.swift`                        | `@Observable`; `onChange` takes `@ObservationIgnored`; drop `import Combine`.        |
| `Tinycast/Core/Snippets/SnippetKeywordListener.swift`      | `@Observable`; drop `import Combine`; handles take `@ObservationIgnored`.            |
| `Tinycast/Core/HotKey/HyperKeyTap.swift`                   | `@Observable`; drop `import Combine`; **hold state and IOKit handles** ignored.      |
| `Tinycast/Core/HotKey/DoubleTapMonitor.swift`              | `@Observable`; **detector and tap handles** ignored; `isPaused`'s `didSet` stays.    |
| `Tinycast/Features/Onboarding/OnboardingView.swift`        | `@Observable`; `@StateObject` → `@State`; drop `import Combine`.                     |
| `Tinycast/Features/Snippets/SnippetArgumentsPrompt.swift`  | `@Observable`; `@ObservedObject` → plain `let`.                                      |
| `Tinycast/Core/AppCore.swift`                              | The last `.environmentObject(self.customCommands)` → `.environment`.                 |
| `Tinycast/Features/Settings/CommandsSettingsView.swift`    | `@EnvironmentObject` → `@Environment(CustomCommandStore.self)`.                       |
| `Tinycast/Features/Settings/GeneralSettingsView.swift`     | Two `@ObservedObject` → plain `let` (both are read-only).                            |
| `Tinycast/Features/Settings/SnippetsSettingsView.swift`    | `@ObservedObject keywordListener` → plain `let`.                                     |
| `Tinycast/Features/Settings/ShortcutRecorder.swift`        | `@ObservedObject doubleTapMonitor` → plain `let`.                                     |
| `AGENTS.md`                                                | The `CustomCommand.swift` clause — see boundaries.                                    |

## Files that must NOT change

- Any type migrated in phases 11–18
- `Tinycast/Core/HotKey/DoubleTapModifier.swift`, `DoubleTapDetector.swift` — pure, harness-compiled,
  and neither is observable
- `Tinycast/Core/HotKey/HotKeyCenter.swift`, `ShortcutCaptureSession.swift` — not observable; their
  `assumeIsolated` blocks bridge Carbon and are load-bearing
- `Tinycast/Core/ShellCommandRunner.swift` — compiled by `custom-command-test`, not observable
- `Tinycast/Core/HealthTicker.swift` — `HealthCheckable` is `AnyObject`; it needs nothing from this
- `Tinycast/Core/EdgeDissolve.swift`, `ThinScrollbar.swift`

## Implementation boundaries

- **Three harnesses gate this phase**: `ranking-test`, `custom-command-test` and `snippets-test` compile
  three of the seven files standalone. Migrate a harness-compiled type **first** and run its harness
  **immediately**, before touching anything else — the hard gate phase 17 used. `@Observable` needs no
  import and no extra source file, so no command line in `docs/development.md` may change.

- **`LauncherRankingStore.lookup` must be `@ObservationIgnored`.** It is a lazily-built cache assigned
  inside `boosts(query:)`, which `AppIndex.orderedResults` calls from `RootPaletteView.body`. Tracked, it
  produces *"Modifying state during view update"* on the first launcher render. This is exactly the trap
  phases 11, 13, 14, 15 and 17 each flagged forward; it is the single most likely defect in this phase.

- **`revision` stays tracked**, in `LauncherRankingStore` as in `VisibilityStore` (13) and `AppIndex`
  (17). `AppIndex`'s memo key reads `ranking.revision` and, on a memo hit, reads *nothing else* — ignoring
  it stalls the launcher list after a visit or a reset.

- **Event-time state must not become a view dependency.** `HyperKeyTap`'s hold state (`hyperActive`,
  `hyperDownAt`, `otherKeyPressed`, `key`) and `DoubleTapMonitor`'s `detector` are written from CGEvent
  tap callbacks — every keystroke, every modifier transition. Tracking them puts a registrar write on the
  keyboard hot path. All of it takes `@ObservationIgnored`. Same rule, same reason, as phase 18's
  `hoverHighlightArmed`.

- **Both `isolated deinit`s stay, and everything they touch is ignored.** `HyperKeyTap.hidConnect` and
  `DoubleTapMonitor`'s `tapPort` / `runLoopSource` / `sessionTokens` are released during teardown, which
  must not enter the registrar. Precedent: phase 17's three SQLite stores.

- **Retained handles and callbacks take `@ObservationIgnored`**, per phase 11's recipe §4:
  `CustomCommandStore.onChange`, `SnippetKeywordListener.observers` / `onMatch` / `healthTicker`,
  `DoubleTapMonitor.onDoubleTap` / `sessionTokens`, `HyperKeyTap.sessionTokens` / `healthTicker`.

- **`DoubleTapMonitor.isPaused`'s `didSet` resets the detector — keep it.** `@Observable` composes with
  property observers (proven in phase 17), and `@ObservationIgnored` leaves a plain stored property, so
  the `didSet` runs either way.

- **`AGENTS.md` has to move in the same commit.** Its Critical Invariants say `Core/CustomCommand.swift`
  must stay *"Foundation plus **Combine for `ObservableObject`** and Darwin for `mkstemp`"*. After this
  phase Combine is no longer needed there — `LauncherRankingStore` already conforms with Foundation
  alone. Amend the clause; do not delete the invariant, whose real content is "no AppKit, no SwiftUI".
  This is a structural rule the refactor is changing, so the precedence ladder permits it.

- **Two consumers bind two-way.** `OnboardingView` has `$model.passphrase` and `$model.selection`;
  `@State private var model = OnboardingModel()` projects those bindings directly for an `@Observable`
  reference type, so no `@Bindable` is needed. `ArgumentValues` hands out hand-rolled `Binding`s from
  `binding(for:)`, which keep working unchanged — its consumer becomes a plain `let`.

- **The `NSAlert` in `SnippetArgumentsPrompt` is out of scope.** It is phase 04's recorded follow-up and
  belongs to whichever phase retires it. Migrate the model; leave `runModal()` alone.

## Detailed acceptance criteria

1. `grep -rn "ObservableObject" Tinycast` returns **nothing**.
2. `grep -rn "@Published" Tinycast` returns **nothing**.
3. `grep -rn "@EnvironmentObject\|@ObservedObject\|@StateObject\|environmentObject" Tinycast` returns
   **nothing**.
4. `grep -rn "import Combine" Tinycast` returns **only** `PermissionsSettingsView.swift`, which uses
   `Timer.publish(…).autoconnect()`.
5. `ranking-test`, `custom-command-test` and `snippets-test` all pass with **no command-line change**.
6. Both `isolated deinit`s are present and unchanged; `DoubleTapMonitor.isPaused`'s `didSet` still resets
   the detector.
7. The launcher renders with **no** "Modifying state during view update" runtime warning, with learned
   ranking data present.
8. Learned ranking still reorders results, and Reset All still clears it.
9. The Hyper Key still engages, and its Settings status row still reflects the tap's state.
10. A double-tap binding still fires, and the recorder still shows the Accessibility warning when the tap
    cannot be created.
11. The Raycast import wizard still completes, with the passphrase field and the selection toggles both
    live.
12. A snippet with `{argument}` still prompts, and the typed values still reach the expansion.

## Manual verification checklist

- [ ] `checklists/build.md` including the warning baseline
- [ ] `checklists/testing.md` — **all 16 harnesses**, with the three gates run first and individually
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons** + **Settings** + **Snippets**
- [ ] **Open the Settings window** and visit General, Commands, Snippets — a missed injection surfaces
      here as a crash, not a compile error
- [ ] Launch with existing ranking data and watch the console: **no** "Modifying state during view update"
- [ ] Search, launch an app twice, search again → it ranks higher. Reset All → it does not
- [ ] Bind a Hyper Key, press it → the chord fires; the Settings status row is correct
- [ ] Bind a double-tap modifier, tap it twice → the action fires
- [ ] Settings ▸ Backup ▸ Import from Raycast → the wizard runs end to end
- [ ] Expand a snippet with two `{argument}`s → both values land

## Regression risks

| Risk                                                                                                | Mitigation                                    |
| ----------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| **`lookup` tracked → "Modifying state during view update"** on every launcher render                | AC7, and the boundary naming it explicitly    |
| A harness stops compiling standalone                                                                | AC5; migrate a gated type first and run it    |
| Event-time state tracked → a registrar write per keystroke                                          | The `@ObservationIgnored` list; AC9, AC10     |
| An `isolated deinit` enters the registrar during teardown                                           | AC6                                           |
| A Settings pane crashes on open from a missed `.environmentObject`                                  | AC3 + opening every affected pane             |
| `revision` ignored → the launcher list stalls after a visit                                         | AC8                                           |

## Rollback strategy

`git revert <sha>`. In-memory observation mechanism only — no persisted key, path, schema or format is
touched. `AGENTS.md`'s clause reverts with it.

## Expected commit size

~13 files, +60 / −70 lines.

## Suggested commit message

```
Migrate the remaining ObservableObject types to @Observable

The seven phases 11-18 left behind: LauncherRankingStore,
CustomCommandStore, SnippetKeywordListener, HyperKeyTap, DoubleTapMonitor,
OnboardingModel and ArgumentValues. Combine's observation machinery is now
gone from the app; the one surviving import drives a Timer publisher.

Caches and event-time state stay untracked: LauncherRankingStore.lookup is
written from a launcher render, and the two taps' hold state is written from
CGEvent callbacks. Both isolated deinits and every retained handle are
untracked for the same reason as the SQLite stores in phase 17.
```

## Dependencies

**Phase 18 (hard)** — for the recipe and to avoid colliding on `AppCore.showSettings`. Blocks nothing:
phase 19 depends on 18, not on this.

## Definition of Done

- All acceptance criteria met
- The three gated harnesses pass with unchanged command lines
- `AGENTS.md`'s `CustomCommand.swift` clause amended
- No "Modifying state during view update" warning with ranking data present
- Merged

## Estimated difficulty

**Medium.** Seven types, but five are one property each. The difficulty is concentrated in two places:
`LauncherRankingStore.lookup`, and knowing which of the two taps' fields are written at event rate.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Check `lookup` first.** If it is not `@ObservationIgnored`, the phase is wrong, and it will still
  build and still pass every harness — the failure is a runtime warning plus an invalidation loop on the
  launcher's hot path.
- Count `@ObservationIgnored` in the two tap files. If either has fewer than five, ask which field was
  judged safe to track and why — the answer should name a field the tap callback never writes.
- `grep -rn "isolated deinit" Tinycast` must still return 6, exactly as before this phase.
- AC1–AC4 are four greps and take under a minute. They are the whole point of the phase: after it, M2's
  claim in the milestone table is finally true.
