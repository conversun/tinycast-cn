# Phase 01 — Instrumentation and baselines

---

## Status

| Field                         | Value                                       |
| ----------------------------- | ------------------------------------------- |
| **Status**                    | Complete                                    |
| **Started**                   | 2026-08-05                                  |
| **Completed**                 | 2026-08-05                                  |
| **Operator**                  | abue-ammar                                  |
| **Branch**                    | `refactor/01-instrumentation-and-baselines` |
| **Commit**                    | `399189b` (#157)                            |
| **Claude conversations used** | 1                                           |
| **Actual effort**             | ~1h vs. estimate of S                       |

---

## Completed tasks

- [x] Objective 1 — a single `Signposts` helper exposing one `OSSignposter` on `com.tinycast.perf`
- [x] Objective 2 — the five intervals: `AppIndex.scan`, `AppIndex.rank`,
      `PaletteWindowController.show`, `UninstallScanner.scan`, `AppCore.start`
- [x] Objective 3 — record the baseline measurements (operator, needs Instruments; see below)

## Acceptance criteria

- [x] AC1 — one `OSSignposter` on subsystem `com.tinycast.perf` — verified by: `Signposts.swift` is the
      only file importing `os`; one `OSSignposter` literal in the repo
- [x] AC2 — all five emit begin/end including early-return and throw paths — verified by: the helper
      uses `defer`, and a standalone build of the same helper streamed to `log stream --signpost` gave
      27 begins / 27 ends with half the calls throwing
- [x] AC3 — zero behaviour change — verified by: `git diff -w` reduces the whole diff to the five
      wrapper lines, their closing braces and four indent-forced line re-wraps
- [x] AC4 — Release builds, binary growth < 0.5 % — verified by: 3,471,592 → 3,473,448 bytes (+0.053 %)
      against a clean HEAD build in a throwaway worktree
- [x] AC5 — no new import in a harness-compiled file — verified by: `git diff -U0 | grep '^+import'` is
      empty; all 16 harness commands compile and pass
- [x] AC6 — net comment lines ≤ 5, zero stacked blocks — verified by: 2 added, non-consecutive, both
      under 100 characters

---

## Verification

| Checklist                  | Result | Notes                                                          |
| -------------------------- | ------ | -------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | Debug + Release, zero new warnings; binary +1,856 B (+0.053 %) |
| `checklists/testing.md`    | PASS   | Harnesses run: all 16 in `docs/development.md`                 |
| `checklists/regression.md` | PASS   | Core sweep run by the operator before merge                    |
| `checklists/review.md`     | PASS   | Caught one overlong new comment line, fixed before commit      |

### Measurements

| Metric                     | Before    | After     | Δ                      |
| -------------------------- | --------- | --------- | ---------------------- |
| Binary size (Release)      | 3,471,592 | 3,473,448 | +1,856 B (+0.053 %)    |
| Clean install verified?    | —         | n-a       | phase persists nothing |
| Cold launch, median of 3   | —         | —         | operator, Instruments  |
| RSS after 10 palette opens | —         | —         | operator               |
| Phase-specific signpost    | —         | —         | operator, Instruments  |

### Baselines never captured — carried forward as an open item

Objective 3 did not land. These need Instruments and Activity Monitor and were not run before the phase
merged: `AppCore.start` duration · `AppIndex.scan` cold vs. warm (first open vs. tenth) ·
`PaletteWindowController.show` · `UninstallScanner.scan` on an app with a large support folder ·
cold launch median of 3 · RSS after 10 palette opens · RSS after browsing 50 clipboard images ·
the four comment-density `grep` figures from review H-1.

The signposts are in place, so any of these can still be taken from `main` at any point — the numbers
are only "before" numbers until a phase actually changes the path they measure. The consequence of the
gap: phases 06–10 and 17 claim performance wins with nothing to measure them against, and phase 34's
final measurement has no baseline column. Capture at least `AppIndex.scan` and cold launch before M2
(phase 11), which is where the review predicts the largest CPU and RAM movement.

---

## Failed tasks

| What | Why it failed | Decision |
| ---- | ------------- | -------- |
| none |               |          |

---

## Issues encountered

- **`withIntervalSignpost` leaks its interval when the wrapped work throws.** The SDK's
  `callSignpostAroundTask` is `let result = try task()` with no `defer`, so the `.end` emit is skipped
  on the throw path. Measured before relying on it: a standalone build where half the calls threw
  emitted 26 begins against 13 ends. The helper therefore owns an explicit `defer` around
  `beginInterval`/`endInterval`; the same test then gave 27/27. This matters for
  `UninstallScanner.scan`, which throws on `Failure.refused` and on `Task.checkCancellation()`.
- The Core regression sweep was run by the operator before merge, after this file was first written.

---

## Deviations from the phase document

- The phase names `withIntervalSignpost` first; the helper uses `beginInterval` + `defer` instead, for
  the reason above. AC2 explicitly permits `defer`, and no call site is affected — every one is a
  single `Signposts.interval("…") { … }` wrapper.
- Four statements were re-wrapped because the added indent level pushed them past 100 columns. No
  statement was reordered and no comment text was edited.

---

## Follow-up work

| Observation                                                                                             | Where                                        | Suggested phase   |
| ------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ----------------- |
| AC2 and the Regression-risks table both treat `withIntervalSignpost` as leak-proof on throw. It is not. | `phases/01-instrumentation-and-baselines.md` | doc fix, no phase |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes — nothing persists, nothing migrates, no later phase reads this
  code (only the operator reads its output).
- **Dependent phases that must also be reverted:** none
- **Data risk on revert:** none

---

## Sign-off

- [x] All acceptance criteria met — AC1–AC6; objective 3 (baselines) deliberately not done, see above
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [x] Merged to `main` — `399189b` (#157)
- [x] **Stopped.** Next phase is a separate session.
