# Phase 08 — Parallel uninstall scan

**Milestone:** M1 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

`UninstallScanner.scan()` is serial end to end: one root at a time, then one full recursive
`FileManager.enumerator` walk per directory candidate, back to back on one thread. Parallelise **both**
phases, uncapped. **Display order must not change.**

## Why this phase exists

A well-established app leaves 10–25 leftover directories. Sizing them serially is by far the longest
operation in Tinycast — the code itself notes "roughly a second at 250k" per walk — and the user is
blocked on a "Looking for leftover files…" placeholder while 8–16 cores sit idle.

This is a short, user-initiated burst. Trading a spike of CPU and RAM for wall-clock latency is the
right call here, and it is the one place in the app where it is.

## Architecture Review reference

**H-4** · §6 P-4 · §6.2 K-2

## Objectives

1. Parallelise root enumeration with a `TaskGroup`, writing results into an index-keyed bucket array.
2. Parallelise directory sizing with a `TaskGroup`, writing sizes back by index.
3. Move deduplication **after** the parallel gather so it stays deterministic.
4. Preserve the final ordering exactly.

## Expected files to modify

| File                                             | Change                                                                 |
| ------------------------------------------------ | ---------------------------------------------------------------------- |
| `Tinycast/Core/Uninstall/UninstallScanner.swift` | Both phases become task groups; `scan` becomes `async`.                |
| `Tinycast/Core/Uninstall/UninstallSession.swift` | Await the now-`async` scan; keep the existing `scanTask` cancellation. |

## Files that must NOT change

- `Tinycast/Core/Uninstall/UninstallTarget.swift`
- `Tinycast/Core/Uninstall/UninstallSearchRoot.swift`
- `Tinycast/Core/Uninstall/UninstallRules.swift`
- `Tinycast/Core/Uninstall/UninstallProtection.swift`
- `Tinycast/Core/Uninstall/UninstallPlan.swift`

  _All five are the harness-compiled pure layer. This phase must not touch them._

- `Tinycast/Core/Uninstall/UninstallRunner.swift`
- `Tinycast/Features/Uninstall/UninstallView.swift`

## Implementation boundaries

- **Uncapped by design.** Do not add a `ProcessInfo.activeProcessorCount` limit, a semaphore, or a
  chunking strategy. Short burst, user is waiting, spend the machine.
- **Order is preserved structurally, not incidentally.** Nothing may sort by completion:
  - Phase 1 writes each root's results into a pre-sized array at that root's own index, so
    `UninstallSearchRoot.all` order survives.
  - Phase 2 mutates only the `size` field of a row already in place.
  - The final ordering statement stays exactly as it is:
    ```
    let leftovers = candidates.filter { $0.evidence != .bundle }.sorted { $0.path < $1.path }
    return UninstallPlan(target:, candidates: candidates.filter { $0.evidence == .bundle } + leftovers, …)
    ```
- **Dedup must not race.** The current `seen` `Set` is mutated inside the serial loop. Move it to a
  single pass over the flattened, index-ordered array. Do not share a `Set` across tasks.
- The bundle candidate stays first, and stays outside the parallel gather.
- The `bin` symlink pass may parallelise too, or stay serial — it is cheap. Prefer leaving it serial
  unless it falls out of the same structure naturally.
- `try Task.checkCancellation()` (or `try? …`) inside each child task, so cancelling the parent still
  releases the whole scan.
- `SizeBudget.maxEntries` stays 250,000. This phase does not tune it.
- Do not touch `UninstallRules.matches`, `isAcceptableCandidate`, or the `lstat`/`PathFacts` logic.

## Detailed acceptance criteria

1. Root enumeration runs in a `TaskGroup` with index-keyed writeback.
2. Directory sizing runs in a `TaskGroup` with index-keyed writeback.
3. No shared mutable `Set`, dictionary or array is written from more than one task.
4. **The candidate list, in order, is identical to before** for the same target app — verified by
   screenshot comparison of the full scrolled list.
5. Reported sizes are identical to before.
6. Cancelling (Escape out of the screen) releases the scan promptly; no orphaned task.
7. `Tools/uninstall-test.swift` passes with no source or command-line change.
8. Scan wall time improves measurably against the phase-01 baseline.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `uninstall-test` is mandatory
- [ ] `checklists/regression.md` — Core sweep + **Uninstall** in full
- [ ] **Before the phase:** run a scan on a heavyweight app (an IDE, a browser, an Adobe app), screenshot
      the full scrolled list including sizes and the summary line
- [ ] After: same app, same list, same order, same sizes, same total
- [ ] Repeat on an app with **no** leftovers — the bundle-only case still works
- [ ] Repeat on an app with a **locked** candidate — it is still locked and uncheckable
- [ ] Escape mid-scan → returns to the launcher immediately, no spinner, no late state update
- [ ] Run the scan twice in a row → identical list both times (determinism)
- [ ] `UninstallScanner.scan` signpost shows the improvement; record before/after
- [ ] Activity Monitor during a scan: CPU spikes then returns; RSS returns to baseline afterwards

## Regression risks

| Risk                                                                                   | Mitigation                                                 |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **List order changes** — the explicit user requirement                                 | AC4, verified by screenshot on a real app, twice           |
| Non-deterministic output because dedup raced                                           | AC3 + the "run it twice" check                             |
| A candidate is dropped because two roots produced the same path and dedup ran per-task | Dedup is one pass over the flattened array                 |
| Cancellation stops working, leaving work running after the screen closes               | AC6                                                        |
| Peak RAM spikes beyond acceptable                                                      | One enumerator per walk, a few KB each; measure and record |
| The pure layer gets edited to make the parallelism easier                              | The five files are on the must-not-change list             |

## Rollback strategy

`git revert <sha>`. Scan results are computed fresh every time; nothing persists. Fully safe.

## Expected commit size

2 files, +70 / −45 lines.

## Suggested commit message

```
Parallelise the uninstall scan

Both phases — root enumeration and directory sizing — now run in task
groups, uncapped: a short user-initiated burst where wall-clock latency
matters more than peak CPU. Results are written back by index, so the
displayed order is unchanged by construction. Dedup runs once over the
flattened array rather than racing a shared set.
```

## Dependencies

Phase 01 (the `UninstallScanner.scan` signpost is the measurement).

## Definition of Done

- All acceptance criteria met
- Before/after list screenshots compared and attached to the progress file
- Timing delta recorded
- `uninstall-test` green
- Merged

## Estimated difficulty

**Medium.** Structured concurrency in a `nonisolated` context, with an ordering invariant.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Compare the list screenshots pixel by pixel on ordering.** This is the acceptance test the user
  called out by name. Sizes can be spot-checked; order cannot.
- Search the diff for `.sorted` and confirm the only sort is the existing path sort on leftovers.
- Search for `seen.insert` and confirm it happens in exactly one place, outside any task group.
- If the summary claims a speedup without a signpost number, ask for the number.
- Confirm `UninstallSession.cancel()` still calls `scanTask?.cancel()` and that the `guard !Task.isCancelled`
  after the await is still there.
