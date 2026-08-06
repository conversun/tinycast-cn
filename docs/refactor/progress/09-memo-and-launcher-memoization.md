# Phase 09 — `Memo` primitive and launcher result memoization

---

## Status

| Field                         | Value                                          |
| ----------------------------- | ---------------------------------------------- |
| **Status**                    | Complete                                       |
| **Started**                   | 2026-08-05                                     |
| **Completed**                 | 2026-08-05                                     |
| **Operator**                  | abue-ammar                                     |
| **Branch**                    | `refactor/09-memo-and-launcher-memoization`    |
| **Commit**                    | single commit on the branch                    |
| **Claude conversations used** | 1                                              |
| **Actual effort**             | ~1 h vs. estimate of M (~2 h)                  |

---

## Completed tasks

- [x] Objective 1 — `Tinycast/Core/Memo.swift`: an 11-line single-slot memo, no imports
- [x] Objective 2 — Adopted in `AppIndex.matchCache`, `CalculatorHistoryStore.searchCache`,
      `EmojiIndex.searchCache`, `FrequentEmojiStore.sortedGlyphs`
- [x] Objective 3 — `revision` counters on `VisibilityStore` and `FavoritesStore`
- [x] Objective 4 — `AppIndex.orderedResults(query:visibility:favorites:)`, memoized
- [x] Objective 5 — `appResults` and `compactFavoriteSlots` point at it; `selectedAppEntry` and
      `actionsContent` read `appResults`, so both are memoized without an edit

## Acceptance criteria

- [x] AC1 — `Memo.swift` Foundation-only, under 30 lines, no state beyond the single slot — verified by:
      11 lines, **no import at all**, one `private var slot: (key: Key, value: Value)?`, one
      `mutating func value(for:build:)`. No capacity, no expiry, no lock, no generics beyond
      `Key: Equatable`
- [x] AC2 — All four adoptions compile and behave identically — verified by: Debug and Release
      `BUILD SUCCEEDED`; each key reproduces its predecessor's invalidation exactly (table below)
- [x] AC3 — `ClipboardStore` untouched — verified by: `git diff --name-only | grep ClipboardStore`
      empty; `clipboard-test` 23/23 with no command-line change
- [x] AC4 — `orderedResults` identical to the old `appResults` chain — verified by: the chain is the
      old four lines moved verbatim, in the same order, with the same trim (`q.isEmpty` is what
      `isQueryEmpty` computed). Operator confirmed the four cases interactively
- [x] AC5 — Favourite, item-hide, category-hide and launch each invalidate the memo — verified by:
      seven mutators bump a revision (`FavoritesStore.toggle/remove/replace`,
      `VisibilityStore.setItemVisible/removeItemKeys/setKindVisible/replace`) and all five revisions
      are in `ResultsKey`. Operator confirmed the list updates on the next render
- [x] AC6 — `compactFavoriteSlots` no longer builds a dictionary per render — verified by:
      `favorites.ordered(…)` replaced with `prefix(while: favorites.isFavorite)` over the memoized
      list. Equivalence checked by a scratch harness compiling the shipped `Memo.swift`: 2 000
      randomized cases including duplicate `preferenceKey`s, all agreeing with `ordered().favorites`
- [x] AC7 — Section order and favourite pinning unchanged — verified by: operator, interactively
- [ ] AC8 — `AppIndex.rank` signpost shows no regression — **not verified.** Phase 01 never captured
      Instruments baselines, so there is no before-number. Per-render allocation provably drops (the
      whole chain is now one memo read on a repeat render), but the figure is unmeasured

---

## The four adoptions — old invalidation → new key

| Site                                | What invalidated the old cache                                  | Key term covering it              |
| ----------------------------------- | --------------------------------------------------------------- | --------------------------------- |
| `AppIndex.matchCache`               | `matchCache = nil` in `publishEntries`; inline `ranking.revision` | `entriesRevision`, `rankingRevision` |
| `CalculatorHistoryStore.searchCache` | `= nil` in `persist()` — reached by `record`/`remove`/`clearAll` | `revision`, bumped in `persist()` |
| `EmojiIndex.searchCache`            | `= nil` in `load()`                                              | `revision`, bumped in `load()`    |
| `FrequentEmojiStore.sortedGlyphs`   | `= nil` at the top of `record()`                                 | `revision`, bumped in `record()`  |

Each counter is bumped in the same place the old clear happened, so the ordering relative to the
mutation is unchanged — and all four are synchronous `@MainActor` paths, so nothing can read a memo
between the bump and the mutation it describes.

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                                                                                              |
| -------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | §1 `xcodegen generate` clean; `.xcodeproj` churn is the one new file (correct). §2 Debug `BUILD SUCCEEDED`, zero warnings from the changed files — **no pre-phase baseline was captured on this branch**, so "zero *new* warnings" is asserted against the file list, not a baseline. §3 Release `BUILD SUCCEEDED`, no type-checker timeout — run because `Memo<Key, Value>` is generic. §4 binary size not measured. §5/§6 operator ran the app |
| `checklists/testing.md`    | PASS   | The four harnesses the phase names: `fuzz-test`, `ranking-test`, `emoji-test`, `clipboard-test` — all pass. The other 13 were **not** run; no changed file is compiled by any of them. Purity intact: `SearchRelevance`, `LauncherRankingStore` and `ClipboardStore` are untouched                             |
| `checklists/regression.md` | PASS   | Run by the operator, manually. Recorded on the operator's confirmation — Claude ran no interactive verification in this session                                                                                                                                                                                     |
| `checklists/review.md`     | PASS   | §1 scope: 9 files, none from the must-NOT-change list, one file added, `.xcodeproj` regenerated; +101/−53 against an expected +110/−70. §2 no condition, comparison, default or nil-handling change; no user-visible string touched. §3 no new task, timer or observer; no isolation weakened. §4 the two new memos replace two hand-rolled caches of the same size — nothing newly retained. §5 comments +7/−4, zero new stacked blocks, every authored line ≤100 chars. §6 no dead code — `MatchCache`, `searchCache` ×2 and `sortedGlyphs` all deleted. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                     | Before | After | Δ                                                                       |
| -------------------------- | ------ | ----- | ----------------------------------------------------------------------- |
| Binary size (Release)      | —      | —     | not measured                                                            |
| Clean install verified?    | —      | n-a   | no storage, no persisted format, not in the clean-install list           |
| Cold launch, median of 3   | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`        |
| RSS after 10 palette opens | —      | —     | not measured                                                            |
| `AppIndex.rank`            | —      | —     | no phase-01 baseline exists (AC8)                                       |

No performance numbers were taken this phase. The win is structural rather than measurable at this
size: on a repeat render with an unchanged query the launcher chain — a `filter` plus a dictionary
build over ~300–400 entries — collapses to one key comparison.

---

## Failed tasks

none

---

## Issues encountered

- **The phase document's results key is incomplete.** Objective 4 specifies
  `(query, rankingRevision, visibilityRevision, favoritesRevision)`. Those four can all be unchanged
  while `apps` changes — `refresh()` runs on **every launcher open**, and a snippet, quicklink or
  custom-command edit republishes directly — which would strand a stale list. See **Deviations**.
- **Four comments in `RootPaletteView` now describe `appResults` as unmemoized** and are wrong. The
  `openActions()` one is explicitly protected until phase 23, so the whole family was left alone
  rather than fixing three of four. See **Follow-up work**.

---

## Deviations from the phase document

- **`ResultsKey` carries a fifth term, `entriesRevision`**, bumped in `publishEntries()` and also part
  of `MatchKey` (where it replaces the old `matchCache = nil`). The phase document names four terms;
  the fifth is required by its own **Implementation boundaries** rule that each key must encode
  exactly the dependencies its old invalidation covered — `publishEntries`'s clear was one of them.
  Without it the launcher would show a stale list after any republish.
- **A ninth file changed: `Tinycast/Features/Launcher/CalculatorCardView.swift`** — one word in a doc
  comment that referenced `AppIndex.matchCache`, the symbol this phase renamed. Not in
  **Expected files to modify**, not in **Files that must NOT change**. No code change.
- **`Memo.swift` has no `import` line at all.** AC1 asks for Foundation-only; the type uses nothing
  from Foundation, so the import would be dead.
- **One moved comment now exceeds the comment budget.** `EmojiIndex`'s "A keyword hit is penalized…"
  line was already 111 characters; moving it inside the memo closure re-indented it to 115. Moved
  unchanged per the system prompt rather than rewritten.

---

## Follow-up work

| Observation                                                                                                              | Where                                                    | Suggested phase        |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------- | ---------------------- |
| Four comments still call `appResults` unmemoized; one is protected until the palette split                                | `Features/RootPaletteView.swift` ~105, 241, 825, 853      | 23 (launcher screen)   |
| `CalcMemo` is a fifth hand-rolled one-slot memo the phase did not list as an adoption site                                | `Features/Launcher/CalculatorCardView.swift:8`            | none — or a later tidy |
| Phase-01 Instruments baselines were never captured, so AC8 has no before-number                                           | `progress/01`                                             | 34 (final measurement) |
| `ClipboardStore`'s two caches stay hand-rolled; adopting `Memo` needs a `clipboard-test` command-line change              | `Core/ClipboardStore.swift`                               | an `AGENTS.md` decision |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. Purely in-memory — no persistence, no migration, no format.
- **Dependent phases that must also be reverted:** none. No phase lists 09 as a dependency, though
  **17** (`AppIndex` → `@Observable`) is easier with this landed and 11 adds `@Observable` to the
  `FavoritesStore` whose `revision` this phase introduced.
- **Data risk on revert:** none.

---

## Sign-off

- [x] All acceptance criteria met **except AC8** (no phase-01 baseline to measure against)
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
