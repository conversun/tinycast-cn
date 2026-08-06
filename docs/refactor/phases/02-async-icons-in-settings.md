# Phase 02 — Async icons in the Settings launcher list

**Milestone:** M1 · **Effort:** S · **Risk:** Low · **Context:** Low

---

## Overview

`Settings ▸ Applications` rasterises app icons synchronously on the main thread. The palette already
solved this with `AppIconView`. Use it, then delete the synchronous path so it cannot come back.

## Why this phase exists

`LauncherItemRow` renders `Image(nsImage: entry.icon)` (`LauncherItemsCard.swift:75`). `AppEntry.icon`
calls `IconCache.icon(forFile:)` synchronously, which on a cold key calls `NSWorkspace.shared.icon` and
rasterises a 96×96 bitmap — on the main thread, inside a `LazyVStack` of ~200 rows, during scrolling.

This is the one place in the app where the codebase's own performance rule is broken, and the fix
already exists twelve files away.

## Architecture Review reference

**H-3** · §6 P-3 ("the single best effort-to-benefit item in the document")

## Objectives

1. Replace the synchronous icon render in `LauncherItemRow` with `AppIconView`.
2. Delete `AppEntry.icon` and any now-unused helper it was the sole caller of.
3. Confirm no other synchronous icon path remains in a list context.

## Expected files to modify

| File                                                 | Change                                                                                                                                              |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Tinycast/Features/Settings/LauncherItemsCard.swift` | `Image(nsImage: entry.icon)` → `AppIconView(app: entry)` at the same frame size.                                                                    |
| `Tinycast/Core/AppIndex.swift`                       | Delete `AppEntry.icon`.                                                                                                                             |
| `Tinycast/Features/Settings/AppPickerPopover.swift`  | Only if `AppPresentation` is the other caller and can move to the async path without changing behaviour. **If it cannot, leave it and report why.** |

## Files that must NOT change

- `Tinycast/Features/Launcher/LauncherView.swift` — `AppIconView` is already correct; do not "improve" it
- `IconCache`'s caching strategy, cost limits or `displayPixel`
- Any other Settings pane

## Implementation boundaries

- `AppIconView` is used **as-is**. Do not add parameters, do not generalise it, do not move it.
- The rendered frame stays `22 × 22` — that is the Settings row size, not the palette's `rowIcon`.
- Do not change `IconCache` in any way. This phase consumes it; it does not touch it.
- If `AppEntry.icon` has a caller you cannot safely convert, leave the property and say so. A
  half-deleted property is worse than a documented one.

## Detailed acceptance criteria

1. `LauncherItemRow` renders through `AppIconView`; no synchronous `IconCache` call remains in it.
2. Warm icons still paint on the first frame with **no placeholder flash** — `AppIconView`'s `init`
   seeds from the cache synchronously and that behaviour must be preserved.
3. `AppEntry.icon` is deleted, or its remaining caller is named in the summary with a reason.
4. Icon size, corner radius and row layout are pixel-identical.
5. `grep -rn "IconCache.icon(forFile" Tinycast` returns only the internal call inside `IconCache`.
6. No behaviour change beyond decode timing.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons**
- [ ] Open Settings ▸ Applications on a machine with 150+ apps. First paint shows placeholders that fill
      in; **no beachball, no scroll hitch**
- [ ] Scroll the full list quickly, twice. Second pass is instant (cache warm)
- [ ] Compare icon rendering against a pre-phase screenshot — same size, same crispness
- [ ] Settings ▸ Commands, System Actions, System Settings panes still render their icons

## Regression risks

| Risk                                          | Mitigation                                                                                   |
| --------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Placeholder flash appears on reopen           | AC2 — `AppIconView`'s synchronous cache seed must be preserved; verify by reopening the pane |
| Icon renders at the wrong size                | AC4 — screenshot comparison                                                                  |
| `AppEntry.icon` had a caller you missed       | AC5 — repo-wide grep                                                                         |
| Symbol-icon entries (commands, actions) break | `AppIconView` branches on `isSymbolIcon`; verify the Commands pane specifically              |

## Rollback strategy

`git revert <sha>`. No persistence, no migration, no dependent phase.

## Expected commit size

2–3 files, +5 / −15 lines.

## Suggested commit message

```
Render Settings launcher icons through AppIconView

The Settings item rows rasterised icons synchronously on the main thread
inside a LazyVStack; the palette's AppIconView already decodes off-main
with a synchronous cache seed. Removes AppEntry.icon so the synchronous
path cannot return.
```

## Dependencies

Phase 01 (baselines).

## Definition of Done

- All acceptance criteria met
- All four checklists passed
- `ROADMAP.md` updated, progress file committed, merged

## Estimated difficulty

**Low.** Genuinely a two-line change plus a deletion.

## Estimated Claude context usage

**Low.**

## Notes for reviewers

- The whole diff should be ~20 lines. Anything larger means `IconCache` or `AppIconView` was touched —
  revert.
- The subtle failure is the placeholder flash. `AppIconView.init` seeds `_image` from
  `IconCache.cached…`; if that is lost the pane flickers on every reopen. Reopen the pane three times.
- Watch for `AppIconView` being copied rather than imported. There must be exactly one definition.
