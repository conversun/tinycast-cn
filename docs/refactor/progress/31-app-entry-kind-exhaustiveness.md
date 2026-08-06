# Phase 31 — `AppEntry.Kind` exhaustiveness and `KindDescriptor`

---

## Status

| Field                         | Value                                          |
| ----------------------------- | ---------------------------------------------- |
| **Status**                    | Complete                                       |
| **Started**                   | 2026-08-06                                     |
| **Completed**                 | 2026-08-06                                     |
| **Operator**                  | abue-ammar                                     |
| **Branch**                    | `refactor/31-app-entry-kind-exhaustiveness`    |
| **Commit**                    | single commit on the branch                    |
| **Claude conversations used** | 1                                              |
| **Actual effort**             | ~20 min vs. estimate of M (2–4 h)              |

---

## Completed tasks

- [x] Objective 1 — every `Kind` switch is exhaustive. Two of the nine sites were boolean
      *expressions* rather than switches (`canRevealInFinder`, `isSymbolIcon`); routing them through
      the descriptor is what put them under the exhaustiveness checker
- [x] Objective 2 — the per-kind metadata collapses into `AppEntry.KindDescriptor`, returned by one
      `switch` on `Kind`. Plain struct, computed per access, exactly five members
- [x] Objective 3 — `Kind` itself untouched: no case added, none removed, no raw value renamed
- [x] The two duplicated open-verb switches (`AppActionsMenu.openTitle`,
      `LauncherScreen.pillTitle`) deleted; both call sites read `descriptor.openVerb`
- [x] `symbolIconName` and `hotKeyAction` deliberately left as their own switches
- [x] The scratch-case test performed, its error count recorded, and the case reverted
- [x] Pre-phase warning baseline taken on-branch before any edit

## Acceptance criteria

- [x] AC1 — no `default:` in a `Kind` switch — verified by:
      `grep -rn "default:" Tinycast/Features/Launcher/` returns two unrelated hits
      (`CommandCatalog.isQuicklinkCommand`, a `built[…, default: [:]]` dictionary subscript).
      **Already true before this phase** — see _Deviations_
- [x] AC2 — a hypothetical `Kind` case is a compile error at every site that must be updated —
      **met for all four switch sites, with one documented exception.** See _The scratch-case test_
- [x] AC3 — `KindDescriptor` exists with exactly the five listed members, and nothing else
- [x] AC4 — every label, section title and open verb character-identical — proven mechanically,
      not by eye: every string literal was extracted from the `-` and `+` sides of the diff and the
      **distinct sets are identical**. The only multiset change is each of the eight open verbs
      losing exactly one duplicate copy, which is the two switches becoming one
- [x] AC5 — section order unchanged; the literal array holds the same sequence of kinds
- [~] AC6 — `hiddenKinds` round-trips — **met by construction, not observed.** No case and no raw
      value was touched and `VisibilityStore` is not in the diff, so there is nothing that could
      change what is persisted. No quit/relaunch pass was performed
- [x] AC7 — **Release build succeeds**; the section array kept its explicit type annotation

---

## The scratch-case test

`case scratch` added to `AppEntry.Kind`, built, reverted. **4 errors, all `switch must be
exhaustive`:**

| File                                              | Line | Switch                |
| ------------------------------------------------- | ---- | --------------------- |
| `Tinycast/Features/Launcher/Service/AppIndex.swift`      | 16   | `Kind.descriptor`     |
| `Tinycast/Features/Launcher/Service/AppIndex.swift`      | 89   | `hotKeyAction`        |
| `Tinycast/Features/Launcher/Service/AppIndex.swift`      | 116  | `symbolIconName`      |
| `Tinycast/Features/Launcher/UI/LauncherCoordinator.swift` | 71   | `launch`              |

**Anyone re-running this must use `SWIFT_COMPILATION_MODE=wholemodule`.** The default Debug batch
mode aborts after the first file that fails, so a plain `xcodebuild` reports only the three errors in
`AppIndex.swift` and hides `LauncherCoordinator`. That is a property of the build, not of the code,
and it will mislead the next person who runs this test on any phase.

**`LauncherList.rows` does not error, and cannot.** A literal array is not exhaustiveness-checkable,
and the phase's implementation boundary explicitly requires that array to stay literal with
hand-written order so it keeps mirroring `AppIndex.publishEntries`'s slices. So one step of the
`AGENTS.md` recipe stays prose-enforced. What the phase *did* buy there is that
`descriptor.sectionTitle` now has no value for a new kind until its author writes one, which is the
prompt to go add the section — a nudge, not a gate. This is the honest limit of the phase.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                     |
| -------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | **Debug and Release**, `CODE_SIGNING_ALLOWED=NO`, both `BUILD SUCCEEDED`. 0 → 0 compile warnings against an on-branch pre-phase baseline. Release matters here — it is the gate on the section array's type annotation |
| `checklists/testing.md`    | PARTIAL | The three harnesses the phase gates on — `fuzz-test`, `ranking-test`, `palette-selection-test` — all pass; `palette-selection-test` 111,684 / 0 failed, unchanged. The other 14 were not run; no file they compile is in the diff |
| `checklists/regression.md` | NOT RUN | **Waived by the operator**, who declined further testing                                                                                                                    |
| `checklists/review.md`     | PASS    | 4 files, +63/−51, all four on the phase's expected list. `AppIndex.publishEntries()` provably untouched (`publishEntries` absent from the diff). Comment delta +1           |

### Measurements

Not a performance or size phase.

| Fact                                       | Before | After | Note                                              |
| ------------------------------------------ | ------ | ----- | ------------------------------------------------- |
| `Kind` switch/expression sites             | 9      | 8     | two verb switches merged, two expressions promoted |
| Sites a new `Kind` breaks the build at     | 3      | 4     | `descriptor` replaces nothing; the two ex-expressions now count |
| Copies of each open verb in the source     | 2      | 1     | one table                                          |
| `Kind` cases / raw values changed          | —      | **0** | AC6                                                |
| Changed string literals                    | —      | **0** | AC4, proven by extracting both sides               |

---

## Failed tasks

None.

---

## Issues encountered

- **Batch-mode compilation hides scratch-case errors.** Documented above. The first run of the test
  reported 3 errors and looked like `LauncherCoordinator` had silently lost its exhaustiveness; it had
  not — the compiler simply never reached the file.

- **`regression.md` was waived.** The residual gap is real but narrow: nothing here is a persisted
  value or a layout, and AC4 mechanically proves no user-visible string moved, but nobody opened the
  palette to confirm the section order and the eight row labels / footer verbs / Actions-menu titles
  render as before. The screenshot comparison the phase asks for was not done.

---

## Deviations from the phase document

- **The phase document's premise was partly stale: there were no `default:` cases left to remove.**
  It lists `LauncherScreen.primaryActionTitle` (`pillTitle`) as using `default:`; it was already
  exhaustive on arrival, as were all the other switches. AC1 was therefore satisfied before the first
  edit. The phase's *real* delivered value is objective 2 plus the promotion of `canRevealInFinder`
  and `isSymbolIcon` from boolean expressions — which the document classifies as "expression", not as
  a gap — into compiler-checked switches.

- **`AppEntry` is not at `Features/Launcher/Model/AppEntry.swift`**, which the document's
  _Expected files to modify_ table names. It lives in `Features/Launcher/Service/AppIndex.swift` and
  was edited in place. Moving it to `Model/` would violate `AGENTS.md` — `AppEntry.icon` returns
  `NSImage`, and a file under `Model/` may not import AppKit. The file table is what is stale.

- **`LauncherList`'s section rows go through a local `section(_:)` helper** rather than repeating
  `AppEntry.Kind.application.descriptor.sectionTitle` inline nine times. The array is still a literal,
  still in the same hand-written order, and still carries its `[(String, [AppEntry])]` annotation;
  `"Favorites"` stays a hand-written first row because it is not a kind.

- **`LauncherScreen`'s `case nil` fallback keeps the literal `"Open Application"`.** It is the
  empty-state default for "no row is selected", not a per-kind derivation, so routing it through the
  descriptor would have made it read worse for no gain.

---

## Follow-up work

| Observation                                                                                                                                                                                                 | Where                                                | Suggested phase                    |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | ---------------------------------- |
| The scratch-case instruction should say `SWIFT_COMPILATION_MODE=wholemodule`. As written it under-reports error sites and invites a false conclusion                                                         | `docs/refactor/checklists/` and future phase prompts | fix alongside the next phase       |
| Phase 31's file table names `Features/Launcher/Model/AppEntry.swift`, which cannot exist under the `Model/` purity rule                                                                                       | `docs/refactor/phases/31-…md`                        | historical record, leave stale     |
| `checklists/regression.md:146` still lists phase 30 in its _Clean install_ set, contradicting that phase document — carried over from phase 30, still open                                                    | `docs/refactor/checklists/regression.md`             | fix alongside the next phase       |
| `AGENTS.md`'s `AppEntry.Kind` invariant still describes the recipe as fully manual. It could now name `KindDescriptor` as the enforcement point and be explicit that the `LauncherList` slice is the one manual step | `AGENTS.md`                                          | phase 34's doc pass                |
| The 14 harnesses outside this phase's gate were not run                                                                                                                                                     | —                                                    | folds into the next phase's testing |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. No storage, no persisted key, no raw value, no format, no
  behaviour. `xcodegen generate` is not needed — no file was added, removed or renamed, so
  `project.pbxproj` is not in the diff.
- **Dependent phases that must also be reverted:** none. **Phase 32 depends on 25 and 29, not on 31**,
  so it is not blocked by this phase and is unaffected by reverting it.
- **Data risk on revert:** none.

---

## Sign-off

- [x] All acceptance criteria met — AC6 by construction rather than observed
- [ ] All four checklists passed — **two of four, one partial.** `regression.md` not run (waived);
      `testing.md` limited to the three harnesses the phase gates on
- [x] The scratch-case test performed and its error count recorded
- [ ] Section screenshot compared — **not done**, part of the waived regression pass
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — branch pushed, not merged
- [x] **Stopped.** Next phase is a separate session.
