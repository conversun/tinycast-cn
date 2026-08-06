# Phase 17 kickoff — Observation: `AppIndex` and the persisted stores

Read `docs/refactor/phases/17-observation-app-index-and-stores.md` completely.

## Task

Migrate `AppIndex`, `ClipboardStore`, `QuicklinkStore` and `SnippetsStore` to `@Observable`.

**Do the four in sequence, verifying compilation after each**, rather than all at once.

## Hard gates — read these before writing anything

- **Three of these four are compiled standalone by `Tools/` harnesses.** `@Observable` comes from the
  `Observation` module, which ships in the OS and should be available to a plain `swiftc` — **but prove
  it before doing any view-side work.** Migrate `ClipboardStore`, run `clipboard-test`. If it fails to
  compile, **stop and report**: the fallback is leaving that store on `ObservableObject` and recording a
  permanent exception in `AGENTS.md`.
- **`isolated deinit` must survive on all three stores that have it.** It tears down SQLite statements
  and dispatch sources. `@Observable` must not change their isolation.
- **Every cache stays**, with its invalidation: `AppIndex`'s match memo, `ClipboardStore`'s
  `searchCache` and `orderedCache`, and the `items` `didSet` that clears both. Verify the `didSet` still
  runs.
- **`AppIndex.publishEntries()`'s `guard updated != apps` early return stays.** Under `@Observable`,
  assigning an equal array still notifies.
- `QuicklinkStore.isAvailable` and its never-delete-a-bad-database behaviour are untouched.
- `SnippetsStore.onSnapshot` stays a plain closure — it is a callback to `AppCore`, not an observation.
- `ClipboardStore`'s `memoryWindow`, pin exemption and trim behaviour are untouched.
- Do not touch `ClipboardManager.swift`, `Memo.swift`, or any pure file under `Core/Quicklinks/` or
  `Core/Snippets/`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "isolated deinit" Tinycast     # expect 3
```

Run **all** harnesses. `clipboard-test`, `quicklink-test` and `snippets-test` are the critical three.

**Then run the app** and capture the headline result: put `let _ = Self._printChanges()` in
`RootPaletteView.body`, open the palette on the **emoji** screen, copy text in another app, and confirm
**no palette re-evaluation is logged**. Remove the `_printChanges` line afterwards.

## Summarise

Use the system-prompt format. Report the `_printChanges` result explicitly — it is the reason M2 exists.
If a harness forced an exception, name it and quote the compiler error.
