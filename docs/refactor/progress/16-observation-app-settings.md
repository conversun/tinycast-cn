# Phase 16 — Observation: `AppSettings`

---

## Status

| Field                         | Value                                              |
| ----------------------------- | -------------------------------------------------- |
| **Status**                    | Complete                                           |
| **Started**                   | 2026-08-05                                         |
| **Completed**                 | 2026-08-05                                         |
| **Operator**                  | abue-ammar                                         |
| **Branch**                    | `refactor/16-observation-app-settings`             |
| **Commit**                    | single commit on the branch                        |
| **Claude conversations used** | 1                                                  |
| **Actual effort**             | ~40 min vs. estimate of L (4–8 h)                  |

---

## Completed tasks

- [x] Objective 1 — `AppSettings` is `@Observable`; `ObservableObject` and all 26 `@Published` are gone
- [x] Objective 2 — every fresh-install default preserved; `init` produces **zero diff lines**
- [x] Objective 3 — all consumers converted: three Combine sink sites and thirteen views

## Acceptance criteria

- [x] AC1 — `@Observable`, no `@Published` — verified by: `grep @Published Tinycast/Core/AppSettings.swift`
      returns nothing; the class declaration and the `defaults` line are the only structural changes
- [x] AC2 — all 25 `Key` constants accounted for — verified by: the `Key` enum is outside the diff
      entirely; the table below lists all 25 against the enum
- [x] AC3 — the absence-vs-`false` checks and every sentinel encoding are byte-identical — verified by:
      `git diff Tinycast/Core/AppSettings.swift` contains **no `init` lines at all**. There are **nine**
      such checks, not the eight the phase document counts — see Deviations
- [x] AC4 — `$settings.x` bindings are the `@Bindable` form — verified by: eight panes converted and the
      build is green, so all 24 binding expressions still resolve. **Write-through not exercised
      interactively**
- [ ] AC5 — every setting persists across relaunch and a clean install takes the intended defaults —
      **not run.** The app was never launched. `@Observable` + `didSet` persistence was proven in a
      standalone `swiftc` harness (quoted below), not in Tinycast
- [ ] AC6 — `windowGap` no longer re-renders the launcher — **not run.** No `_printChanges` pass. The
      mechanism is not in doubt: neither `AppRow` nor `RootPaletteView` reads `windowGap`, and under
      `@Observable` only a read registers
- [x] AC7 — `SettingsBackup` compiles unchanged — verified by: `git diff --name-only | grep SettingsBackup`
      is empty and the Debug build succeeds. Round-trip **not exercised**
- [ ] AC8 — feature-presence reconciliation still fires on every toggle — **not run interactively.** The
      tracking → re-arm → settled-read sequence was harness-tested; see below

### The mechanism, tested rather than assumed

Two things had to be true before a line was written, and neither is visible in a diff:

1. **`@Observable` preserves `didSet`.** A `@MainActor @Observable` class with two `didSet` blocks
   writing `UserDefaults` compiled under `-swift-version 6` and persisted both values. This is the
   phase's central claim and the one that would silently stop every setting persisting.
2. **`withObservationTracking` reproduces the `@Published` timing.** `onChange` fires *before* the
   write lands, exactly like `@Published`, so the deferred `Task` is still what reads the settled
   value. A scratch harness fired twice for two changes, printed the settled value each time, and
   showed an untracked property change firing nothing.

### All 25 keys and their fresh-install defaults

★ marks an absence-vs-stored-`false` check — the "starts **on**" idiom `POLICY.md` carve-out 1 protects.

| #   | Key                              | Fresh install                            |
| --- | -------------------------------- | ---------------------------------------- |
| 1   | `clipboardRetentionDays`         | `integer` 0 matches no case → `.threeMonths` |
| 2   | `clipboardDisabledApps`          | `stringArray` ?? keychainaccess + Passwords |
| 3   | `hyperKeyPhysicalKey`            | `string` ?? `.none`                      |
| 4   | `hyperKeyIncludesShift` ★        | `true`                                   |
| 5   | `hyperKeyQuickPress`             | `string` ?? `.none`                      |
| 6   | `hyperKeyReplacesGlyph` ★        | `true`                                   |
| 7   | `emojiSkinTone`                  | `string` ?? `.none`                      |
| 8   | `popToRootTimeout`               | `integer` 0 → `.immediately`             |
| 9   | `compactMode`                    | `false`                                  |
| 10  | `showFavoritesInCompactMode` ★   | `true`                                   |
| 11  | `launcherSearchScopes`           | `stringArray` ?? `SearchScopes.defaults` |
| 12  | `openOnCursorScreen` ★           | `true`                                   |
| 13  | `customCommandsEnabled`          | `false`                                  |
| 14  | `customCommandsShowInLauncher` ★ | `true`                                   |
| 15  | `snippetsEnabled`                | `false`                                  |
| 16  | `snippetsShowInLauncher` ★       | `true`                                   |
| 17  | `windowManagementEnabled`        | `false`                                  |
| 18  | `windowManagementShowInLauncher` ★ | `true`                                 |
| 19  | `windowManagementGap`            | `integer`, unset reads as 0              |
| 20  | `windowManagementCycleOnRepeat`  | `false`                                  |
| 21  | `quicklinksEnabled`              | `false`                                  |
| 22  | `quicklinksShowInLauncher` ★     | `true`                                   |
| 23  | `quicklinkOpensNewWindow`        | `false`                                  |
| 24  | `quicklinkSelectionFallback`     | `string` ?? `.ask`                       |
| 25  | `quicklinkConfirmsBeforeDelete` ★ | `true`                                  |

`launchAtLogin` has no key — it reads `LaunchAtLogin.isEnabled` and its `didSet` calls
`LaunchAtLogin.set`, a side effect, kept as the phase requires. `SettingsKey.showInMenuBar` stays an
`@AppStorage` key outside `AppSettings`, shared with `TinycastApp`'s `MenuBarExtra`.

### The three sink sites, exactly as changed

| Site                  | Before                                                | After                                                                      |
| --------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------- |
| `AppCore.start()`     | 5 `.sink`s over 8 publishers, `.dropFirst()`, `.store(in: &cancellables)` | 5 `withObservationTracking` scopes through one private `track(_:reproject:)` |
| `AppIndex.start()`    | `$searchScopes.dropFirst().sink`                      | `observeSearchScopes()` — re-arms **before** `await refresh()`             |
| `HyperKeyTap.start()` | `$hyperKey.sink` (no `dropFirst`)                     | explicit `applyKey(settings.hyperKey)` + `observeKey()`                    |

Three details worth recording:

- **`.dropFirst()` disappears with no replacement.** `withObservationTracking` never calls `onChange`
  on registration, so the drop is structural rather than something that had to be re-expressed.
- **`HyperKeyTap` needed the initial call written out.** Its sink had no `dropFirst`, so Combine
  delivered the current value at subscribe time. That is now `applyKey(settings.hyperKey)` on the line
  above the tracking call — the one place where deleting `@Published` removes a real behaviour unless
  it is restored by hand.
- **`MainActor.assumeIsolated` and the deferral `Task` are both kept**, per the phase boundary. The
  task re-arms first, then re-projects, so a scope edit landing during an in-flight scan is still
  observed. Phase 18 removes both wrappers.

`cancellables` is now dead in all three types and was deleted. `import Combine` stays in all three —
each still declares its own `@Published` (`AppIndex.apps`, `HyperKeyTap.status`,
`AppCore.pendingQuicklinkEdit`), which phases 17 and 18 own.

### Consumers converted

| Site                                          | Before             | After                                        |
| --------------------------------------------- | ------------------ | -------------------------------------------- |
| `GeneralSettingsView`, `ClipboardSettingsView`, `CommandsSettingsView`, `EmojiSettingsView`, `SnippetsSettingsView`, `WindowManagementSettingsView`, `QuicklinksSettingsView`, `OnboardingView` | `@ObservedObject` | `@Bindable` (they use `$settings.x`)        |
| `SearchScopesCard`, `RootPaletteView`         | `@ObservedObject`  | `private let` (read/mutate through the reference, no `$`) |
| `LauncherView` `AppRow`, `ShortcutRecorder`   | `@ObservedObject`  | **property deleted**                         |

The last row is the phase's one judgement call, approved before implementing. In both views the
property existed **only** to force invalidation — neither file mentioned `settings` anywhere else.
Their keycaps render through `KeyShortcut.collapsedModifierSymbols`, which reads
`AppCore.shared.settings.hyperKey` / `.hyperKeyReplacesGlyph` / `.hyperKeyIncludesShift` during `body`,
and under `@Observable` those reads register with the view's own tracking scope. The result is strictly
finer-grained: the rows now invalidate on the three Hyper-key properties they actually read instead of
on any of the 25 changing.

No injection site exists for `AppSettings` — every consumer reaches it through `AppCore.shared` — so
phase 11's "the compiler cannot see a missed injection" hazard does not apply to this phase at all.
`PaletteWindowController` only reads `core.settings` and needed no change, despite the phase's file
table anticipating one.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                                                                                                                        |
| -------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | **A pre-phase baseline was captured on this branch** — Debug build before any edit: `BUILD SUCCEEDED`, zero source warnings. After: `BUILD SUCCEEDED`, zero source warnings, with all 16 changed files force-recompiled via `touch` to defeat incremental caching. So "zero *new* warnings" is a measured delta here, not an absolute count. `xcodegen generate` clean, no new file so no `.xcodeproj` churn. Release build, binary size and startup timing not measured |
| `checklists/testing.md`    | PASS    | The three named gates: `callout-test` 30 passed, `scopes-test` PASS ("ALL PASSED"), `volume-test` 81 passed. Also ran `snippets-test` (ALL PASSED) unprompted, because `Tools/snippets-test.swift` carries its own stub `AppSettings` class and was the one harness that could plausibly have noticed this change |
| `checklists/regression.md` | NOT RUN | **Waived by the operator.** The app was never launched: no pane walked, no control toggled, no relaunch, no Dev-channel wipe. AC5, AC6 and AC8 are unexercised, and the wipe-and-relaunch default check — which the phase document calls "the primary check" — did not happen                 |
| `checklists/review.md`     | PASS    | Self-check. §1 scope: 16 files against the phase's expected list; **none from the must-NOT-change list** — `SettingsBackup.swift`, `SearchScopes.swift`, `VolumeLevel.swift`, `DoubleTap*` and `CurrencyRateStore.swift` are all absent from `git diff --name-only`; +108/−111 against an expected +90/−110. §2 no condition, comparison, default, `UserDefaults` key or user-visible string changed; the `init` block has zero diff lines. §3 isolation unchanged — still `@MainActor` throughout, no `@unchecked`, no `nonisolated(unsafe)`; the new `@Sendable @MainActor` closure parameters on `track` are the strictest form that compiles. §4 nothing newly retained; three `Set<AnyCancellable>` removed, one registrar added per instance. §5 comments net −3, stacked blocks +0. §6 `cancellables` deleted in all three types; no import orphaned. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                     | Before | After | Δ                                                                            |
| -------------------------- | ------ | ----- | ---------------------------------------------------------------------------- |
| Binary size (Release)      | —      | —     | not measured                                                                 |
| Clean install verified?    | —      | **no** | the one check this phase most needed; the `init` block is provably byte-identical, which is the static half of the same assurance |
| Cold launch, median of 3   | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()` — the five tracking registrations replace five Combine subscriptions |
| Compiler warnings          | 0      | 0     | measured on this branch, before and after                                    |
| Palette re-renders per settings change | all 25 properties | read-scoped | mechanism verified by inspection, not by `_printChanges` — see AC6 |

This is the phase where M2's invalidation win should become real: `AppSettings` was the widest
invalidation source in the app, and eleven of its thirteen view consumers now track individual
properties. Unmeasured, like every phase since 01.

---

## Failed tasks

none

---

## Issues encountered

- **The phase document says eight absence-vs-`false` checks and lists nine.** Counting both the prompt
  and the phase body: `hyperKeyIncludesShift`, `hyperKeyReplacesGlyph`, `showFavoritesInCompactMode`,
  `openOnCursorScreen`, `customCommandsShowInLauncher`, `snippetsShowInLauncher`,
  `windowManagementShowInLauncher`, `quicklinksShowInLauncher`, `quicklinkConfirmsBeforeDelete` — nine
  names, and `grep -c "== nil" Tinycast/Core/AppSettings.swift` returns 9. All nine are untouched. The
  miscount is in the document, not the code; `POLICY.md` carve-out 1 repeats "eight" and should be
  corrected in the same place.
- **The three new comments were written over the 100-character cap and then rewritten.** The comments
  they replaced were 137–180 characters, so matching the local style would have broken the standing
  contract. Each is now ≤94 characters including indentation.
- **Semicolons were used to compress the paired reads in `track`, then removed.** `grep` for `;` in
  `Tinycast/` finds them only inside `ClipboardStore`'s SQL string literals — the codebase has no
  Swift semicolons at all, and the first draft would have introduced the only three.
- **`@Bindable` works as a stored view property with a default value.** `@Bindable private var settings
  = AppCore.shared.settings` needs no `@Environment` and no `@Bindable var x = x` shadow in `body`,
  which is what phase 11's recipe §3 anticipated. That is only true because `AppSettings` is reached
  through the singleton rather than injected.

---

## Deviations from the phase document

- **Sixteen files, not the ~14 the phase estimates**, and two of them by a different route than the
  file table suggests: `LauncherView` and `ShortcutRecorder` lost their `settings` property outright
  rather than converting it, and `PaletteWindowController` — which the table lists as "if it injects
  settings" — needed no change, because it never did.
- **A private `track(_:reproject:)` helper was added to `AppCore`** rather than writing five
  near-identical `withObservationTracking` methods. It is one private method taking two closures, no
  protocol and no generic parameter, and it keeps the call site as condensed as the
  `for publisher in [...]` loop it replaces. Recorded because the standing prompt bars new abstractions
  and this sits at the boundary of that rule.
- **One behavioural nuance the conversion introduces, by design.** A pair whose two properties are
  written in the *same* main-actor turn — a settings-backup import, say — now re-projects once instead
  of twice, because tracking is disarmed between the first `onChange` and the deferred re-arm. The
  deferred read sees both settled values, so the end state is identical; only the number of
  re-projections differs.
- **Two pre-existing comments had one word corrected** (`publisher` → `observer`) in `AppSettings` and
  `HyperKeyTap`, where they named the mechanism this phase deletes. The standing prompt prefers
  deleting a comment to updating it; both were load-bearing enough to keep.
- **`checklists/regression.md` was not run**, on the operator's instruction, and the phase is recorded
  `Complete` without it — the same disposition as phases 14 and 15. Recorded here rather than silently
  marked PASS.

---

## Follow-up work

| Observation                                                                                                                                                                                                 | Where                                    | Suggested phase |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | --------------- |
| **The clean-install default check never happened.** The phase document calls it the primary check and the only thing that catches a broken absence-vs-`false` conversion. The static substitute is strong — `init` has zero diff lines — but no fresh channel was ever launched | `Core/AppSettings.swift`                 | before merge    |
| **No control was ever toggled.** A dead `@Bindable` binding compiles and looks normal until used; all 24 are unexercised                                                                                     | eight Settings panes                     | before merge    |
| **The three sink conversions are unexercised**: no feature switch toggled, no search scope edited, no Hyper Key changed                                                                                      | `AppCore`, `AppIndex`, `HyperKeyTap`     | before merge    |
| `POLICY.md` carve-out 1, the phase document and `prompts/phase-16.md` all say "eight" absence checks where there are nine                                                                                    | `docs/refactor/POLICY.md`                | 35              |
| `Memo` storage still needs `@ObservationIgnored` when `AppIndex` migrates — flagged by phases 11, 13, 14 and 15, and now unavoidable: 17 migrates that type                                                  | `Core/AppIndex.swift`                    | 17              |
| `AppCore`, `AppIndex` and `HyperKeyTap` still import Combine for their own `@Published`; the `assumeIsolated` + `Task` wrappers in all three tracking sites are phase 18's to remove                          | three files in this diff                 | 17, 18          |
| AC6's `_printChanges` measurement was never taken; the aggregate re-render win stays unquantified                                                                                                            | —                                        | 34              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory observation mechanism only — `UserDefaults` remains
  the source of truth, and every key, default and `didSet` write is identical either side of the
  revert. No migration, no format change, no key rename.
- **Dependent phases that must also be reverted:** none yet. Phases **18** and **33** both list 16 as a
  dependency and must not be started against a reverted 16.
- **Data risk on revert:** none.

---

## Sign-off

- [x] AC1–AC4 and AC7 met; AC5, AC6 and AC8 mechanism-verified but not exercised interactively
- [ ] All four checklists passed — three passed, `regression.md` waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Does not block phase 17.** 17 depends on 09 and 11, both `Complete`, and shares one file with
      this diff (`Core/AppIndex.swift`). This phase left `AppIndex.apps`, its `import Combine` and the
      phase-09 `Memo`/cache storage untouched, so 17 inherits adjacent work and no conflict. **Phase 18
      is unblocked** and inherits the three `assumeIsolated` + `Task` wrappers named above.
