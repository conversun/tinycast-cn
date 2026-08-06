# Phase 17 — Observation: `AppIndex` and the persisted stores

**Milestone:** M2 · **Effort:** L · **Risk:** High · **Context:** High

> **Compatibility policy applies.** See [`../POLICY.md`](../POLICY.md). Verification is a **clean install**, not a
> data-preservation check.

---

## Overview

Migrate the four large state owners: `AppIndex`, `ClipboardStore`, `QuicklinkStore`, `SnippetsStore`.
Two of them are harness-compiled, which constrains what may be added to them.

## Why this phase exists

These four publish the arrays the palette renders. `ClipboardStore.items` in particular republishes
every time the user copies anything, anywhere in macOS — which under `ObservableObject` re-runs the
entire palette body regardless of mode. Migrating them is where the invalidation win actually lands.

## Architecture Review reference

**C-3** wave B · §6 P-1

## Objectives

1. Migrate `AppIndex`, `ClipboardStore`, `QuicklinkStore`, `SnippetsStore` to `@Observable`.
2. Keep `ClipboardStore` and `QuicklinkStore` compilable by their harnesses.
3. Preserve every cache, every `isolated deinit`, and every SQLite lifecycle.

## Expected files to modify

| File                                                      | Change                                                                                               |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Tinycast/Core/AppIndex.swift`                            | `@Observable`; drop `import Combine` if the `settings.$searchScopes` sink already moved in phase 16. |
| `Tinycast/Core/ClipboardStore.swift`                      | `@Observable`. **Harness-compiled — see boundaries.**                                                |
| `Tinycast/Core/Quicklinks/QuicklinkStore.swift`           | `@Observable`. **Harness-compiled — see boundaries.**                                                |
| `Tinycast/Core/Snippets/SnippetsStore.swift`              | `@Observable`; drop `import Combine`. **Harness-compiled.**                                          |
| `Tinycast/Core/PaletteWindowController.swift`             | Four injection sites.                                                                                |
| `Tinycast/Features/RootPaletteView.swift`                 | Four `@EnvironmentObject`s.                                                                          |
| `Tinycast/Features/Clipboard/ClipboardView.swift`         | Consumption.                                                                                         |
| `Tinycast/Features/Quicklinks/QuicklinkListView.swift`    | Consumption.                                                                                         |
| `Tinycast/Features/Settings/QuicklinksSettingsView.swift` | Consumption.                                                                                         |
| `Tinycast/Features/Settings/SnippetsSettingsView.swift`   | Consumption.                                                                                         |
| `Tinycast/Features/Settings/LauncherItemsCard.swift`      | `appIndex` consumption.                                                                              |
| `Tinycast/Features/Settings/ClipboardSettingsView.swift`  | `appIndex` consumption.                                                                              |
| `Tinycast/Core/AppCore.swift`                             | Injection in `showSettings`.                                                                         |

## Files that must NOT change

- `Tinycast/Core/SearchRelevance.swift`, `SearchScopes.swift`, `LauncherRankingStore.swift`,
  `SpotlightNames.swift`, `SettingsPaneScanner.swift`
- `Tinycast/Core/Quicklinks/Quicklink.swift`, `QuicklinkDestination.swift`, `QuicklinkArchive.swift`
- `Tinycast/Core/Snippets/` — everything except `SnippetsStore.swift`
- `Tinycast/Core/Memo.swift`
- `Tinycast/Core/ClipboardManager.swift`

## Implementation boundaries

**The harness constraint dominates this phase.**

- `Tools/clipboard-test.swift`, `Tools/quicklink-test.swift` and `Tools/snippets-test.swift` compile
  these files standalone. `@Observable` is a macro from the `Observation` module, which ships in the OS
  and is available to a plain `swiftc` invocation — **but you must prove it.** Run the three harnesses
  early, before doing the view-side work. If any fails to compile, **stop and report**: the fallback is
  to leave that store on `ObservableObject` and note it as a permanent exception in `AGENTS.md`.
- **`isolated deinit` must survive.** All three of `ClipboardStore`, `QuicklinkStore` and `SnippetsStore`
  use it for SQLite / dispatch-source teardown. `@Observable` must not change their isolation.
- **Every cache stays.** `AppIndex.matchCache`/`Memo`, `ClipboardStore.searchCache` and `orderedCache`,
  and the `items` `didSet` that clears them. If `items` becomes `@Observable`-tracked, its `didSet`
  still runs — verify.
- `AppIndex.publishEntries()`'s `guard updated != apps` early return stays. Under `@Observable`,
  assigning an equal array still notifies.
- `QuicklinkStore.isAvailable` and its "never delete a database that won't open" behaviour are untouched.
- `SnippetsStore.onSnapshot` stays a plain closure — it is a callback to `AppCore`, not an observation.
- `ClipboardStore`'s in-memory window (`memoryWindow = 1000`), pin exemption and trim behaviour are
  untouched.
- Do not touch `ClipboardManager` — it holds the store but publishes nothing itself.

## Detailed acceptance criteria

1. All four types are `@Observable`, **or** an exception is documented with the harness error that
   forced it.
2. `clipboard-test`, `quicklink-test` and `snippets-test` all pass with **no command-line change**.
3. `isolated deinit` is present and unchanged on all three stores that had it.
4. All caches and their invalidation are unchanged.
5. `AppIndex.publishEntries`'s equality guard is present.
6. Copying text updates the clipboard list within ~1 s while the palette is open on the clipboard screen.
7. With `_printChanges` in `RootPaletteView.body`: copying text while the palette is on the **emoji**
   screen produces **no palette re-evaluation**. _(This is the headline result of M2.)_
8. Quicklink CRUD, snippet reload-on-external-edit, and the app index refresh all still drive the UI.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — **all 17 harnesses**, `clipboard-test` / `quicklink-test` /
      `snippets-test` are the critical three
- [ ] `checklists/regression.md` — Core sweep + **Clipboard** + **Quicklinks** + **Snippets** +
      **Launcher & icons** + **Clean install**
- [ ] **The headline check:** open the palette on the emoji screen, add `_printChanges`, copy text
      elsewhere → **no re-evaluation logged**. Record this in the progress file.
- [ ] Copy text → the clipboard list updates; pin it → it moves to Pinned and the highlight follows
- [ ] Copy an image → thumbnail appears
- [ ] Clipboard search with a 2-char and a 4-char query (fallback vs FTS paths)
- [ ] Add, edit, duplicate, pin and delete a quicklink → the launcher and the Settings list both update
- [ ] Edit a snippet file in Finder → the app reloads it within ~150 ms
- [ ] Toggle a feature switch → the launcher section appears/disappears
- [ ] Install or delete an app → reopen the palette → the index reflects it
- [ ] Wipe the Dev channel → launch → every store initialises empty without crashing
- [ ] Add a clip, a quicklink and a snippet, quit, relaunch → all three persisted

## Regression risks

| Risk                                                                            | Mitigation                                 |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| **A harness stops compiling** and the pure-layer invariant is broken            | AC2, run early, with a documented fallback |
| `isolated deinit` lost → SQLite handles leak or teardown races                  | AC3                                        |
| A cache's `didSet` invalidation is lost → stale search results                  | AC4 + the 2-char/4-char search check       |
| `publishEntries` equality guard lost → the launcher re-renders on every refresh | AC5                                        |
| A store crashes rather than starting empty when its file is absent              | The clean-install run                      |
| The clipboard list stops live-updating                                          | AC6                                        |

## Rollback strategy

`git revert <sha>`. **No data risk** — local data is disposable under [`POLICY.md`](../POLICY.md).

This is the largest single-phase revert in M2 — if it goes wrong, revert rather than fix forward, and
consider splitting it into four one-store phases.

## Expected commit size

~13 files, +70 / −90 lines.

## Suggested commit message

```
Migrate AppIndex and the persisted stores to @Observable

AppIndex, ClipboardStore, QuicklinkStore, SnippetsStore. This is where
the invalidation win lands: a clipboard capture no longer re-runs the
whole palette body while the user is on another screen. The isolated
deinits, the SQLite lifecycles and every memo invalidation are unchanged;
the three harnesses still compile these files standalone.
```

## Dependencies

Phase 11, phase 09 (`Memo` in `AppIndex`), phase 16 (`AppSettings`, since `AppIndex.start` observes it).

## Definition of Done

- All acceptance criteria met
- The `_printChanges` headline result recorded in the progress file
- All 17 harnesses green
- Clean-install run verified
- Merged

## Estimated difficulty

**High.** Four large types, two hard constraints, one measurable outcome.

## Estimated Claude context usage

**High** — consider asking Claude to do the four types in sequence within the conversation, verifying
compilation after each.

## Notes for reviewers

- **Run the three harnesses first, before reading any other part of the diff.** If they do not compile,
  nothing else matters.
- Search the diff for `isolated deinit` — three occurrences expected, unchanged.
- Search for `didSet` in `ClipboardStore` — the `items` observer that clears two caches must still be
  there.
- The `_printChanges` result is the reason M2 exists. If the summary does not include it, ask for it
  before approving.
- If this phase feels too large in review, it is legitimate to ask for it to be split into four commits
  on the same branch — one per store — so each is independently bisectable.
