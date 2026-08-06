# Phase 11 — Observation pilot: `FavoritesStore`

**Milestone:** M2 · **Effort:** S · **Risk:** Med · **Context:** Low

---

## Overview

Migrate exactly one store to `@Observable` to establish the pattern, prove the mechanics, and write down
the recipe every later M2 phase follows. One type, one conversation, one commit.

## Why this phase exists

The Observation migration is the largest single win in the roadmap and touches 26 types. Doing it
type-by-type is only safe if the _first_ one is done deliberately and the resulting recipe is recorded.
`FavoritesStore` is the right pilot: 53 lines, one `@Published` property, two consumers, and its effects
are immediately visible in the launcher.

## Architecture Review reference

**C-3** · §6 P-1 · §6.2 K-1 · Roadmap W2

## Objectives

1. Convert `FavoritesStore` from `ObservableObject`/`@Published` to `@Observable`.
2. Update both consumers to `@Environment`.
3. **Record the migration recipe** in the progress file for phases 12–18 to follow.

## Expected files to modify

| File                                            | Change                                                                                        |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `Tinycast/Core/FavoritesStore.swift`            | `@Observable`; drop `@Published`; drop `import Combine` if unused.                            |
| `Tinycast/Core/PaletteWindowController.swift`   | `.environmentObject(core.favorites)` → `.environment(core.favorites)`.                        |
| `Tinycast/Features/RootPaletteView.swift`       | `@EnvironmentObject private var favorites` → `@Environment(FavoritesStore.self)`.             |
| `Tinycast/Features/Launcher/LauncherView.swift` | Only if `AppActionsMenu` takes `favorites` — it takes it as a parameter, so likely no change. |

## Files that must NOT change

- Any other store. This phase is one type.
- `Tinycast/Core/AppCore.swift` — it holds `let favorites = FavoritesStore()`; that line does not change
- `Tinycast/Core/Backup/SettingsBackup.swift` — it calls `favorites.replace(keys:)` directly, unaffected

## Implementation boundaries

- `private(set) var keys: [String]` keeps its access control and its type.
- **`revision` (added in phase 09) must remain and keep incrementing.** `AppIndex.orderedResults` keys
  its memo on it, and `@Observable` does not replace that — the memo is a value cache, not a view
  dependency.
- Do not change any method signature, any UserDefaults key, or the `ordered(_:)` split logic.
- `@Environment(FavoritesStore.self)` yields an optional in some formulations. Use the non-optional form
  and inject with `.environment(_:)` — do not introduce optionality into the view.
- Do not migrate any other type "since we're here".
- Do not remove `import Combine` from files that still need it for other types.

## Detailed acceptance criteria

1. `FavoritesStore` is `@Observable`; no `@Published`, no `ObservableObject` conformance.
2. Both injection and consumption use `.environment` / `@Environment`.
3. `revision` still increments on `toggle`, `remove` and `replace`.
4. Adding or removing a favourite updates the launcher **on the next render**, in both expanded and
   compact modes.
5. `SettingsBackup` import still replaces the favourites list and the UI reflects it.
6. No other type's observation mechanism changed.
7. `Self._printChanges()` (temporarily, during verification) shows `RootPaletteView` no longer
   re-evaluating for unrelated store changes that previously went through `FavoritesStore`.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons**
- [ ] Add a favourite via the Actions menu → it appears in the Favorites section immediately
- [ ] Remove it → it leaves immediately
- [ ] Compact mode with favourites on: slots update immediately when a favourite is added
- [ ] With 6+ favourites: five slots plus "…" overflow; ⌘1–⌘5 launch the right apps
- [ ] Import a settings backup containing favourites → the list updates
- [ ] Quit and relaunch → favourites persist in the same order

## Regression risks

| Risk                                                                                                            | Mitigation                             |
| --------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| **The view stops updating.** A missing `@Environment` registration compiles fine and fails silently at runtime. | AC4 + the interactive add/remove test  |
| The compact bar's slots go stale                                                                                | Explicit compact-mode check            |
| `revision` is dropped as "redundant now"                                                                        | AC3 — it serves the memo, not the view |
| The optional `@Environment` form leaks into the view and hides a missing injection                              | Boundary note                          |

## Rollback strategy

`git revert <sha>`. In-memory only.

## Expected commit size

3 files, +12 / −12 lines.

## Suggested commit message

```
Migrate FavoritesStore to @Observable

Pilot for the Observation migration: one leaf store, two consumers.
Establishes the recipe the remaining M2 phases follow. The revision
counter stays — it feeds AppIndex's result memo, not the view.
```

## Dependencies

Phase 01. Phase 09 if it landed first (for `revision`). **Blocks phases 12–18.**

## Definition of Done

- All acceptance criteria met
- **The recipe is written into the progress file**, covering:
  - the exact `@Observable` / `@Environment` edit pattern
  - how `.environmentObject` injection sites are converted
  - which `import Combine` lines can go and which cannot
  - the manual check that proves the view still updates
- Merged

## Estimated difficulty

**Low** as code. The value is in the recipe, not the diff.

## Estimated Claude context usage

**Low.**

## Notes for reviewers

- This phase's real deliverable is the **recipe**. If the progress file's recipe section is thin, the
  next seven phases will each rediscover the same problems. Push back on a thin write-up harder than on
  the code.
- Verify the view genuinely still updates by _using_ it, not by reading the diff. This is the failure
  mode that compiles cleanly and ships broken.
- Confirm `PaletteWindowController.ensurePanel()` converted the right one of its 15 `.environmentObject`
  calls and left the other 14 alone.
