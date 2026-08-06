# Phase 07 — Settings-pane scan cache

**Milestone:** M1 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

`SettingsPaneScanner.scan()` re-reads and re-parses ~40 `.appex` `Info.plist` files **and** their
`InfoPlist.loctable` files on every palette open. Cache the result, keyed on the extensions directory's
modification date — the same mtime trick `SpotlightNames.Cache` already uses one function away.

## Why this phase exists

`AppIndex.refresh()` runs on every `showPalette(mode: .launcher)`. Inside the detached scan it calls
`SettingsPaneScanner.scan()` unconditionally. That is ~80 file reads plus ~80
`PropertyListSerialization` deserialisations every time the user presses the launcher hotkey, for data
that changes only on an OS update.

## Architecture Review reference

**H-2** · §6 P-2

## Objectives

1. Cache the scanned pane entries, invalidated by the modification date of
   `/System/Library/ExtensionKit/Extensions`.
2. Thread the cache through `AppIndex` as a **value**, exactly as `alternateNameCache` already is —
   avoid introducing static mutable state.
3. Preserve the pane list, its ordering and its display names exactly.

## Expected files to modify

| File                                      | Change                                                                                                           |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `Tinycast/Core/SettingsPaneScanner.swift` | `scan()` gains a `cache:` parameter and returns `([AppEntry], Cache)`, mirroring `SpotlightNames.Cache`'s shape. |
| `Tinycast/Core/AppIndex.swift`            | Hold the pane cache alongside `alternateNameCache`; pass it into `scan` and store what comes back.               |

## Files that must NOT change

- `Tinycast/Core/SpotlightNames.swift` — it is the pattern to copy, not to edit
- `Tinycast/Core/SearchScopes.swift` — harness-compiled
- `Tinycast/Core/SearchRelevance.swift` — harness-compiled
- Any view file

## Implementation boundaries

- **Prefer the value-threaded cache over a static.** `AppIndex.refresh()` already does
  `let reusing = alternateNameCache` → detached scan → `alternateNameCache = cache`. Do exactly that
  again for panes. This keeps `SettingsPaneScanner` free of shared mutable state and free of a lock.
- If a `Sendable` constraint makes value-threading genuinely impossible, a static guarded by an
  `NSLock` is acceptable — but say so in the summary and justify it. Do not reach for
  `nonisolated(unsafe)` without a lock.
- Invalidation key is **only** the extensions directory's `contentModificationDate`. Do not add a
  time-based expiry, a launch-count heuristic, or a manual refresh path.
- Do not change `displayName`, `loctableName`, `isSettingsPane`, `nameOverrides` or `skippedBundleIDs`.
- Do not cache anything else in this phase — not `Bundle(url:)` results, not `SearchScopes.appBundles`.
  Those are separate decisions with separate measurements.
- The scan stays `nonisolated` and runs inside the existing `Task.detached`.

## Detailed acceptance criteria

1. A second `AppIndex.refresh()` with an unchanged extensions directory performs **zero** plist reads.
   Verified with the `AppIndex.scan` signpost from phase 01, or with `fs_usage`.
2. The published `AppEntry` list for `.systemSettings` is identical before and after — same count, same
   ids, same names, same order.
3. The cache is invalidated when the directory's mtime changes.
4. No static mutable state, or a justified locked one.
5. `AppIndex.scan` remains `nonisolated` and is still called from `Task.detached`.
6. First-open cost is unchanged (cold path is the same work).

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `fuzz-test`, `ranking-test`, `scopes-test`
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons**
- [ ] Capture the System Settings section of the launcher before the phase (screenshot the full list)
- [ ] After: the section lists the same panes, same names, same order
- [ ] Search for a pane by a localized name (e.g. in a non-English locale if available) — still found
- [ ] `AppIndex.scan` signpost: first open vs. tenth open shows a clear drop
- [ ] Instruments ▸ File Activity or `sudo fs_usage -w -f filesys Tinycast` during the tenth open shows
      no reads under `/System/Library/ExtensionKit/`
- [ ] Panes still appear after a relaunch (cache is per-process, so the cold path must still work)

## Regression risks

| Risk                                                         | Mitigation                                                                                                |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| A pane installed mid-session is missed                       | Directory mtime changes when a pane is installed; and this is impossible in practice outside an OS update |
| Pane display names change (localization lookup skipped)      | AC2 screenshot comparison                                                                                 |
| Static mutable state introduces a data race under Swift 6    | AC4; prefer the value-threaded form                                                                       |
| Cache retained forever, growing memory                       | ~40 small `AppEntry` values, bounded by the directory; note the size in the progress file                 |
| Ordering changes because the cache returns an unsorted array | AC2                                                                                                       |

## Rollback strategy

`git revert <sha>`. Purely in-memory; nothing persists.

## Expected commit size

2 files, +45 / −15 lines.

## Suggested commit message

```
Cache the System Settings pane scan by directory mtime

AppIndex.refresh() runs on every palette open and re-parsed ~40 .appex
Info.plist and loctable files each time, for data that changes only on an
OS update. Threaded through AppIndex as a value like SpotlightNames.Cache.
```

## Dependencies

Phase 01 (the `AppIndex.scan` signpost is how you verify this).

## Definition of Done

- All acceptance criteria met
- Signpost delta recorded in the progress file
- Pane list verified identical
- Merged

## Estimated difficulty

**Medium.** The `Sendable` threading through `Task.detached` is the fiddly part.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- Read `SpotlightNames.Cache` first, then read the new code. If it does not look like a sibling of it,
  push back — matching an existing idiom is worth more here than any cleverness.
- Check the `init(reusing:)` semantics were copied thoughtfully: `SpotlightNames.Cache` deliberately
  carries forward _only_ entries this pass asked about, so uninstalled apps fall out. Panes do not need
  that (the directory listing is the whole set) but the reviewer should confirm the difference was
  considered rather than overlooked.
- Verify the empty-directory case: if `contentsOfDirectory` fails, the current code returns `[]`. Make
  sure that failure is not cached as a successful empty scan forever.
