# Phase 15 — Observation: `HotKeyManager`

---

## Status

| Field                         | Value                                              |
| ----------------------------- | -------------------------------------------------- |
| **Status**                    | Complete                                           |
| **Started**                   | 2026-08-05                                         |
| **Completed**                 | 2026-08-05                                         |
| **Operator**                  | abue-ammar                                         |
| **Branch**                    | `refactor/15-observation-hotkey-manager`           |
| **Commit**                    | single commit on the branch                        |
| **Claude conversations used** | 1                                                  |
| **Actual effort**             | ~25 min vs. estimate of M (2–4 h)                  |

---

## Completed tasks

- [x] Objective 1 — `HotKeyManager` is `@Observable`; `ObservableObject` and the `@Published` on
      `recordingAction` are gone
- [x] Objective 2 — the manual `objectWillChange.send()` is deleted. It was **the last one in the
      tree**: `grep -rn objectWillChange Tinycast Tools` now returns nothing
- [x] Objective 3 — all six consumers converted, two of them unlisted by the phase document

## Acceptance criteria

- [x] AC1 — `@Observable`, no `objectWillChange` — verified by: the diff, and the tree-wide grep above
- [x] AC2 — `recordingAction`'s `didSet` intact and still pausing both engines — verified by: the diff
      shows the body byte-identical (only the `@Published` attribute on the line above was removed), and
      a scratch harness confirmed the macro preserves `didSet` semantics including the `oldValue` guard.
      Quoted below
- [ ] AC3 — a launcher row's keycap chip appears the moment a shortcut is bound — **mechanism verified,
      not run interactively.** See "The two mechanisms" below
- [ ] AC4 — clearing a binding removes the keycap — **not run interactively.** Same code path as AC3
- [ ] AC5 — the recorder's own display updates as the binding changes — **mechanism verified, not run
      interactively.** The deferred-closure half was the real risk here and was tested; see below
- [x] AC6 — bindings survive quit and relaunch — verified by: no `UserDefaults` read or write appears in
      the diff. `setBinding`'s persistence block, `storedBinding`, the four bound-ID indexes and every
      key constant are untouched. Not exercised by relaunch
- [x] AC7 — `SettingsBackup.gather` output unchanged — verified by: `SettingsBackup.swift` is not in the
      diff, and every `HotKeyManager` member it calls — `binding(for:)`, `boundBundleIDs`,
      `boundPaneBundleIDs`, `boundCustomCommandIDs`, `boundQuicklinkIDs`, `conflictOwner`, `setBinding` —
      is unchanged in signature and in body

### `recordingAction`'s `didSet`, as it stands after the phase

```swift
var recordingAction: HotKeyAction? {
    didSet {
        guard recordingAction != oldValue else { return }
        let recording = recordingAction != nil
        center.isPaused = recording
        doubleTapMonitor.isPaused = recording
        if let recordingAction {
            capture.start(action: recordingAction, hotKeys: self)
        } else {
            capture.stop()
        }
    }
}
```

### The two mechanisms, tested rather than assumed

Both were checked in standalone `swiftc` harnesses, because the phase document's own reviewer note says
neither shows up in a diff read.

1. **`didSet` survives the macro.** A `@MainActor @Observable` class with a `didSet` carrying an
   `oldValue` guard compiled and fired correctly: setting `"a"`, then `"a"` again, then `nil` logged
   `["a", "nil"]` — the redundant set was swallowed by the guard, exactly as the recorder needs.
2. **A private map notifies through a method.** `withObservationTracking` around a
   `binding(for:)`-shaped read fired its `onChange` when a `setBinding`-shaped method mutated the
   private `bindings` dictionary. This is precisely the AC3/AC4 keycap path: `bindings` is `private`,
   and `AppRow` never touches it except through `binding(for:)`.
3. **The recorder callout's deferred reads still track.** `ShortcutRecorderPopoverHost` reads
   `recordingAction` inside `overlayPreferenceValue` → `GeometryReader` → `.animation(_:value:)`, none
   of which is the host's own `body`. Phase 14 established that deferred-closure reads do *not*
   invalidate the outer view, which made this the one place the conversion could plausibly have gone
   quiet. A SwiftUI harness reproducing that exact nesting under `@Observable`, hosted in an offscreen
   `NSHostingView`, rendered the callout on the change. The pattern tracks.

### Consumers converted

| Site                                | Before                                        | After                                        |
| ----------------------------------- | --------------------------------------------- | -------------------------------------------- |
| `PaletteWindowController` `:125`    | `.environmentObject(core.hotKeys)`            | `.environment(core.hotKeys)`                 |
| `LauncherView` `AppRow` `:153`      | `@EnvironmentObject … : HotKeyManager`        | `@Environment(HotKeyManager.self)`           |
| `QuicklinkListView` `QuicklinkRow` `:98` | `@EnvironmentObject … : HotKeyManager`   | `@Environment(HotKeyManager.self)`           |
| `ShortcutRecorder` `:7`             | `@ObservedObject`                             | `private let`                                |
| `ShortcutRecorderPopover` `:72`     | `@ObservedObject`                             | `private let`                                |
| `OnboardingView` `:10`              | `@ObservedObject`                             | `private let`                                |

One injection site, converted. Both `@Environment` consumers are reachable **only** through
`RootPaletteView`, and `grep -rn "RootPaletteView(" Tinycast` returns exactly one instantiation — the
converted one. The other three reach the manager through `AppCore.shared`, so they need no injection.
This matters more than usual: a non-optional `@Environment(T.self)` traps at runtime on a missed
injection rather than reading nil, and the compiler cannot see it.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                                                                                                                     |
| -------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | `xcodegen generate` clean, no new file so no `.xcodeproj` churn. Debug `BUILD SUCCEEDED`, zero errors and zero Swift warnings; the only warning in the log is the pre-existing `appintentsmetadataprocessor` "No AppIntents.framework dependency" notice, which is not from source. **No pre-phase baseline was captured on this branch**, so "zero new warnings" rests on the absolute count being zero rather than on a diff. Release build and binary size not measured |
| `checklists/testing.md`    | PASS    | `hotkey-test` — 34 passed, 0 failed. It is the phase's named gate and compiles `DoubleTapModifier.swift` + `DoubleTapDetector.swift`, both on the must-NOT-change list, so it gates the engines this phase must not disturb rather than the changed file itself                            |
| `checklists/regression.md` | NOT RUN | **Waived by the operator.** No interactive pass: no shortcut was bound or cleared in Settings, the palette was never opened, no recording session was started, and the "existing shortcut must not fire while recording" check was not made. AC3, AC4 and AC5 are unexercised              |
| `checklists/review.md`     | PASS    | Self-check. §1 scope: 7 files, five from the phase's expected list plus two the compiler forced (see Deviations); **none from the must-NOT-change list**, confirmed against `git diff --name-only`; +11/−11 against an expected +18/−22. §2 no condition, comparison, default, method signature or `UserDefaults` key changed; no user-visible string; `conflictOwner`, `candidateActions` and `displayName` untouched in body. §3 isolation unchanged — still `@MainActor`, no `@unchecked`, no `nonisolated(unsafe)`. §4 nothing newly retained; `@Observable` swaps a `Published` subject for a registrar; `capture` and `doubleTapMonitor` stay `let`. §5 comments net +0, stacked blocks +0. §6 nothing orphaned; no import changed. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                   | Before | After | Δ                                                                                             |
| ------------------------ | ------ | ----- | --------------------------------------------------------------------------------------------- |
| Binary size (Release)    | —      | —     | not measured                                                                                  |
| Clean install verified?  | —      | n-a   | no storage change; every hotkey `UserDefaults` key, its JSON-string format and the four bound-ID indexes are untouched |
| Cold launch, median of 3 | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`                             |
| Compiler warnings        | —      | 0     | absolute count, not a measured delta — no pre-phase baseline on this branch                   |

The M2 re-render win is still not measurable from one type. It accrues across 16–18.

---

## Failed tasks

none

---

## Issues encountered

- **`candidateActionsCache` took `@ObservationIgnored`, on the operator's explicit approval.** It is
  cache storage written inside the `candidateActions` getter — the exact shape phase 11's recipe §4
  flags as tripping *"Modifying state during view update"*. No view body reaches it today, so this is a
  latent trap rather than a live bug, and the phase document says not to change `candidateActions`.
  Raised before implementing and approved; recorded here because it is one line beyond the letter of the
  boundary.
- **The `setBinding` doc comment had to be rewritten, not just kept.** It read "…and publishes so the
  launcher and recorders re-render", naming a mechanism this phase deletes. Replaced with a single
  96-character line stating that the `bindings` mutation is what notifies. Net comment lines: 0.
- **`ShortcutRecorder` now mixes three observation styles** — a plain `let` for `hotKeys`, and
  `@ObservedObject` still for `settings` and `doubleTapMonitor`. Correct for this phase (`AppSettings`
  is 16, `DoubleTapMonitor` is on the must-NOT-change list) but it reads oddly until 16 lands.

---

## Deviations from the phase document

- **Seven files, not the five the phase lists.** `Features/Quicklinks/QuicklinkListView.swift` and
  `Features/Onboarding/OnboardingView.swift` both held `HotKeyManager` as `@EnvironmentObject` /
  `@ObservedObject`, which stops compiling the moment the type drops `ObservableObject`. Neither is on
  the must-NOT-change list, and both take the same one-line change as their listed siblings. Phase 11's
  recipe §5 requires a type to migrate with all of its consumers in one commit, so this is not optional.
  The same pattern as phase 14's eighth file.
- **No import changed.** `HotKeyManager.swift` imports Foundation only and never imported Combine;
  `OnboardingView`'s `import Combine` stays, still load-bearing for `Timer.publish`, `@StateObject` and
  `OnboardingModel: ObservableObject`.
- **Diff is +11/−11 against an expected +18/−22**, the same shortfall pattern as phases 11–14.
- **`checklists/regression.md` was not run**, on the operator's instruction, and the phase is recorded
  `Complete` without it. Recorded here rather than silently marked PASS.

---

## Follow-up work

| Observation                                                                                                                                                                    | Where                                        | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- | --------------- |
| **The recording pause was never exercised.** The phase calls this one of the two things that break here: if `didSet` were lost, the shortcut being typed fires the binding it is replacing. The `didSet` is provably unchanged and its semantics were harness-tested, but no key was ever pressed against the real app | `Core/HotKeyManager.swift:16`                | before merge    |
| **Keycap freshness was never observed.** AC3/AC4 rest on a harness reproduction of the notify path, not on a bound shortcut appearing in the launcher                          | `Features/Launcher/LauncherView.swift:168`   | before merge    |
| The remaining checklist items — Escape cancels, plain Delete clears, conflict rejection names the owner, a double-tap fires, Hyper ✦ re-renders, backup export/wipe/import      | —                                            | before merge    |
| `displayName`'s four `AppCore.shared` reaches are present and unchanged, as the phase requires                                                                                 | `Core/HotKeyManager.swift:153`               | 26              |
| `ShortcutRecorder`, `OnboardingView` and `AppRow` still hold `AppSettings` via `@ObservedObject`; phase 16 will revisit all three files                                        | three files in this diff                     | 16              |
| `Memo` storage still needs `@ObservationIgnored` when `AppIndex` migrates, as phases 11, 13 and 14 flagged                                                                     | `Core/AppIndex.swift`                        | 17              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory observation mechanism only — `UserDefaults` remains
  the source of truth and is read and written identically either side of the revert. No migration, no
  format change.
- **Dependent phases that must also be reverted:** none. **Revert this before phase 06** if 06 is ever
  rolled back, per the phase document — without 06's in-memory map there is nothing for `@Observable` to
  observe.
- **Data risk on revert:** none.

---

## Sign-off

- [x] AC1, AC2, AC6, AC7 met; AC3–AC5 mechanism-verified but not exercised interactively
- [ ] All four checklists passed — three passed, `regression.md` not run
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Does not block phase 16.** Phase 16 depends on 11 alone, which is `Complete`. It shares three
      files with this diff (`ShortcutRecorder`, `OnboardingView`, `LauncherView`), all of which will need
      their `AppSettings` `@ObservedObject` converted — this phase left those lines untouched, so there is
      no conflict to resolve, only adjacent work.
