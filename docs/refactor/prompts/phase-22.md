# Phase 22 kickoff — Screens: `clipboard` and `calculatorHistory`

Read `docs/refactor/phases/22-screens-clipboard-and-calculator-history.md` completely.

## Task

Add `ClipboardScreen` and `CalculatorHistoryScreen`. This is the first screen carrying the inline
calculator card, so it establishes the pattern phase 23 reuses.

## Hard gates

- **The calculator card becomes `rows[0]`, not an offset variable.** For the history screen, `rows` is
  `[.calc(result)] + entries.map(Row.entry)` when a result exists, and the flat selection indexes `rows`
  directly. `calcCount` must not appear in either new file. Phase 23 depends on this being right.
- **`CalculatorCardView` is shared with the still-un-migrated launcher.** Do not move it, do not
  parameterise it, do not duplicate it. `grep -rn "struct CalculatorCard" Tinycast` must return one.
- **The clipboard's follow-the-moved-row behaviour is precise. Copy it exactly:**
  - The change key is `ClipFollowKey(id: store.items.first?.id, token: vm.followToken)` — read from the
    **store**, not from the filtered results, so typing a query never reads as a row that moved.
  - A nil `old.id` is the first load landing, not a move — it must not reposition the selection.
  - Selection follows only when the query is empty **and** the head id actually changed.
  - The scroll intent becomes `.follow` regardless.
- Chords into the screens — clipboard: ⌘P, ⌘⌫, ⌘↵ (copy without pasting). History: ⌘⌫ (**never the calc
  card**), ⌘↵ (copy the expression).
- The empty-history case renders `EmptyResults` across the **whole panel**, not inside the narrow list
  column. Preserve that branch.
- An **error** calc card is selectable but has no action: it must not drive the pill, ⌘K, or ↵.
- `ClipboardPreview`, `ClipboardInfoSection`, `AsyncThumbnail` and `DateBucket` move unchanged. Do not
  edit them.
- Do not touch `ClipboardStore.swift`, `Core/Calculator/*`, `CalculatorHistoryStore.swift` or
  `AppCore.swift`. Do not migrate the launcher.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "calcCount" Tinycast/Features/Clipboard Tinycast/Features/Calculator   # must be empty
```

Extend the selection harness with a leading calc row; run it plus `clipboard-test` and `calc-test`.

**Then run the app**: open clipboard history, **type a query**, then copy something in another app. The
selection must **not** jump. That is the bug the store-vs-results distinction exists to prevent.

## Summarise

Use the system-prompt format. Quote the new `ClipFollowKey` construction so the reviewer can confirm it
still reads `store.items.first?.id`.
