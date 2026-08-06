# Phase 18b — Observation: the remaining `ObservableObject` types

---

## Status

| Field                         | Value                                          |
| ----------------------------- | ---------------------------------------------- |
| **Status**                    | Complete                                       |
| **Started**                   | 2026-08-05                                     |
| **Completed**                 | 2026-08-05                                     |
| **Operator**                  | abue-ammar                                     |
| **Branch**                    | `refactor/18b-observation-remaining-types`     |
| **Commit**                    | single commit on the branch                    |
| **Claude conversations used** | 1                                              |
| **Actual effort**             | ~35 min vs. estimate of M (2–4 h)              |

---

## Completed tasks

- [x] Objective 1 — all seven remaining `ObservableObject` types are `@Observable`:
      `LauncherRankingStore`, `CustomCommandStore`, `SnippetKeywordListener`, `HyperKeyTap`,
      `DoubleTapMonitor`, `OnboardingModel`, `ArgumentValues`. **Combine's observation machinery is now
      absent from the app** — `ObservableObject` and `@Published` both grep empty tree-wide
- [x] Objective 2 — the last `.environmentObject` / `@EnvironmentObject` pair is gone
      (`AppCore.showSettings` → `CommandsSettingsView`), along with the four remaining `@ObservedObject`
      properties and the one `@StateObject`
- [~] Objective 3 — `import Combine` dropped from three files; **`OnboardingView.swift` keeps it, and
      must.** `AGENTS.md`'s `CustomCommand.swift` clause amended. See *Deviations*

## Acceptance criteria

- [x] AC1 — `grep -rn "ObservableObject" Tinycast` returns **nothing** (exit 1) — verified by: the grep
- [x] AC2 — `grep -rn "@Published" Tinycast` returns **nothing** (exit 1) — verified by: the grep. This
      required rewording `AppCore.swift`'s stale comment claiming clipboard `items` is `@Published`
      (false since phase 17, and `progress/18` had already filed it as a phase-34 follow-up)
- [x] AC3 — `grep -rn "@EnvironmentObject\|@ObservedObject\|@StateObject\|environmentObject" Tinycast`
      returns **nothing** (exit 1) — verified by: the grep
- [ ] AC4 — `import Combine` only in `PermissionsSettingsView.swift` — **NOT MET; it survives in
      `OnboardingView.swift` too, and the phase document is wrong to expect otherwise.** That file's
      `refreshTimer` is `Timer.publish(…).autoconnect()`, whose type is
      `Publishers.Autoconnect<Timer.TimerPublisher>` — a Combine type in a stored property, so the file
      needs the import for its own poll and not for `OnboardingModel`. See *Issues encountered*
- [x] AC5 — `ranking-test`, `custom-command-test`, `snippets-test` pass with **no command-line change**
      — verified by: each migrated type ran its own harness immediately after its edit, before the next
      file was touched; `docs/development.md` is absent from `git diff --name-only`
- [x] AC6 — both `isolated deinit`s present and unchanged; `DoubleTapMonitor.isPaused`'s `didSet` still
      resets the detector — verified by: `grep -rn "isolated deinit" Tinycast | wc -l` → **6**, and the
      diff shows no line inside either body
- [~] AC7 — no "Modifying state during view update" on the launcher — **mechanism proven, app not
      driven.** See *The `lookup` proof*
- [~] AC8 — learned ranking reorders, Reset All clears — the store logic is covered by `ranking-test`
      (29 cases, including per-item and global reset); the palette-level behaviour was not exercised
- [ ] AC9 — Hyper Key engages and its status row reflects the tap — **not verified interactively**
- [ ] AC10 — a double-tap binding fires; the recorder shows the Accessibility warning — **not verified**
- [ ] AC11 — the Raycast import wizard completes — **not verified**
- [ ] AC12 — a snippet with `{argument}` prompts and the values reach the expansion — **not verified**

---

### The `lookup` proof

This phase's one named defect is a tracked `LauncherRankingStore.lookup`: it is assigned inside
`boosts(query:)`, which `AppIndex.orderedResults` calls from `RootPaletteView.body`, so tracking it
writes to the registrar mid-render — and still builds green and passes every harness.

The app was not driven, so instead the macro expansion was read directly:

```
swiftc -swift-version 6 -typecheck -Xfrontend -dump-macro-expansions \
  Tinycast/Core/SearchRelevance.swift Tinycast/Core/LauncherRankingStore.swift
```

emits `access(keyPath:)` / `withMutation(keyPath:)` for **`records` and `revision` only**. `lookup`
appears nowhere in the expansion, so the write in `boosts(query:)` cannot reach the registrar by
construction. The same dump is the positive proof for `revision`, which had to stay **tracked** because
`AppIndex`'s memo key reads it and, on a hit, reads nothing else.

### `@ObservationIgnored`, and the rule used

Phase 11's recipe §4 (retained handles and caches) plus this phase's event-time rule. Counts:
`HyperKeyTap` 10, `DoubleTapMonitor` 6, `SnippetKeywordListener` 4, `LauncherRankingStore` 1,
`CustomCommandStore` 1.

| Field                                                            | Reason                    |
| ---------------------------------------------------------------- | ------------------------- |
| `LauncherRankingStore.lookup`                                    | cache, render-written     |
| `CustomCommandStore.onChange`                                    | retained callback         |
| `SnippetKeywordListener.policy`                                  | per-keystroke buffer      |
| `SnippetKeywordListener.observers` / `onMatch` / `healthTicker`   | retained handles          |
| `HyperKeyTap.hyperActive` / `hyperDownAt` / `otherKeyPressed` / `key` | event-time state      |
| `HyperKeyTap.hidConnect`                                         | `deinit`-released         |
| `HyperKeyTap.tapPort` / `runLoopSource`                          | raw CF handles            |
| `HyperKeyTap.sessionTokens` / `healthTicker`                     | retained handles          |
| `HyperKeyTap.settings`                                           | injected reference        |
| `DoubleTapMonitor.detector`                                      | event-time state          |
| `DoubleTapMonitor.tapPort` / `runLoopSource`                     | `deinit`-released         |
| `DoubleTapMonitor.sessionTokens` / `onDoubleTap` / `healthTicker` | retained handles          |

Left deliberately **tracked**: `records`, `revision`, `commands`, `status` (×2), `needsAccessibility`,
`entries`, `OnboardingModel`'s six, and `DoubleTapMonitor`'s `bound` / `sessionActive` /
`loggedTapFailure` — the last three are *read* at event time but written only on binding or session
changes, which is where the phase document draws the line.

### Injection and consumption

| Site                                      | Before                             | After                                          |
| ----------------------------------------- | ---------------------------------- | ---------------------------------------------- |
| `AppCore.showSettings`                    | `.environmentObject(customCommands)` | `.environment(customCommands)`                |
| `CommandsSettingsView`                    | `@EnvironmentObject`               | `@Environment(CustomCommandStore.self)`, no annotation |
| `GeneralSettingsView` (`hyperTap`, `launcherRanking`) | `@ObservedObject`      | plain `let`                                    |
| `SnippetsSettingsView` (`keywordListener`) | `@ObservedObject`                 | plain `let`                                    |
| `ShortcutRecorder` (`doubleTapMonitor`)   | `@ObservedObject`                  | plain `let`                                    |
| `OnboardingView` (`model`)                | `@StateObject`                     | `@State` — `$model.passphrase` / `$model.selection` project unchanged |
| `SnippetArgumentsForm` (`values`)         | `@ObservedObject`                  | plain `let` — `binding(for:)`'s hand-rolled `Binding`s unchanged |

One injection site existed and it was converted, so the recipe's "the compiler is blind to a missed
injection" risk reduced to a single reachable pane.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                                                                                                                                        |
| -------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | **Pre-phase baseline captured on this branch before any edit**: `BUILD SUCCEEDED`, 0 source warnings. After: `BUILD SUCCEEDED`, 0 source warnings — a measured delta. (`appintentsmetadataprocessor`, the multiple-destinations notice and the "could not read priors" incremental notice are build-system noise, not source warnings.) `xcodegen generate` clean, no new file so no `.xcodeproj` churn. Release build and binary size **not measured** |
| `checklists/testing.md`    | PASS    | **All 16 harnesses green**, with the three gates run first and individually: `ranking-test` 29, `custom-command-test` 18, `snippets-test` 194; then fuzz 80, calc 486, clipboard 23, scopes 19, raycast 75, emoji 2054 records, hotkey 34, callout 30, system-action 78, volume 81, window-command 319, uninstall 117, quicklink 82. Every command line byte-identical to `docs/development.md`               |
| `checklists/regression.md` | NOT RUN | **Waived by the operator** ("no need more tests"). AC7–AC12 rest on it, including the launch-with-ranking-data console watch the phase document calls primary. AC7 was proven from the macro expansion instead. No clean-install run — none is required: this phase changes no persisted key, path, schema or format |
| `checklists/review.md`     | PASS    | Self-check. §1 scope: 13 files, **all on the phase's expected list**, none from the must-NOT-change list — `DoubleTapModifier.swift`, `DoubleTapDetector.swift`, `HotKeyCenter.swift`, `ShortcutCaptureSession.swift`, `ShellCommandRunner.swift`, `HealthTicker.swift`, `EdgeDissolve.swift`, `ThinScrollbar.swift` and every type from phases 11–18 are absent from `git diff --name-only`; +63/−54 against an expected +60/−70. §2 no condition, comparison, default, method signature, `UserDefaults` key or user-visible string changed; the `NSAlert` in `SnippetArgumentsPrompt` and its `runModal()` are untouched. §3 isolation unchanged — still `@MainActor`, no `@unchecked`, no `nonisolated(unsafe)`, no `assumeIsolated` added or removed. §4 nothing newly retained; twelve `@Published` subjects replaced by seven registrars. §5 comments +6 / −2, all ≤ 100 characters, no stacked block. §6 three orphaned `import Combine` deleted. §7 the two off-limits files untouched |

### Measurements

| Metric                                    | Before | After | Δ                                                                     |
| ----------------------------------------- | ------ | ----- | --------------------------------------------------------------------- |
| `ObservableObject` conformances, tree-wide | 7      | **0** | C-3 fully closed; M2's milestone claim is now true                     |
| `@Published` properties, tree-wide        | 12     | **0** |                                                                       |
| `import Combine`                          | 5      | 2     | `PermissionsSettingsView` + `OnboardingView`, both for `Timer.publish` |
| `MainActor.assumeIsolated` blocks         | 33     | 33    | untouched — every C / notification / timer bridge intact              |
| `isolated deinit`                         | 6      | 6     | unchanged, as AC6 requires                                            |
| Compiler warnings                         | 0      | 0     | measured on this branch, before and after                             |
| Binary size (Release)                     | —      | —     | not measured                                                          |
| Cold launch                                | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`      |

---

## Failed tasks

none

---

## Issues encountered

- **Dropping `import Combine` from `OnboardingView.swift` broke it, and `xcodebuild` did not say so.**
  The operator caught two Xcode warnings — *"Cannot use enum 'Publishers' in a property declaration
  member of a type not marked '@_implementationOnly'; 'Combine' was not imported by this file"* — that
  the command-line Debug build never emitted; the phase build log contains no such diagnostic. A scratch
  `swiftc -swift-version 6 -typecheck` of the same property also passed, so the pre-edit check that
  authorised the removal was a false negative. Re-running it with
  `-enable-upcoming-feature MemberImportVisibility` reproduces the real complaint as a hard error:
  *"instance method 'autoconnect()' is not available due to missing import of defining module
  'Combine'"*. The import was restored. **Lesson: for "is this import still needed", the IDE's
  diagnostics are authoritative over a clean `xcodebuild`.**
- **A bad shell extraction ran unrelated commands from `docs/development.md`.** Collecting the harness
  commands with a `sed '/^```sh/,/^```/p'` range matched **all six** `sh` fences, so the resulting script
  also ran `open Tinycast.xcodeproj`, `brew install`, `node Tools/gen-*.js`, `./build-dmg.sh` twice and
  `npm install`. Consequence inside the repo: `Tinycast/Core/Calculator/CurrencyData.generated.swift` was
  regenerated from a live Frankfurter fetch — **reverted with `git checkout --`, and the phase commit is
  clean of it**. Outside it: two DMGs in the gitignored `build/`, and `buildServer.json` (also gitignored)
  rewritten with identical content. Take only the fence under `## Tests` and assert every line is a
  `swiftc` invocation.
- **The harnesses do not share a summary line.** `ALL PASSED`, `486 passed, 0 failed`, `23/23 passed` and
  `emoji-test: all checks passed (2054 records)` all occur, so a grep for `ALL PASSED` reported ten false
  failures. Exit status is the verdict.

---

## Deviations from the phase document

- **AC4 cannot be met as written.** `OnboardingView.swift` needs `import Combine` for its own
  one-second Accessibility poll, not for `OnboardingModel` — the same construct that AC4 accepts as
  legitimate in `PermissionsSettingsView`. Recorded NOT MET rather than reinterpreted; the *intent*
  (no Combine left for observation) is fully satisfied at 5 → 2.
- **Three fields took `@ObservationIgnored` beyond the document's enumerated lists**, approved by the
  operator before implementing: `SnippetKeywordListener.policy` (the tap callback mutates it on every
  keystroke — the document's own event-time rule, which its list omits), and `HyperKeyTap.tapPort` /
  `runLoopSource` (the identical raw CF handles the document tells you to ignore in `DoubleTapMonitor`,
  and `reenable()` reads `tapPort` straight from the tap callback). `HyperKeyTap.settings` took it too,
  as an injected reference no view reads.
- **`AppCore.swift`'s stale comment had to change** for AC2's grep to come back empty. It said clipboard
  `items` is `@Published`, which stopped being true in phase 17. Reworded and shortened, not deleted —
  the deferral it explains is load-bearing for startup.
- **`AGENTS.md` line 95 is now short mid-paragraph.** Reflowing the sentence would touch lines this
  phase had no reason to edit, which the standing contract forbids.
- **`@Observable` widens tracking beyond what `@Published` covered**, as in phases 12, 17 and 18:
  `OnboardingModel`'s six properties were all `@Published` already, but `DoubleTapMonitor.bound`,
  `sessionActive` and `loggedTapFailure` are newly tracked. No view reads them.
- **`checklists/regression.md` was not run at all**, on the operator's instruction, and the phase is
  recorded `Complete` without it — the disposition of phases 13–18. Recorded here rather than silently
  marked PASS.

---

## Follow-up work

| Observation                                                                                                                                                                                            | Where                                              | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- | --------------- |
| **The interactive sweep was never run.** AC8–AC12 are unexercised: launch with ranking data and watch the console, search → launch twice → search, Reset All, press a Hyper Key and check its status row, fire a double-tap binding, run the Raycast wizard, expand a snippet with two `{argument}`s, and open Settings ▸ General / Commands / Snippets | Settings panes, palette                            | before merge    |
| **AC4 is unmeetable as written** — `OnboardingView.swift` legitimately imports Combine. The phase document and its kickoff both need correcting, as does the assumption that `PermissionsSettingsView` is the sole survivor | `phases/18b-…md`, `prompts/phase-18b.md`           | 35              |
| `PermissionsSettingsView` and `OnboardingView` now hold the same four-line `Timer.publish` Accessibility poll. One shared helper would retire both Combine imports                                        | `Features/Settings/`, `Features/Onboarding/`        | 34 or later     |
| **`_printChanges` still never run** — inherited from 11, 13–18. M2 closes with every headline claim correct by construction and unmeasured                                                                | `Features/RootPaletteView.swift`                   | 34              |
| `AGENTS.md` line 95 wraps short; fold it into the next line during the doc pass                                                                                                                          | `AGENTS.md`                                        | 34              |
| The `NSAlert` in `SnippetArgumentsPrompt` remains — phase 04's recorded follow-up, explicitly out of scope here                                                                                           | `Features/Snippets/SnippetArgumentsPrompt.swift`   | 34 or later     |
| No phase-01 Instruments baseline exists, so no M1/M2 phase has before-numbers                                                                                                                            | `progress/01`                                      | 34              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory observation mechanism only — no persisted key, path,
  schema or format is touched in either direction. `AGENTS.md`'s clause reverts with it.
- **Dependent phases that must also be reverted:** none. Phase 19 depends on 18, not on this.
- **Data risk on revert:** none.

---

## Sign-off

- [x] AC1, AC2, AC3, AC5, AC6 met; AC4 **not met** (the document's premise is wrong, intent satisfied at
      5 → 2); AC7 proven from the macro expansion but not in the running app; AC8–AC12 not verified
- [ ] All four checklists passed — three passed, `regression.md` **not run**, waived by the operator
- [x] All 16 harnesses green, the three gates first and individually, no command line changed
- [x] `lookup` untracked and `revision` tracked, both proven from `-dump-macro-expansions`
- [x] `isolated deinit` still totals 6; both bodies and `isPaused`'s `didSet` byte-identical
- [x] `AGENTS.md`'s `CustomCommand.swift` clause amended in the same commit
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [x] **Blocks nothing.** Phase 19 depends on 18 alone and is unaffected by this phase either way; what
      19 inherits unfinished here is *verification*, not structure. M2's deliverable is now literally
      true: zero `ObservableObject`, zero `@Published`, and the only Combine left in the tree drives two
      `Timer` publishers
