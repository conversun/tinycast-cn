# Phase 01 — Instrumentation and baselines

**Milestone:** M0 · **Effort:** S · **Risk:** Low · **Context:** Low

---

## Overview

Add permanent `os_signpost` intervals around the five operations this roadmap claims to improve, then
record the numbers they produce. Nothing else changes.

## Why this phase exists

Every later phase promises a measurable effect — "80 fewer plist parses per palette open", "6–12× faster
uninstall scan", "fewer body evaluations". Without a baseline captured _before_ any of them land, those
claims are unfalsifiable and the roadmap degrades into hoping.

Signposts are effectively free at runtime when no Instruments session is attached, so these stay in the
code permanently rather than being added and removed per phase.

## Architecture Review reference

Roadmap W0 (§5) · §6 Performance table, which every entry says to measure

## Objectives

1. Add a single `Signposts` helper exposing one `OSSignposter` on a `com.tinycast.perf` subsystem.
2. Wrap these five intervals, and only these:
   - `AppIndex.scan` — the detached app + settings-pane scan
   - `AppIndex.rank` — the scoring pass
   - `PaletteWindowController.show` — summon to ordered-front
   - `UninstallScanner.scan` — the full uninstall scan
   - `AppCore.start` — the synchronous launch path
3. Record the baseline measurements in the progress file.

## Expected files to modify

| File                                             | Change                                                       |
| ------------------------------------------------ | ------------------------------------------------------------ |
| `Tinycast/Core/Signposts.swift`                  | **New.** One `OSSignposter`, one interval helper. ~20 lines. |
| `Tinycast/Core/AppIndex.swift`                   | Wrap `scan` and `rank`.                                      |
| `Tinycast/Core/PaletteWindowController.swift`    | Wrap `show`.                                                 |
| `Tinycast/Core/Uninstall/UninstallScanner.swift` | Wrap `scan`.                                                 |
| `Tinycast/Core/AppCore.swift`                    | Wrap `start`.                                                |

## Files that must NOT change

- Any file compiled by a `Tools/` harness — `SearchRelevance.swift`, `LauncherRankingStore.swift`,
  `SearchScopes.swift`, `ClipboardStore.swift`, everything in `Core/Calculator/`, `Core/Emoji/`,
  `Core/Snippets/`, `Core/Quicklinks/`, `Core/WindowManagement/`, and the five pure
  `Core/Uninstall/` files. **Adding `import os` to any of them breaks its harness.**
- `Core/EdgeDissolve.swift`, `Core/ThinScrollbar.swift`
- Any view file

## Implementation boundaries

- **Instrumentation only.** No logic changes, no reordering, no extraction.
- Do not add signposts anywhere beyond the five named intervals.
- Do not add `os_log` statements. Signposts only.
- The helper must not retain state beyond the single `OSSignposter` instance.
- `UninstallScanner.scan` and `AppIndex.scan` are `nonisolated` — the helper must be usable from there
  without introducing isolation.

## Detailed acceptance criteria

1. `Tinycast/Core/Signposts.swift` exists and declares exactly one `OSSignposter` on subsystem
   `com.tinycast.perf`.
2. All five intervals emit `begin`/`end` events, including on the early-return and `throw` paths — use
   `withIntervalSignpost` or a `defer`, never a manual end that a `return` can skip.
3. Zero behaviour change: no statement reordered, no condition altered.
4. Release build succeeds; binary growth is under 0.5 %.
5. No new import appears in any harness-compiled file.
6. Net comment lines added ≤ 5; zero stacked comment blocks.

## Manual verification checklist

- [ ] `checklists/build.md`, including the Release build and binary-size step
- [ ] `checklists/testing.md` — run **all** harnesses to prove no purity break
- [ ] `checklists/regression.md` — Core sweep only
- [ ] Instruments ▸ os_signpost: open the palette, confirm `AppIndex.scan` and
      `PaletteWindowController.show` intervals appear
- [ ] Run an uninstall scan on a heavyweight app; confirm the interval appears

## Baseline capture (operator, not Claude)

Record all of this in the progress file — later phases compare against it.

| Metric                                 | How                                                |
| -------------------------------------- | -------------------------------------------------- |
| Release binary size                    | `stat -f%z` on the built executable                |
| Cold launch, median of 3               | Quit fully, relaunch, time to menu-bar icon        |
| `AppCore.start` duration               | Instruments                                        |
| `AppIndex.scan` cold / warm            | Instruments, first open vs. tenth                  |
| `PaletteWindowController.show`         | Instruments                                        |
| `UninstallScanner.scan`                | Instruments, on an app with a large support folder |
| RSS after 10 palette opens             | Activity Monitor                                   |
| RSS after browsing 50 clipboard images | Activity Monitor                                   |
| Comment density                        | The four `grep` figures from review H-1            |

## Regression risks

| Risk                                                               | Mitigation                                                             |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `import os` added to a harness-compiled file breaks the test suite | Full harness run is a gate                                             |
| A manually-ended interval leaks on an early return                 | Acceptance criterion 2 requires `defer` or `withIntervalSignpost`      |
| Signposts in a hot loop add overhead                               | Only five call sites, all coarse-grained; none inside a per-entry loop |

## Rollback strategy

`git revert <sha>`. Fully self-contained — nothing persists, nothing migrates, no dependent phase reads
this code (only the operator reads its output).

## Expected commit size

~5 files, +60 / −0 lines.

## Suggested commit message

```
Add signpost instrumentation for the refactor baseline

Five coarse intervals — app scan, ranking, palette show, uninstall scan,
launch — so the refactor roadmap's performance claims are measurable.
No behaviour change.
```

## Dependencies

None. This is the first phase.

## Definition of Done

- All acceptance criteria met
- Baselines recorded in `progress/01-instrumentation-and-baselines.md`
- `ROADMAP.md` status updated
- Merged to `main`

## Estimated difficulty

**Low.** Mechanical. The only trap is putting a signpost in a harness-compiled file.

## Estimated Claude context usage

**Low** — five files, four of them read-mostly.

## Notes for reviewers

- Check the `import os` list first: `git diff --name-only` cross-referenced against
  `checklists/testing.md`'s harness table. This is the one way this phase can break something.
- Confirm intervals cannot leak. `AppIndex.scan` has a `continue` inside a `repeat` loop and
  `UninstallScanner.scan` has several `throw` paths.
- Do not accept extra signposts "while we're here". Five, exactly.
