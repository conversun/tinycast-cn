# Phase 32 — Retire `AppCore` forwarders, adopt `@Environment`

---

## Status

| Field                         | Value                                          |
| ----------------------------- | ---------------------------------------------- |
| **Status**                    | Complete                                       |
| **Started**                   | 2026-08-06                                     |
| **Completed**                 | 2026-08-06                                     |
| **Operator**                  | abue-ammar                                     |
| **Branch**                    | `refactor/32-retire-appcore-forwarders`        |
| **Commit**                    | single commit on the branch                    |
| **Claude conversations used** | 1                                              |
| **Actual effort**             | ~45 min vs. estimate of M (2–4 h)              |

---

## Completed tasks

- [x] Objective 1 — every movable call site addresses its owning coordinator; 45 forwarders deleted
- [x] Objective 2 — all 17 view files that reached `AppCore.shared` now take their dependencies from
      the environment; zero view-side singleton reaches remain
- [~] Objective 3 — the genuinely-global reaches were left alone, but there are **six**, not three,
      and `BackupActions` adds six more. See _Deviations_
- [x] `armedHover` converted to an `ArmedHover` `ViewModifier` reading `@Environment(PaletteState.self)`,
      keeping all seven call sites unchanged and the `hoverHighlightArmed` gate identical
- [x] `AppSettings` and `HotKeyManager` injected at all three window builders; every other store
      reached through the already-injected `AppCore`
- [x] All 58 `@Environment` declarations audited against the three window builders — every one resolves
- [x] Pre-phase warning baseline taken on-branch before any edit (0 warnings)

## Acceptance criteria

- [ ] AC1 — `grep -rn "AppCore.shared" Tinycast` returns exactly three sites — **NOT MET.** Returns
      **12**: `AppDelegate` (3), `TinycastApp` (3), `BackupActions.swift` (6). The phase document
      never enumerates `BackupActions`; retiring its reaches needs either `LauncherCoordinator` edits
      (on the must-NOT-change list) or a default-argument form that hides the coupling from the grep.
      **Left alone by an explicit operator decision taken before implementation began.** Note also that
      the document's legitimate site #3, `PaletteWindowController.ensurePanel()`, does not use
      `AppCore.shared` at all — it receives `core` via `init`
- [~] AC2 — `AppCore` has no forwarding methods — **PARTIAL.** Four remain, each because its only
      callers are on the must-NOT-change list: `showPalette` and `showSettings` (`TinycastApp`'s
      `MenuBarExtra`, `QuicklinkCoordinator`), `hidePalette` (`QuicklinkCoordinator`), `handleReopen`
      (`AppDelegate`). `runWindowCommand` also remains and is **not** a forwarder — it is a real
      implementation, because window management is the one feature with no coordinator
- [~] AC3 — every view compiles and **runs** — **statically verified, not runtime verified.** All 58
      `@Environment` declarations were enumerated and matched against the three window builders
      (`PaletteWindowController.ensurePanel`, `PaletteCoordinator.showSettings`,
      `PaletteCoordinator.showOnboarding`); sheets inherit their presenter's environment. **No pane was
      opened.** This is the phase's stated runtime-only failure mode and it remains unexercised
- [~] AC4 — `armedHover` behaves identically — **met by inspection, not observed.** Same
      `onContinuousHover`, same `hoverHighlightArmed` read, same `.ended` reset; only the flag's source
      moved from the singleton to the environment. **The stationary-pointer test was not performed**
- [ ] AC5 — `AppCore.swift` under ~250 lines — **NOT MET. 319** (from 544, −225). What remains:
      stored properties and coordinator wiring (~95), `start()` (81), `hotKeyDisplayName`,
      `prepareForTermination`, the feature-switch tracking (~50), four retained forwarders,
      `runWindowCommand`, and the five-method dialog façade. The phase document's own arithmetic is
      internally inconsistent here — `−180` in _Why this phase exists_ against `net −60` in
      _Expected commit size_
- [x] AC6 — zero behaviour change — by inspection; no user-visible string, layout, key handler or
      persisted value is in the diff

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                        |
| -------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PARTIAL | **Debug only**, `CODE_SIGNING_ALLOWED=NO`, `BUILD SUCCEEDED`. 0 → 0 compile warnings against an on-branch pre-phase baseline. Release not built                                |
| `checklists/testing.md`    | PASS    | **All 17 harnesses**, `bash -e` exit 0, zero failures (`palette-selection-test` 111,684 / 0; `quicklink-test` 82/82; `snippets-test` ALL PASSED)                              |
| `checklists/regression.md` | NOT RUN | **Waived by the operator**, who declined further testing                                                                                                                       |
| `checklists/review.md`     | PARTIAL | 30 files, +161/−349, all on the phase's expected list. The must-NOT-change list was checked mechanically against `git diff --name-only`: `AppDelegate`, `TinycastApp` and every store are absent. `PaletteCoordinator` **is** in the diff — see _Deviations_. Comment delta 0 |

### Measurements

| Fact                                          | Before | After   | Note                                                     |
| --------------------------------------------- | ------ | ------- | -------------------------------------------------------- |
| `AppCore.swift` lines                         | 544    | **319** | −225; AC5 wanted ~250                                     |
| Forwarding methods on `AppCore`               | 49     | **4**   | 45 deleted; the 4 have non-movable callers                |
| `AppCore.shared` reaches, tree-wide           | 46     | **12**  | AC1 wanted 3                                              |
| View files reaching `AppCore.shared`          | 17     | **0**   | objective 2, fully met                                    |
| `@Environment` declarations                   | 34     | **58**  | all audited against the three window builders             |
| `.environment(…)` injections                  | 21     | **26**  | `AppSettings` ×3 windows, `HotKeyManager` ×2, `AppCore` ×1 |
| Coordinators                                  | 10     | 10      | unchanged; none was modified except as noted              |

---

## Failed tasks

- **AC1 and AC5 were not achievable as written**, and both were known to be unachievable before
  implementation started — they were raised in the plan and the operator accepted the shortfall. See
  _Deviations_ for why each is blocked and _Follow-up work_ for the phase that closes them.

---

## Issues encountered

- **Coordinators are not `@Observable`, so they cannot be injected into `@Environment`.** This is the
  single fact that shapes the phase's outcome. `@Environment(SomeCoordinator.self)` requires
  `Observable` conformance; adding it would modify coordinator implementations, which the phase forbids.
  Views therefore address coordinators as `core.launcherCoordinator.launch(…)` with `AppCore` in the
  environment. This satisfies "point every call site at its owning coordinator" but not the stronger
  reading of "views no longer talk to `AppCore`".

- **The phase's named injection point no longer exists.** The document names
  `AppCore.showSettings` as one of two injection points; phase 25 moved that code into
  `PaletteCoordinator`, which the same document lists as must-NOT-change. Resolved by treating the
  injection-point clause as following the code — see _Deviations_.

- **Twelve `@Bindable var x = x` shims were needed.** Converting
  `@Bindable private var settings = AppCore.shared.settings` to `@Environment(AppSettings.self)` breaks
  `$settings` bindings, which need a local `@Bindable` rebind in each view *member* that uses one — not
  just in `body`. Three panes (`WindowManagement`, `Commands`, `Quicklinks`) and `OnboardingView` keep
  their bindings inside helper computed properties, so each needed its own. Each shim was verified to be
  reachable by a `$`-use before the phase closed. The idiom already existed at `RootPaletteView:381`.

- **An over-captured `awk` ran unrelated commands.** Extracting the `## Tests` fence from
  `docs/development.md` captured the fences after it as well, so a single run executed
  `node Tools/gen-emoji.js`, `node Tools/gen-currencies.js`, `./build-dmg.sh` twice and `npm install`
  before hanging on `npm run dev`. Fallout was contained and verified: `CurrencyData.generated.swift`
  had its date stamp rewritten and was reverted with `git checkout`; `EmojiData.generated.swift`
  regenerated identically; two stray `build/*.dmg` files were deleted; `website/package-lock.json` is
  unmodified. `git status` was re-confirmed to hold exactly the 30 intended files.

---

## Deviations from the phase document

- **`PaletteCoordinator.swift` was edited, and it is on the must-NOT-change list.** The list reads
  "Any coordinator's implementation — this phase changes callers, not callees", while the boundaries
  name `AppCore.showSettings` as an injection point that must gain `.environment(…)` entries. Phase 25
  moved that code into `PaletteCoordinator`, so the two clauses contradict each other. Resolved in
  favour of the injection-point clause, since objective 2 is otherwise unachievable for ten Settings
  views. **The edit is five `.environment(…)` lines across the two aux-window builders and nothing
  else** — no logic, no signature, no method body changed. Raised in the plan and approved before
  implementation.

- **`BackupActions.swift` was deliberately left untouched**, on an explicit operator decision. Two
  alternatives were offered and declined: a required `core` parameter (needs `LauncherCoordinator`
  edits, forbidden this phase) and a `core: AppCore = .shared` default mirroring
  `SettingsBackup.gather`. The second was rejected on the grounds that it makes the AC1 grep pass
  while leaving the coupling intact — a worse outcome than the honest shortfall.

- **`armedHover` became a `ViewModifier` rather than taking a parameter.** The phase allows "through the
  environment or as a parameter". The modifier form was chosen because it changes zero call sites across
  the seven views that use it, so the semantics the phase protects cannot drift at a call site.

- **Stores other than `AppSettings` and `HotKeyManager` are reached as `core.<store>`, not injected.**
  The document's file table names only `@Environment(AppSettings.self)` explicitly. `HotKeyManager` was
  added because `ShortcutRecorder` spans the Settings and Onboarding windows. The six single-consumer
  stores (`hyperKeyTap`, `launcherRanking`, `currencyRates`, `runningApps`, `clipboardStore`,
  `snippetListener`) are read through the already-injected `AppCore`, to keep the diff in the protected
  `PaletteCoordinator` file to a minimum. This is a consistency wart: `ClipboardStore` is an
  `@Environment` object in the palette and a `core.clipboardStore` read in Settings.

---

## Follow-up work

| Observation                                                                                                                                                              | Where                                             | Suggested phase              |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------- | ---------------------------- |
| **The runtime pass was never done.** All 14 Settings panes, About and Onboarding, plus the stationary-pointer hover test. `@Environment` failures are runtime and per-view | —                                                 | before or alongside 32b      |
| `QuicklinkCoordinator` is the only coordinator not handed `paletteCoordinator`; its six siblings take one. That inconsistency alone keeps `showPalette` / `hidePalette` alive | `Features/Quicklinks/UI/QuicklinkCoordinator.swift` | **32b**                      |
| `runWindowCommand` is the only feature action implemented on `AppCore`; window management is the only feature without a coordinator                                        | `App/AppCore.swift`, `Features/WindowManagement/`  | **32b**                      |
| `SettingsBackup.gather(from:)` / `apply(to:)` carry a `= .shared` default that **no caller supplies** — a seam that only hides the coupling from grep                      | `Features/Backup/Model/SettingsBackup.swift`       | **32b**, before 33 freezes it |
| `pendingQuicklinkEdit` is observable state homeless on `AppCore`, because a non-`@Observable` coordinator cannot host it. Wants a `State`-suffixed owner                    | `App/AppCore.swift`                                | undecided — needs a design call |
| AC1 and AC5 as written are unreachable while the must-NOT-change list stands; the document's own line-count arithmetic contradicts itself                                  | `docs/refactor/phases/32-…md`                      | historical record, leave stale |
| `checklists/regression.md:146` still lists phase 30 in its _Clean install_ set — carried from phases 30 and 31, still open                                                 | `docs/refactor/checklists/regression.md`           | fix alongside the next phase |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. No storage, no persisted key, no raw value, no format and no
  behaviour is touched. `xcodegen generate` is not needed — no file was added, removed or renamed, so
  `project.pbxproj` is not in the diff.
- **Dependent phases that must also be reverted:** none. **Phase 33 depends on 16, not on 32**, and 34
  depends on 33, so the roadmap is not blocked by this phase either way. Only the proposed 32b depends
  on it.
- **Data risk on revert:** none.

---

## Sign-off

- [ ] All acceptance criteria met — **three of six.** AC1 and AC5 not met, AC2 partial; AC3 and AC4
      verified statically rather than observed
- [ ] All four checklists passed — **none fully.** `testing.md` PASS (all 17); `build.md` Debug only;
      `regression.md` waived; `review.md` limited to the diff and the must-NOT-change audit
- [x] All 17 harnesses run and passing
- [x] Every `@Environment` declaration audited against its window builder
- [ ] All 14 Settings panes, About and Onboarding opened — **not done**, part of the waived pass
- [ ] Stationary-pointer hover test — **not done**, part of the waived pass
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
