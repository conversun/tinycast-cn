# Phase 09 kickoff — `Memo` primitive and launcher result memoization

Read `docs/refactor/phases/09-memo-and-launcher-memoization.md` completely before editing.

## Task

Two halves of one objective — eliminate repeated per-render work behind one memo primitive:

1. Add `Tinycast/Core/Memo.swift` (< 30 lines) and adopt it at four sites.
2. Add `revision` to `VisibilityStore` and `FavoritesStore`, then add
   `AppIndex.orderedResults(query:visibility:favorites:)` memoized on
   `(query, rankingRevision, visibilityRevision, favoritesRevision)`, and point four `RootPaletteView`
   call sites at it.

## Hard gates

- `Memo` is a struct with **one** optional `(key, value)` slot and one `mutating func value(for:build:)`.
  No LRU, no capacity, no expiry, no thread-safety story, no generics beyond `Key: Equatable`.
- **Adopt in exactly four places:** `AppIndex.matchCache`, `CalculatorHistoryStore.searchCache`,
  `EmojiIndex.searchCache`, `FrequentEmojiStore.sortedGlyphs`.
- **Do NOT touch `ClipboardStore`.** It is harness-compiled and `AGENTS.md` requires it to depend on no
  other app source. Its two caches stay exactly as they are.
- **Each adoption's key must encode every dependency its old invalidation covered.** `sortedGlyphs` is
  cleared in `record()`; `CalculatorHistoryStore.searchCache` is cleared in `persist()`. Both need a
  mutation counter in the key, not just the query.
- `revision` uses `&+=` and increments on **every** mutation that can change the visible set:
  `FavoritesStore.toggle/remove/replace`; `VisibilityStore.setItemVisible/removeItemKeys/setKindVisible/replace`.
- `orderedResults` performs the current chain in the current order:
  `matches(query)` → `.filter(visibility.isVisible)` → if the query is empty and favourites exist,
  `favorites.ordered(base)` → `favorites + rest`. **Do not reorder or optimise the chain** — visibility
  filtering stays downstream of `matches` so the match memo is never keyed on hidden state.
- Do **not** remove the `openActions()` workaround or its `if vm.mode == .launcher` guard. That is
  phase 23.
- Do not touch `SearchRelevance` or `LauncherRankingStore`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only | grep ClipboardStore     # must be empty
```

Run `fuzz-test`, `ranking-test`, `emoji-test`, `clipboard-test`.

## Summarise

Use the system-prompt format. For **each** of the four adoptions, state what invalidated the old cache
and which part of the new key covers it.
