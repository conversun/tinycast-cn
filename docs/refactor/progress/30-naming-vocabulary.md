# Phase 30 — Naming vocabulary

---

## Status

| Field                         | Value                                |
| ----------------------------- | ------------------------------------ |
| **Status**                    | Complete                             |
| **Started**                   | 2026-08-06                           |
| **Completed**                 | 2026-08-06                           |
| **Operator**                  | abue-ammar                           |
| **Branch**                    | `refactor/30-naming-vocabulary`      |
| **Commit**                    | single commit on the branch          |
| **Claude conversations used** | 1                                    |
| **Actual effort**             | ~10 min vs. estimate of S (≤ 2 h)    |

---

## Completed tasks

- [x] Objective 1 — both renames applied: `CommandRegistry` → `CommandCatalog`,
      `PaletteViewModel` → `PaletteState`, each file renamed to match its type
- [x] Objective 2 — the suffix vocabulary table written into `AGENTS.md` with membership lists, seven
      exceptions and the "new suffix means a new row" rule
- [x] Objective 3 — nothing else changed; the Swift diff is provably identifier-only
- [x] `PalettePanel.paletteViewModel` (the stored property) → `paletteState`
- [x] `xcodegen generate` re-run and the regenerated `project.pbxproj` staged
- [x] Live subsystem docs updated so no doc names a type that no longer exists

## Acceptance criteria

- [x] AC1 — no old name remains — verified by:
      `git grep -n "CommandRegistry\|PaletteViewModel" -- Tinycast` empty. The AC's unscoped grep still
      hits `docs/architecture-review.md` and `docs/refactor/**`; those are the historical records of the
      phases that created the names, rank 5, left stale on purpose as in phase 28
- [x] AC2 — both file names match their types — verified by:
      `git diff -M --summary` shows both renames at **100 %** similarity
- [x] AC3 — the changed-string-literal grep — **met, with its one line accounted for.** The grep
      returns a `-`/`+` pair for `AppIndex.swift:84`, whose `"questionmark"` literal is untouched — the
      line changed only in the identifier. Proven mechanically rather than by eye: every literal
      extracted from the `-` side and the `+` side of the whole Swift diff is byte-identical
- [x] AC4 — `AGENTS.md` carries the table, memberships, exceptions with reasons and the rule
- [~] AC5 — `Registry` / `ViewModel` absent from `Tinycast/` — **met for top-level types.** Three lines
      remain, all `SnippetRepository`'s private nested `CoordinatorRegistry`. See _Deviations_
- [x] AC6 — all 17 harnesses pass — verified by: the `## Tests` fence of `docs/development.md` run
      under `bash -e`, exit 0; `palette-selection-test` 111,684, unchanged
- [~] AC7 — zero behaviour change — **proven structurally, not observed.** Normalising the four rename
      pairs makes the `-` and `+` sides of the Swift diff **identical**, so no logic was touched. No
      runtime pass was performed

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                              |
| -------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PARTIAL | Debug only, `CODE_SIGNING_ALLOWED=NO`. 0 → 0 compile warnings against an **on-branch pre-phase baseline**. `xcodegen generate` twice → `project.pbxproj` hash identical. **Release not built** |
| `checklists/testing.md`    | PASS    | All 17 harnesses, `bash -e`, exit 0. `palette-selection-test` 111,684 unchanged                                                                     |
| `checklists/regression.md` | NOT RUN | **Waived by the operator**, who declined further testing                                                                                            |
| `checklists/review.md`     | PASS    | Identifier-only diff proven by normalising the rename pairs and diffing both sides. Comment delta 0                                                 |

### Measurements

Not a performance or size phase. 23 files, +89/−44 — of which `AGENTS.md` is +47. The Swift delta is
one line per call site plus one reworded doc comment.

| Fact                                    | Before | After | Note                                       |
| --------------------------------------- | ------ | ----- | ------------------------------------------ |
| `Registry` as a top-level type suffix   | 1      | 0     | retired                                    |
| `ViewModel` as a type suffix            | 1      | 0     | retired                                    |
| `Catalog` members                       | 3      | 4     | `CommandCatalog` joins                     |
| `State` members                         | 2      | 3     | `PaletteState` joins                       |
| Changed string literals                 | —      | **0** | AC3, proven by extracting both sides       |

---

## Failed tasks

None.

---

## Issues encountered

- **`regression.md` was waived, and the cost here is genuinely low.** Unlike phase 28, this phase's
  risks are not runtime. The diff is identifier-only by proof, no persisted key, raw value or column
  name is touched, and the three renames that *would* have carried storage risk were cut from the phase
  before implementation. The residual gap is that nobody opened the palette afterwards.

- **BSD `sed` silently no-ops on `\b`.** The first rename pass used `\b…\b` word boundaries, reported
  success and changed nothing; only the follow-up `git grep` caught it. The identifiers are unique
  substrings, so the second pass dropped the boundaries. Anything scripted against `sed` on macOS in a
  later phase should verify the substitution landed rather than trust the exit code.

- **`checklists/regression.md` still lists phase 30 in its _Clean install_ set** (line 146, "phases 05,
  06, 16, 17, 27–30, 35"), which the rewritten phase document explicitly retires. The checklist and the
  phase document disagree; the phase document is rank 3 and wins, but the checklist should be corrected
  so the next reader is not sent to run a pass the phase says is unnecessary.

---

## Deviations from the phase document

- **The phase document was rewritten before execution, cutting three of the original six renames.**
  `ClipboardManager` → `ClipboardMonitor`, `HotKeyManager` → `HotKeyBindings` and
  `MiscellaneousSettingsView` → `CalculatorSettingsView` were dropped on the operator's decision, and
  `Manager` was instead documented as a closed set of two. The reasoning is recorded in the phase
  document's _Renames explicitly NOT in this phase_ section. This is what removed every
  persisted-string risk the phase originally carried, and what let AC3 be inverted from "account for
  every changed literal" to "the grep must be empty".

- **AC5 is met for top-level types only.** `SnippetRepository`'s private nested `CoordinatorRegistry`
  keeps its name. The suffix is *accurate* there — it interns one lock per canonical channel-directory
  path, which is real registration, unlike `CommandRegistry`'s static list. Renaming it is outside the
  phase's boundaries, and the file sits under a `Model/` purity invariant and compiles into
  `snippets-test`. The `AGENTS.md` table was scoped to top-level types and carries the exception with
  its reason.

- **`PalettePanel.paletteViewModel` → `paletteState`** — a property, not a type. Read as part of
  applying the rename; `paletteViewModel: PaletteState?` would have been incoherent.

- **`let vm: PaletteState` kept as `vm`** in the seven screens. It matches neither AC grep and renaming
  it is outside what the phase asked. Under-delivering is re-runnable.

- **One comment reworded.** `PaletteState.swift:3` opened "View-model shared between…", which the
  rename makes false; two words changed and the sentence's content is intact. Comment delta **0**
  (1 added, 1 removed).

- **Live doc paths were updated although no acceptance criterion asked**, on the precedent phases 27
  and 28 set: `docs/palette.md` (3), `docs/architecture.md` (1), `docs/custom-commands.md` (1).
  `docs/architecture-review.md` and everything under `docs/refactor/` left stale deliberately.

- **A factual error was introduced into `AGENTS.md` and corrected in the same phase.** The
  `CoordinatorRegistry` exception first read "caches an `NSFileCoordinator` per channel directory". It
  does not — the nested `Coordinator` is an `NSLock` wrapper, and the file's only `NSFileCoordinator`
  is an unrelated local at line 342. Corrected before commit.

---

## Follow-up work

| Observation                                                                                                                                 | Where                                                     | Suggested phase                    |
| --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ---------------------------------- |
| **`Coordinator` has three meanings in one file** — the vocabulary's 10 `*Coordinator` action surfaces, `NSFileCoordinator` at line 342, and a private `NSLock` wrapper at line 4. Rename `Coordinator` → `DirectoryLock`, `CoordinatorRegistry` → `DirectoryLockTable`, `coordinatorRegistry` → `directoryLocks`, `coordinator` → `lock`. ~14 private lines, no API surface; also makes AC5's grep literally empty and retires the `AGENTS.md` exception | `Features/Snippets/Model/SnippetRepository.swift`          | **standalone commit after 30**     |
| `MiscellaneousSettingsView` sits under `Features/Calculator/Settings/` but is not a Calculator-owned pane; belongs in `Features/Settings/Panes/` beside General and Permissions | `Features/Calculator/Settings/MiscellaneousSettingsView.swift` | a small move, unassigned           |
| `checklists/regression.md:146` still lists phase 30 in its _Clean install_ set, contradicting the phase document                             | `docs/refactor/checklists/regression.md`                  | fix alongside the next phase       |
| Release configuration not built for this phase                                                                                              | —                                                         | folds into the next phase's build  |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. Identifier renames plus documentation; no storage, no
  persisted format, no behaviour. Re-run `xcodegen generate` after reverting.
- **Dependent phases that must also be reverted:** none. **Phase 31 and 32 depend on 29, not on 30**,
  so neither is blocked by this phase and neither is affected by reverting it.
- **Data risk on revert:** none.

---

## Sign-off

- [x] All acceptance criteria met — AC5 for top-level types, AC7 proven structurally rather than
      observed
- [ ] All four checklists passed — **two of four, one partial.** `regression.md` not run (waived);
      `build.md` Debug only
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — branch pushed, not merged
- [x] **Stopped.** Next phase is a separate session.
