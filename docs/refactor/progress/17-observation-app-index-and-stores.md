# Phase 17 — Observation: `AppIndex` and the persisted stores

---

## Status

| Field                         | Value                                                     |
| ----------------------------- | --------------------------------------------------------- |
| **Status**                    | Complete                                                  |
| **Started**                   | 2026-08-05                                                |
| **Completed**                 | 2026-08-05                                                |
| **Operator**                  | abue-ammar                                                |
| **Branch**                    | `refactor/17-observation-app-index-and-stores`             |
| **Commit**                    | single commit on the branch                               |
| **Claude conversations used** | 1                                                         |
| **Actual effort**             | ~50 min vs. estimate of L (4–8 h)                         |

---

## Completed tasks

- [x] Objective 1 — `AppIndex`, `ClipboardStore`, `QuicklinkStore`, `SnippetsStore` are all `@Observable`;
      every `@Published` and every `ObservableObject` conformance on the four is gone
- [x] Objective 2 — all three harness-compiled stores still compile standalone, **no command-line change**
- [x] Objective 3 — every cache, every `isolated deinit` and every SQLite lifecycle preserved

## Acceptance criteria

- [x] AC1 — all four `@Observable`, no exception needed — verified by: `grep @Published` across the four
      files returns nothing; `@Observable` expands fine under a plain `swiftc -swift-version 6`
- [x] AC2 — `clipboard-test` 23/23, `quicklink-test` 82/82, `snippets-test` ALL PASSED, **no command-line
      change** — verified by: the commands copied verbatim from `docs/development.md`. `raycast-test` also
      compiles `ClipboardStore.swift` and also passes — a **fourth** gate the phase document omits
- [x] AC3 — `isolated deinit` present and unchanged on all three stores — verified by: all three bodies
      are outside the diff entirely
- [x] AC4 — every cache and its invalidation unchanged — verified by: `items`' `didSet` is byte-identical
      and both memo/cache fields took `@ObservationIgnored`; the `didSet`-survives-`@Observable` question
      was settled empirically before any file was edited (below)
- [x] AC5 — `publishEntries`'s equality guard present — verified by: `AppIndex.swift:514`,
      `guard updated != apps else { return }`, outside the diff
- [~] AC6 — copying text updates the clipboard list within ~1 s — **partially verified.** The
      capture → store → SQLite path was exercised live: two `pbcopy` marks landed in `items` in the right
      order with `source_app` attribution, inside 2 s. **The on-screen list update was never observed**
- [~] AC7 — **the headline result.** The **cause was found and fixed**; the `_printChanges` measurement
      was **not run**. See below — this is the most important entry in this file
- [ ] AC8 — quicklink CRUD, snippet reload-on-external-edit and index refresh still drive the UI —
      **not verified interactively.** The store layer is covered by the three harnesses

### AC7 — the migration alone did not achieve the headline win

This is worth recording in full, because a green build and three green harnesses would have hidden it.

`RootPaletteView.body` computed its clipboard follow-key **unconditionally**:

```swift
let clipFollow = ClipFollowKey(id: store.items.first?.id, token: vm.followToken)
```

Every other mode-specific read in that body is gated (`vm.mode == .launcher ? appResults : []` and six
more). This one was not. Under `ObservableObject` that cost nothing extra — `objectWillChange` already
re-ran the whole body for any store change. Under `@Observable` it is precisely what decides the
phase's stated purpose: reading `store.items` in `body` registers the palette as a dependent of
`items`, so **a clipboard capture would still have re-evaluated the entire palette body on the emoji
screen** and the commit message's central claim would have been false.

Scoped to one line, matching the six reads above it:

```swift
let clipFollow = ClipFollowKey(
    id: vm.mode == .clipboard ? store.items.first?.id : nil, token: vm.followToken)
```

**Why this is behaviour-preserving.** The key's sole consumer already opens with
`guard vm.mode == .clipboard, old.id != nil else { return }`. The change introduces exactly one new
key transition — `nil` → an id, on entering the clipboard screen — and that guard's existing
`old.id != nil` clause swallows it, including the `scroll = ScrollIntent(kind: .follow)` after it. Its
comment ("A nil `old.id` is the first load landing, not a row that moved") already describes this case.
Leaving clipboard mode fires the reverse transition, which the `vm.mode` clause swallows.

**What is and is not established.** Off the clipboard screen the ternary never evaluates
`store.items`, so no dependency is registered — a language-level guarantee, by short-circuit, not a
measurement. The `_printChanges` run the phase asks for **did not happen**: driving the palette needs
⌃Space plus keystrokes to reach the emoji screen, and `osascript` cannot send keys in this environment.
The static audit that found the bug was exhaustive — `grep` over `body`'s whole range (lines 213–470)
for `store.` / `appIndex.` / `quicklinks.` / `snippetsStore.` returns **only** that line, so no second
unscoped read of any of the four survives.

**This change is outside the phase document's stated edit for that file** ("Four `@EnvironmentObject`s")
and was approved by the operator before it was made.

### The mechanism, tested rather than assumed

The phase document says of `items`' cache-clearing `didSet`: "If `items` becomes `@Observable`-tracked,
its `didSet` still runs — **verify**." Verified before editing anything, because a silently dropped
`didSet` means permanently stale clipboard search results:

```
didSetRan=2 cache=nil notified=1 items=[1, 2]
```

A `@Observable` class with a `private(set) var` carrying a `didSet`, compiled `-swift-version 6`: two
mutations produced two `didSet` runs, the cache was nilled, and `withObservationTracking` still fired.
So `@Observable` composes with property observers rather than replacing them.

The harness constraint — the phase's dominant risk — was also settled before any view-side work:
`ClipboardStore` was migrated first and `clipboard-test` run immediately, per the hard gate. It passed
first try. `@Observable` needs no import and no flag beyond what those command lines already carry.

### `@ObservationIgnored`, and the rule used

Applied on two grounds, and nowhere else:

| Field(s)                                                      | Why                                                                                                  |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `AppIndex.matchMemo`, `resultsMemo`                           | Written by `matches()` / `orderedResults()`, which views call **during `body`** → "Modifying state during view update". This is the hazard phases 11, 13, 14 and 15 all flagged forward to this one |
| `ClipboardStore.searchCache`, `orderedCache`                  | Same: written by `search()` and `orderedItems`, both read from `body`                                 |
| `ClipboardStore` `db` + 8 statements, `QuicklinkStore` `db` + 3 | Written by `closeDatabase()`, which `isolated deinit` calls — teardown must not enter the registrar   |
| `SnippetsStore` `reloadTask`, `watcherRetryTask`, `directoryWatcher`, `fileWatchers` | Same deinit path; also the recipe's named "retained `Task` handles" category (precedent: `CurrencyRateStore.pump`, `UninstallSession.scanTask`, `ShortcutCaptureSession.monitors`) |

**`AppIndex.entriesRevision` was deliberately left tracked.** On a memo *hit*, `matches()` reads only
`entriesRevision` and `ranking.revision` — never `apps` — so ignoring it would stall the launcher list
after a republish. Exactly the reasoning phase 13 recorded for `VisibilityStore.revision`, and the same
trap in the opposite direction from the memos above it.

### Injection and consumption

| Site                                                      | Change                                                        |
| --------------------------------------------------------- | ------------------------------------------------------------- |
| `PaletteWindowController.ensurePanel()`                    | 3 × `.environmentObject` → `.environment` (appIndex, clipboardStore, quicklinks) |
| `AppCore.showSettings()`                                   | 3 × `.environmentObject` → `.environment` (appIndex, snippetsStore, quicklinks)  |
| `RootPaletteView`                                          | 3 × `@EnvironmentObject` → `@Environment(T.self)`, no type annotation            |
| `ClipboardView` (`ClipboardList`, `ClipboardPreview`)      | 2 × `ClipboardStore`                                          |
| `QuicklinksSettingsView`, `SnippetsSettingsView`, `LauncherItemsCard`, `ClipboardSettingsView`, `QuicklinkEditorSheet`, `AppPickerPopover` | 1 each |

No consumer binds two-way — all four types expose only `private(set)` state — so **no `@Bindable` was
needed anywhere**, unlike phase 16.

Phase 11's "the compiler cannot see a missed injection" hazard **does not apply in this direction**:
`.environmentObject(x)` requires `ObservableObject`, so dropping the conformance turned every injection
site into a compile error. All six were compiler-found, not grep-found.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                                                                                                                       |
| -------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | **Pre-phase baseline captured on this branch before any edit**: `BUILD SUCCEEDED`, 0 source warnings. After: `BUILD SUCCEEDED`, 0 source warnings — a measured delta, not an absolute count. (The single `warning:` in both logs is `appintentsmetadataprocessor`, not a source warning.) Recompilation of all four store files confirmed in the build log rather than assumed. `xcodegen generate` clean, no new file so no `.xcodeproj` churn. Release build and binary size not measured |
| `checklists/testing.md`    | PASS    | **All 16 harnesses green.** The three critical: `clipboard-test` 23/23, `quicklink-test` 82/82, `snippets-test` ALL PASSED. Plus `raycast-test` (also compiles `ClipboardStore`), `fuzz`, `ranking`, `calc`, `scopes`, `emoji`, `custom-command`, `hotkey`, `callout`, `system-action`, `volume`, `window-command`, `uninstall`. The checklist says 17; **16 exist** — `palette-selection-test` arrives in phase 19 |
| `checklists/regression.md` | PARTIAL | **Clean install PASS, interactive sweep waived by the operator.** Dev channel wiped per `POLICY.md`, then launched: all four stores initialised from nothing, `clipboard.sqlite3` + `quicklinks.sqlite3` + `Snippets/` created, no crash, empty stderr, alive 8 s. Two live `pbcopy` captures landed in the right order with source attribution. Relaunched against the populated databases — no crash, so `load()` on non-empty stores is exercised. **Not done:** the `_printChanges` check, pin/unpin, image thumbnails, 2-char vs 4-char search, quicklink CRUD, snippet external edit, feature toggles, app install/delete |
| `checklists/review.md`     | PASS    | Self-check. §1 scope: 14 files; **none from the must-NOT-change list** — `Memo.swift`, `ClipboardManager.swift`, `SearchRelevance.swift`, `SearchScopes.swift`, `LauncherRankingStore.swift`, `SpotlightNames.swift`, `SettingsPaneScanner.swift`, `Quicklink.swift`, `QuicklinkDestination.swift`, `QuicklinkArchive.swift` and the rest of `Core/Snippets/` are all absent from `git diff --name-only`; +56/−53 against an expected +70/−90. §2 no condition, comparison, default, SQL statement, column name, `UserDefaults` key or user-visible string changed; the one logic change is AC7's, recorded above. §3 isolation unchanged — still `@MainActor`, all three `isolated deinit`s intact, no `@unchecked`, no `nonisolated(unsafe)`. §4 nothing newly retained; four `@Published` subjects replaced by four registrars, `memoryWindow` and the trim/pin exemption untouched. §5 comments +0 / −0. §6 two `import Combine` deleted as orphaned; nothing else orphaned. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                     | Before | After  | Δ                                                                                     |
| -------------------------- | ------ | ------ | ------------------------------------------------------------------------------------- |
| Binary size (Release)      | —      | —      | not measured                                                                          |
| Clean install verified?     | —      | **yes** | Dev channel wiped and relaunched; all four stores build their state from nothing       |
| Cold launch, median of 3   | —      | —      | no phase-01 baseline exists; nothing added to `init` or `start()`                       |
| Compiler warnings          | 0      | 0      | measured on this branch, before and after                                              |
| Palette re-evaluation per clipboard capture, off the clipboard screen | every capture | none | by construction (AC7's ternary short-circuit), **not** by `_printChanges` |

M2's whole premise is that last row, and it is the one number still unmeasured. Note that it was
`false` on arrival at this phase and is `true` only because of the one-line palette change — the four
`@Observable` migrations alone would not have moved it.

---

## Failed tasks

none

---

## Issues encountered

- **`RootPaletteView.body` read `store.items` unconditionally**, which would have defeated the phase's
  entire purpose while building green and passing every harness. Full account under AC7 above.
- **Three `@ObservationIgnored` rationale comments were written and then removed.** They explained a
  change just made — barred by the standing contract — and, worse, each contained the words
  "isolated deinit", polluting the exact `grep -rn "isolated deinit"` the phase's *Notes for reviewers*
  prescribes. Comment delta is +0/−0.
- **The kickoff's `grep -rn "isolated deinit" Tinycast` says "expect 3"; the tree has 6.** Three belong
  to this phase (`ClipboardStore`, `QuicklinkStore`, `SnippetsStore`); the others are `ClipboardManager`,
  `HyperKeyTap` and `DoubleTapMonitor`, none in this diff. The document means "three in this phase's
  stores", but the command as written does not say that.
- **A stale `Tinycast Dev.app` under a second DerivedData root** (`Tinycast-exbvcmulq…`, dated Jul 29)
  was found first and discarded in favour of the one `-showBuildSettings` names
  (`Tinycast-faaxgapth…`, built today). Exactly the trap phase 11's progress file warned about; without
  the check the clean-install run would have tested a two-week-old binary.

---

## Deviations from the phase document

- **One behavioural change beyond the phase's stated edits**, operator-approved before implementing:
  the `clipFollow` read in `RootPaletteView.body` is now mode-scoped. Without it AC7 is unachievable.
- **14 files, not the 13 the table lists, and not the same 13.** `QuicklinkListView.swift` is listed but
  references none of the four types and needed no change. `QuicklinkEditorSheet.swift` and
  `AppPickerPopover.swift` are **unlisted** `AppIndex` consumers the compiler forced. Same pattern as
  phase 15's two unlisted consumers.
- **"Four injection sites" and "four `@EnvironmentObject`s" are three each.** `SnippetsStore` is never
  injected into the palette — it reaches Settings only, via `AppCore.showSettings`.
- **A fourth harness gates `ClipboardStore`.** `raycast-test` compiles it too; the phase names only
  three. It passes.
- **Diff is +56/−53 against an expected +70/−90.** The estimate assumed wider consumer churn; the
  `private(set)` state on all four types meant no `@Bindable` conversions at all.
- **`@Observable` widens tracking beyond what `@Published` covered.** `ClipboardStore.maxAge` (never
  `@Published`) and the stores' private scan/state vars are now tracked. No view reads any of them.
  Same class of delta phase 12 recorded for `UninstallSession.app`.
- **`checklists/regression.md` only partially run**, on the operator's instruction, and the phase is
  recorded `Complete` without the interactive sweep — the disposition of phases 13–16. Recorded here
  rather than silently marked PASS. This phase did, however, complete the **clean-install** run that
  `POLICY.md` makes the required verification for a storage phase, which 16 did not.

---

## Follow-up work

| Observation                                                                                                                                                                     | Where                                        | Suggested phase |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | --------------- |
| **AC7's `_printChanges` measurement was never taken.** The reason M2 exists is now correct by construction but unmeasured. Steps: add `let _ = Self._printChanges()` to `RootPaletteView.body`, open the palette on the emoji screen, copy text elsewhere, expect no log line | `Features/RootPaletteView.swift`             | 18, else 34     |
| **No clipboard UI interaction was exercised**: pin/unpin and the highlight following a moved row, image thumbnails, 2-char vs 4-char search (fallback vs FTS)                     | `Features/Clipboard/ClipboardView.swift`     | before merge    |
| **No quicklink CRUD, snippet external edit or feature toggle was exercised** — AC8 is entirely unverified interactively                                                            | Settings panes                               | before merge    |
| Phase doc file-list errors: `QuicklinkListView` listed but unaffected; `QuicklinkEditorSheet` and `AppPickerPopover` unlisted; "four" injection sites are three                    | `phases/17-…md`, `prompts/phase-17.md`       | 35              |
| Kickoff's `isolated deinit` grep says 3; tree-wide it is 6                                                                                                                        | `prompts/phase-17.md`                        | 35              |
| Checklists say "all 17 harnesses"; 16 exist until phase 19 lands `palette-selection-test`                                                                                          | `checklists/testing.md`                      | 19              |
| `AppCore` and `PaletteViewModel` still `ObservableObject`; `PaletteViewModel.followToken` is still `@Published`, and the `assumeIsolated` + deferral `Task` wrappers from 16 remain | `Core/AppCore.swift`                         | 18              |
| No phase-01 Instruments baseline exists, so no M1/M2 phase has before-numbers                                                                                                      | `progress/01`                                 | 34              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory observation mechanism only. No schema change, no
  column rename, no path change, no persisted format touched — both SQLite schemas, every prepared
  statement and the snippet Markdown format are byte-identical either side of the revert.
- **Dependent phases that must also be reverted:** none yet. Phase **18** lists 16 and 17 as
  dependencies and must not be started against a reverted 17.
- **Data risk on revert:** none. Local data is disposable under `POLICY.md`; this phase's clean-install
  run wiped the Dev channel deliberately, and it now holds two throwaway test clips.

---

## Sign-off

- [x] AC1–AC5 met; AC6 partially verified; AC7's cause fixed but unmeasured; AC8 not verified
- [ ] All four checklists passed — three passed, `regression.md` partial (clean install done, interactive
      sweep waived by the operator)
- [x] The `_printChanges` headline result recorded above — **as not run**, with the defect it would have
      caught documented instead
- [x] All 16 existing harnesses green
- [x] Clean-install run verified
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [x] **Does not block phase 18.** 18 depends on 16 and 17, both now `Complete`. It inherits: `AppCore`
      and `PaletteViewModel` still on `ObservableObject`, phase 16's three `assumeIsolated` + deferral
      `Task` wrappers, and the `_printChanges` measurement above — 18 is the natural place to take it,
      since it is the phase that finishes the palette's observation story and retires the Combine sinks.
