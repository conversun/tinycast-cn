# Phase 29 — Feature folders and the Settings shell

---

## Status

| Field                         | Value                              |
| ----------------------------- | ---------------------------------- |
| **Status**                    | Complete                           |
| **Started**                   | 2026-08-06                         |
| **Completed**                 | 2026-08-06                         |
| **Operator**                  | abue-ammar                         |
| **Branch**                    | `refactor/29-feature-folders`       |
| **Commit**                    | single commit on the branch         |
| **Claude conversations used** | 1                                  |
| **Actual effort**             | ~35 min vs. estimate of L (High in aggregate) |

---

## Completed tasks

- [x] Objective 1 — `Features/<Name>/{Model,Service,UI,Settings}/` created for the eleven features large
      enough to warrant it; Onboarding and WindowManagement kept flat per the phase's own judgement call
- [x] Objective 2 — all 88 `Core/` files plus the 20 scattered `Features/Settings/` panes moved in
- [x] Objective 3 — `Settings/` reduced to `SettingsRootView.swift`, `SettingsTab.swift`,
      `AppSettings.swift` and `Panes/` (General + Permissions)
- [x] Objective 4 — all 17 harness command lines updated in **four** places, not the three named
- [x] Objective 5 — **`Tinycast/Core/` deleted**, including its eight emptied subdirectories
- [x] `HealthTicker.swift` and `Memo.swift` → `Platform/`
- [x] `RunningApps.swift` → `RunningAppsMonitor.swift` (file rename only; the type was already
      `RunningAppsMonitor`)
- [x] Split 1 of 3 — `LauncherView.swift` → `LauncherList.swift`, `SectionHeader.swift`,
      `AppIconView.swift`, `AppActionsMenu.swift`
- [x] Split 3 of 3 — `SettingsRootView.swift` → `SettingsRootView.swift` + `SettingsTab.swift`
- [x] `xcodegen generate` re-run and the regenerated `project.pbxproj` staged

## Acceptance criteria

- [x] AC1 — every file at its target path — verified by: `find Tinycast/Features -type d` matches the
      target-layout table; `ls Tinycast/Core` fails
- [x] AC2 — 100 % similarity for every move — verified by: `git diff -M --cached --summary` shows
      **133 renames at `(100%)`** and exactly one below it, `LauncherView.swift => UI/LauncherList.swift
      (63%)`, which is split 1. Both surviving splits were proven byte-identical **redistributions** by
      `diff` against `git show HEAD:…` — the concatenation of the new files' declarations, in
      declaration order, equals the original's exactly. Total Swift line delta is **+4**, fully
      accounted for by the four new files' `import` + blank headers minus the separator blanks the
      redistribution drops. Zero declaration bytes changed
- [x] AC3 — all 17 command lines updated and all 17 pass — verified by: the `## Tests` fence
      **copy-pasted fresh** out of `docs/development.md` and run under `zsh -e`, exit 0, `0 failed` in
      every summary; all 17 binaries confirmed rebuilt by timestamp. `palette-selection-test` 111,684,
      unchanged
- [x] AC4 — every path in `AGENTS.md`'s Critical Invariants section correct — verified by: read end to
      end; 13 paths repaired; `grep -n 'Core/' AGENTS.md` now returns nothing
- [x] AC5 — `Settings/` holds exactly the three files + `Panes/`, and `Panes/` exactly the two orphan
      panes — verified by: `find Tinycast/Features/Settings -type f` returns exactly five paths
- [x] AC6 — **`Tinycast/Core/` no longer exists** — verified by: `ls Tinycast/Core` →
      `No such file or directory`. No file was homeless; see _Deviations_ for the two the phase's table
      mis-places
- [~] AC7 — one top-level `View`/namespace enum per file — **not met for `ClipboardView.swift`.** Split 2
      is impossible without widening `private`; see _Failed tasks_. Every other multi-declaration file
      predates this phase and is not in the split list, so the AC's own exception covers it
- [~] AC8 — Debug and Release succeed; UI pixel-identical — **builds met, pixel-identity argued not
      observed.** Both configurations build clean at 0 compile warnings against a pre-phase Debug
      baseline measured on-branch (0 → 0). No screenshot pair was taken
- [x] Layer gate — **no file under any `Model/` imports AppKit or SwiftUI** — verified by:
      `grep -rn '^import \(AppKit\|SwiftUI\)' Tinycast/Features/*/Model/` returns nothing

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                             |
| -------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | Debug **and** Release, `CODE_SIGNING_ALLOWED=NO`. 0 → 0 compile warnings against a pre-phase Debug baseline measured on this branch. `xcodegen generate` twice → `project.pbxproj` identical        |
| `checklists/testing.md`    | PASS    | All 17 harnesses, command lines copy-pasted verbatim from the updated `docs/development.md`, `zsh -e`, exit 0. `palette-selection-test` 111,684 unchanged                                          |
| `checklists/regression.md` | NOT RUN | **Waived by the operator**, who declined further testing. This is the phase that moves every Settings pane file, so the 14-pane walk and the before/after screenshot pair are the gap — see below |
| `checklists/review.md`     | PASS    | Redistribution proven by `diff` against `git show HEAD:…` on both splits, not by eye. Comment delta 0                                                                                              |

### Measurements

Not a performance or size phase. Content delta is zero by construction: 133 files moved with zero
changed lines, two splits that redistribute bytes without changing any, and one file
(`SettingsRootView.swift`) whose diff is **0 insertions, 65 deletions**.

| Metric                    | Before | After | Note                                              |
| ------------------------- | ------ | ----- | ------------------------------------------------- |
| `Tinycast/Core/` files    | 88     | **0** | directory deleted                                 |
| `Tinycast/Features/` files| 51     | 139   | 13 feature folders + `PaletteRowIndex`            |
| `Tinycast/Platform/` files| 9      | 11    | `HealthTicker`, `Memo`                            |
| `Features/Settings/` files| 25     | 5     | shell + `Panes/`                                  |
| Swift comment lines       | 1949   | 1949  | delta **0**                                       |
| Swift total lines         | 30061  | 30065 | +4, all split-file headers                        |

---

## Failed tasks

- **Split 2 of 3 (`ClipboardView.swift`) was reverted, and AC7 fails for that one file.** The phase's
  split table sends `AsyncThumbnail` into `ClipboardList.swift`, but it is `private` and used from
  **both** sides of the intended boundary — line 173 inside `ClipboardRow` (which lands in
  `ClipboardList.swift`) and line 264 inside `ClipboardPreview` (which lands in
  `ClipboardPreview.swift`). The compiler demanded `internal`. The phase document's own rule decides
  it: _"If the compiler demands a wider access level anywhere, the split is wrong — put it back and say
  so, do not widen."_ So `ClipboardView.swift` moved whole at 100 % similarity and still declares
  `ClipboardList`, `DateBucket`, `ClipboardRow`, `AsyncThumbnail`, `ClipboardPreview` and
  `ClipboardInfoSection`.

  This was found from a build error, then confirmed against the two usage sites rather than worked
  around. **Splitting it requires a real decision, not a bigger `git mv`**: either `AsyncThumbnail`
  becomes `internal` in its own file (widening, which this phase forbids), or the two call sites stop
  sharing one helper. That is a design question for phase 30 or 34, not a move.

---

## Issues encountered

- **`regression.md` was waived, and this is the phase where that costs the most.** Every one of the 14
  Settings pane files moved. The phase's manual checklist asks for the sidebar order, each pane's cards
  and the palette's `Settings ▸ <pane>` entries to be walked, plus a before/after screenshot pair. None
  was performed. The structural argument is strong — 133 files at 100 % similarity cannot have changed a
  view body, and `SettingsTab`'s raw values (persisted `CommandID`s) moved byte-identical — but it is
  not the same as having clicked through the panes. Anyone who trips over a missing or misordered
  Settings pane later should start here.

- **The two data generators hardcoded `Tinycast/Core/…` output paths.** `Tools/gen-emoji.js:318` and
  `Tools/gen-currencies.js:129` write the two `*.generated.swift` files. Left alone, the next
  `node Tools/gen-emoji.js` would have **recreated `Tinycast/Core/Emoji/`** and silently undone AC6.
  Both were repathed. The phase document names three places to update and this is a fifth; it is the
  only one that could have reverted an acceptance criterion by itself.

- **`git mv` leaves emptied directories on disk**, as in phase 28 — eight of them under `Core/`, plus
  `Core/` itself. `rmdir` them explicitly or `find Tinycast -type d -empty -delete`; XcodeGen derives
  sources from the directory tree, so a stray empty group is noise.

- **zsh does not word-split unquoted parameters.** A `for` loop feeding `set -- $range` into `sed`
  silently produced a file literally named `.swift` and one malformed split. Caught immediately by
  `git status`, unstaged and redone. Worth knowing because the harness fences in `docs/development.md`
  are run under `zsh` on this machine.

---

## Deviations from the phase document

- **`AppRow.swift` was not created.** `AppRow` is `private` in `LauncherView.swift` with a single user,
  `LauncherList`. The phase's private-type rule sends it into that type's file, so it lives in
  `LauncherList.swift` and the split produced four files, not five. Same rule, benign case — unlike
  `AsyncThumbnail` above, which had two users.

- **`ClipboardActionsMenu.swift` is not part of any split.** The split table lists it as an output of
  `ClipboardView.swift`, but phase 22 already put that enum in `ClipboardScreen.swift`, which moved at
  100 %. The table is stale, not wrong about where the type should live.

- **`AppEntry` did not reach `Launcher/Model/`.** The target layout lists it as a Model type, but it is
  declared inside `Core/AppIndex.swift`, which imports AppKit. Extracting it would be a fourth split,
  and only three are permitted. It rides to `Launcher/Service/` inside `AppIndex.swift`. **A future
  phase that wants `AppEntry` pure has to split `AppIndex.swift` first.**

- **`KeyShortcut` and `RaycastImportV2` went to `Service/`, not `Model/`.** The target layout lists
  `KeyShortcut` under HotKeys Model and `Raycast*` under Backup Model, but both import AppKit. The
  kickoff states the layer rule as a checkable gate — _"a file under `Model/` must not import AppKit or
  SwiftUI"_ — so the gate decided it over the table's type list. Result: zero AppKit/SwiftUI imports
  under any `Model/`.

- **`CalloutPlacement.swift` is in `HotKeys/UI/`, where the table puts it, even though it is pure
  CoreGraphics and harness-compiled.** `callout-test` compiles it from `UI/`. This is the one
  harness-compiled file that does not live under a `Model/`, and it is deliberate — the table is
  explicit. Worth flagging because it makes "harness input ⇒ `Model/`" false as a general rule.

- **`palette-selection-test` is *not* exempt.** Both the kickoff and the implementation boundaries say
  it is the one harness whose command line does not change. It compiles
  `Core/Emoji/EmojiGridGeometry.swift`, which this phase moved, so its command line changed like the
  other sixteen. The `checklists/testing.md` row was also missing that second input entirely and now
  names it.

- **`ci.yml` is a fourth place, and `checklists/build.md` a fifth.** The phase names
  `docs/development.md`, `AGENTS.md` and `checklists/testing.md`. `.github/workflows/ci.yml` carries 15
  of the command lines — phase 27 established that a stale path there is a red suite, not a stale doc —
  and `checklists/build.md` names the three engine paths in its Release-build trigger. Both updated.

- **`WindowManagement/` and `Onboarding/` are flat, with no layer subfolders.** Both the kickoff and the
  boundaries name these two as not needing them. WindowManagement has five files including
  `WindowMover.swift` (AppKit) and its Settings pane, so the pure/impure split there is documented in
  `docs/window-management.md` rather than expressed in the directory tree.

- **Eight doc paths fixed that this phase did not break.** `docs/ui.md` (7) and `docs/architecture.md`
  (1) still pointed at `Core/Theme.swift`, `Core/EdgeDissolve.swift`, `Core/ThinScrollbar.swift`,
  `Core/ScrollIntent.swift`, `Core/SymbolImage.swift`, `Core/Tooltip.swift`,
  `Core/PanelTransition.swift` and `Core/NotificationToken.swift` — all **phase-27 leftovers**. They
  were swept up because they now point into a deleted directory. `docs/architecture-review.md` was left
  stale on purpose: rank 5 on the precedence ladder, historical, never an instruction.

---

## Follow-up work

| Observation                                                                                                   | Where                                                                    | Suggested phase |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | --------------- |
| `ClipboardView.swift` still declares six top-level types; AC7 unmet. Needs an `AsyncThumbnail` decision, not a move | `Features/Clipboard/UI/ClipboardView.swift`                              | 30 or 34        |
| Two comments name the dead path `Core/Calculator/`; not editable without breaking the 100 % gate               | `Calculator/Model/CalcCurrency.swift:9`, `Calculator/Service/CurrencyRateStore.swift:4` | 30 or 34 |
| **`ci.yml` runs 15 of 17 harnesses** — no `volume-test`, no `palette-selection-test`                          | `.github/workflows/ci.yml`                                               | 33 or 34        |
| **`ci.yml`'s `snippets-test` line omits `HealthTicker.swift` and cannot compile** — red since phase 10        | `.github/workflows/ci.yml`                                               | 33 or 34        |
| `AppEntry` cannot be pure until `AppIndex.swift` is split                                                     | `Features/Launcher/Service/AppIndex.swift`                               | 30 or later     |
| The 14-pane Settings walk and screenshot pair this phase skipped                                              | all Settings panes                                                       | fold into 30    |
| Stale paths in the architecture review (now more of them)                                                     | `docs/architecture-review.md`                                            | 34, docs pass   |

**No blocker for phase 30.** Phase 29's dependents are 30, 31 and 32; all three depend on the file
layout, which is complete and builds clean in both configurations. Nothing above blocks them — the two
`ci.yml` defects predate this phase and do not affect local verification, and the `ClipboardView.swift`
gap is a naming/design question that 30 is the natural home for.

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. Moves plus two cut-and-paste splits; no storage, no persisted
  format, no behaviour. `SettingsTab`'s raw values — persisted `CommandID`s — moved byte-identical, so a
  revert cannot orphan a record. Re-run `xcodegen generate` after reverting.
- **Dependent phases that must also be reverted:** none yet. **30, 31 and 32 hard-depend on this**, so
  reverting after any of them lands means reverting those too.
- **Data risk on revert:** none.
- **Note:** this landed as **one commit**, not the thirteen the phase document's rollback strategy
  assumes — the operator chose a single staged tree. Per-feature revert is therefore a manual path
  filter, not a `git revert`.

---

## Sign-off

- [x] All acceptance criteria met — **AC7 not met** for `ClipboardView.swift` (the phase's own
      private-type rule blocks the split); AC8 partially — builds verified, pixel-identity argued from
      byte-identity rather than observed
- [ ] All four checklists passed — **three of four.** `regression.md` not run; waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — branch pushed, not merged
- [x] **Stopped.** Next phase is a separate session.
