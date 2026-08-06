# Phase 08 — Parallel uninstall scan

---

## Status

| Field                         | Value                              |
| ----------------------------- | ---------------------------------- |
| **Status**                    | Complete                           |
| **Started**                   | 2026-08-05                         |
| **Completed**                 | 2026-08-05                         |
| **Operator**                  | abue-ammar                         |
| **Branch**                    | `refactor/08-parallel-uninstall-scan` |
| **Commit**                    | single commit on the branch        |
| **Claude conversations used** | 1                                  |
| **Actual effort**             | ~1.5 h vs. estimate of M (~2 h)    |

---

## Completed tasks

- [x] Objective 1 — Parallelise root enumeration with a `TaskGroup`, writing results into an
      index-keyed bucket array
- [x] Objective 2 — Parallelise directory sizing with a `TaskGroup`, writing sizes back by index
- [x] Objective 3 — Move deduplication **after** the parallel gather so it stays deterministic
- [x] Objective 4 — Preserve the final ordering exactly

## Acceptance criteria

- [x] AC1 — Root enumeration in a `TaskGroup` with index-keyed writeback — verified by:
      `withThrowingTaskGroup(of: (Int, [Row]).self)`, `buckets` pre-sized to `roots.count`, writeback
      is `buckets[index] = found` in the group body
- [x] AC2 — Directory sizing in a `TaskGroup` with index-keyed writeback — verified by:
      `withThrowingTaskGroup(of: (Int, MeasuredSize).self)` over `walkIndices`, writeback is
      `candidates[index] = resized(candidates[index], to: size)`
- [x] AC3 — No shared mutable `Set`, dictionary or array written from more than one task — verified by:
      `seen` is a single pass after both gathers (`git diff | grep seen.insert` → exactly one added
      site, outside any group); each group's writeback happens in the group body, not in a child
- [x] AC4 — Candidate list identical in order — verified by: compiling the `main` scanner and this one
      into standalone binaries (pure layer + `Signposts` + a driver printing index, evidence, bytes,
      `isLowerBound`, protection, name, label, path per row) and diffing the output on 13 real apps —
      Xcode, Safari (27 rows), Zed, VS Code, Chrome, MongoDB Compass, OrbStack, Raycast Beta, Stats,
      Dinky, TablePro, Alacritty — plus a synthetic 8-fat-directory target. Byte-identical every time.
      Operator confirmed the rendered list visually.
- [x] AC5 — Reported sizes identical — verified by: the same diffs; `size.bytes` and
      `size.isLowerBound` are both columns in the compared output
- [x] AC6 — Cancelling releases the scan promptly, no orphaned task — verified by: a driver that
      cancels at 15 ms reports `CancellationError` 1–4 ms later and its `await task.value` returns
      immediately, including mid-way through Xcode's 4 GB bundle walk. Required adding a per-entry
      `Task.checkCancellation()` inside `directorySize` — see **Deviations**
- [x] AC7 — `Tools/uninstall-test.swift` passes with no source or command-line change — verified by:
      117 passed, 0 failed, exit 0; none of the five harness-compiled files appear in
      `git diff --name-only`
- [x] AC8 — Scan wall time improves measurably — verified by: harness timings below. Target-dependent,
      and the Xcode case is ~0 % — see **Measurements**

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                     |
| -------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | §1 `xcodegen generate` clean, no `.xcodeproj` churn (correct — no files added). §2 Debug `BUILD SUCCEEDED`, **zero warnings against a pre-phase baseline captured on this branch** (also zero). §3 Release required (touches generic code: `Signposts.interval<T>`) — `BUILD SUCCEEDED`, no type-checker timeout. §4 binary below. §5 launch and the uninstall flow confirmed by the operator. §6 n-a — phase 08 is not in the startup-timing list |
| `checklists/testing.md`    | PASS   | Harnesses run: **all 17**, though only `uninstall-test` was mandatory (the phase names it; the harness → source map does not, since no harness compiles the two changed files). `fuzz` `ranking` `calc` `clipboard` `scopes` `raycast` `emoji` `custom-command` `snippets` `hotkey` `callout` `system-action` `volume` `window-command` `uninstall` `quicklink` — all pass. Purity invariant intact: the five pure uninstall files still `import Foundation` only and are untouched |
| `checklists/regression.md` | PASS   | Sections run: Core sweep + **Uninstall** in full, by the operator, manually. Includes the before/after list comparison, the bundle-only case, a locked candidate, Escape mid-scan, and the run-it-twice determinism check                                                                                              |
| `checklists/review.md`     | PASS   | §1 scope: 3 files, none from the must-NOT-change list, no new or deleted files, `.xcodeproj` unchanged; +154/−73 against an expected +70/−45 (~2×, at the edge — see **Deviations**). §2 no condition, comparison, default, guard or nil-handling change; no user-visible string touched. §3 `Task.detached` **removed** in favour of a structured child; `[weak self]` and `scanTask?.cancel()` intact; nothing new is long-lived. §4 no new cache, nothing newly retained. §5 comments +9/−3 = **+6 net**, zero new stacked blocks (the one adjacent pair in the file is byte-identical on `main`), longest added line 99 chars. §6 no dead code, no shim, no TODO. §7 `trashItem` still the only removal call; `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                     | Before    | After     | Δ                                                          |
| -------------------------- | --------- | --------- | ---------------------------------------------------------- |
| Binary size (Release)      | 3,490,024 | 3,507,576 | **+17,552 B (+0.503 %)** — two `TaskGroup` specializations  |
| Clean install verified?    | —         | n-a       | no storage, no persisted format, not in the clean-install list |
| Cold launch, median of 3   | —         | —         | no phase-01 baseline exists; scan is not on the launch path |
| RSS after 10 palette opens | —         | —         | not measured; scan peak RSS +0.5–1.1 MB (harness-measured)  |
| `UninstallScanner.scan`    | 1.27 s    | 1.27 s    | Xcode: **~0 %** — one 4 GB bundle walk dominates            |
| `UninstallScanner.scan`    | 0.047 s   | 0.030 s   | Safari, 27 rows: **~1.6×**                                  |
| `UninstallScanner.scan`    | 0.199 s   | 0.144 s   | VS Code: **~1.4×**                                          |
| `UninstallScanner.scan`    | 0.092 s   | 0.015 s   | Stats: **~6×**                                              |
| `UninstallScanner.scan`    | 0.398 s   | 0.084 s   | 8 fat directories, synthetic: **~4.7×**                     |

Harness-measured, by compiling the real `UninstallScanner.swift` from both `main` and this branch into
standalone binaries. **Not** taken from the phase-01 signpost — no baseline exists (see `progress/01`).
Each figure is the median of three runs on a warm filesystem cache.

Five rows rather than one because a single number would mislead: the win is entirely a function of how
many fat directories the target has. Xcode is Amdahl-bound — its 4 GB `.app` walk is the long pole and
no amount of fan-out beats the longest single walk. Targets with several mid-sized leftovers, which the
phase document describes as the common case (10–25 directories), gain 1.4–6×.

---

## Failed tasks

none

---

## Issues encountered

- **`Signposts.interval` had no async overload.** Phase 01 shipped one sync helper, and `scan` becoming
  `async` made it uncallable. Added a 5-line `async rethrows` overload rather than hand-rolling
  `beginInterval`/`defer` at the call site, which would have left the helper inconsistent with its only
  other use. `Signposts.swift` is not in the phase's expected-files list.
- **`UninstallCandidate.size` is `let`.** The phase document says phase 2 "mutates only the `size` field
  of a row already in place", but `UninstallPlan.swift` is on the must-NOT-change list, so the field
  cannot be made mutable. See **Deviations** — no future phase makes it mutable either (12, 20 and 25 all
  list `Core/Uninstall/*` as untouchable; 29 only moves the files), so this is settled, not deferred.
- **Cancellation never actually reached the scan before this phase.** `scanTask?.cancel()` cancelled the
  outer task, but the scan ran inside a `Task.detached`, which does not inherit cancellation — the
  `Task.checkCancellation()` calls in the old serial loop could never fire. The UI released immediately
  because of the `guard !Task.isCancelled` after the await, so this was invisible. Uncapped fan-out
  would have made it visible as every core staying busy after Escape, so the phase's own gate
  ("cancelling the parent still releases the whole scan") required fixing it.
- **The perf win is much smaller than the phase document implies for one-fat-directory targets.** The
  document's framing — "8–16 cores sit idle" — holds for a target with many leftovers, not for one whose
  `.app` bundle is the bulk of the work. Worth knowing before phase 34 re-measures.

---

## Deviations from the phase document

- **A third file changed: `Tinycast/Core/Signposts.swift`** (+8 lines, an `async` overload of
  `interval`). Not in **Expected files to modify**, not in **Files that must NOT change**. Without it
  the phase-01 signpost — which AC8 names as the measurement — could not wrap an `async` scan.
- **Phase 2 substitutes a size-only copy instead of mutating a field.** `UninstallCandidate.size` is
  `let` and `UninstallPlan.swift` is must-NOT-change, so writeback is
  `candidates[index] = resized(candidates[index], to: size)` — same array, same index, one field
  different. The ordering guarantee the sentence exists to protect is unaffected. `resized` is arguably
  the safer form: `UninstallCandidate` has no defaulted properties, so adding a field breaks it at
  compile time, where an in-place `.size =` would silently keep working.
- **`Task.detached` removed from `UninstallSession.begin`.** The phase asked only to "await the
  now-`async` scan"; the scan now runs through a `private nonisolated static runScan` so it is
  `scanTask`'s structured child. This is what makes the kickoff's cancellation gate true, keeps
  `makeTarget` off the main actor, and satisfies `review.md` §3's "no `Task.detached` where a structured
  child would do". `scanTask?.cancel()`, the `.userInitiated` priority and the `guard !Task.isCancelled`
  are all unchanged.
- **`directorySize` gained a per-entry `Task.checkCancellation()`** and is now `throws`. The phase asked
  for a check "inside each child task"; without one inside the walk itself, cancellation could not land
  until a walk finished, and with uncapped fan-out every in-flight walk would run to completion after
  Escape. AC6 asks for prompt release.
- **Diff is ~2× the expected commit size** (+154/−73 vs. +70/−45, 3 files vs. 2). The extra volume is
  the per-root body and the `bin` pass moving into named helpers (`rows`, `binRows`) — re-indented moves
  that the diff counts twice — plus `Row`, `resized` and the signpost overload. No new behaviour.

---

## Follow-up work

| Observation                                                                                                                                   | Where                                    | Suggested phase                    |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ---------------------------------- |
| Phase-01 Instruments baselines were never captured, so this phase's before/after came from a scratch harness rather than the shipped signpost  | `progress/01`                            | 34 (final measurement)             |
| `UninstallScanner.scan`'s signpost now measures a parallel region, so the interval is wall-clock, not CPU time — matters when reading a trace   | `Core/Uninstall/UninstallScanner.swift:30` | 34 (final measurement)             |
| The bundle walk is the long pole on large `.app` targets; nothing splits a single directory tree across tasks                                   | `Core/Uninstall/UninstallScanner.swift:238` | none — out of scope, likely not worth it |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. Scan results are computed fresh on every run and nothing is
  persisted, so there is no state to unwind.
- **Dependent phases that must also be reverted:** none. No phase lists 08 as a dependency.
- **Data risk on revert:** none — local data is disposable under `POLICY.md`, and this phase writes none.

---

## Sign-off

- [x] All acceptance criteria met
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
