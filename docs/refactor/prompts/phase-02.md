# Phase 02 kickoff — Async icons in the Settings launcher list

Read `docs/refactor/phases/02-async-icons-in-settings.md` completely before editing.

## Task

`LauncherItemRow` in `Features/Settings/LauncherItemsCard.swift` renders `Image(nsImage: entry.icon)`,
which rasterises synchronously on the main thread inside a `LazyVStack`. Use the existing `AppIconView`
instead, then delete `AppEntry.icon`.

## Hard gates

- **Use `AppIconView` exactly as it is.** Do not add parameters, do not generalise it, do not move it,
  do not copy it. There must remain exactly one definition.
- The rendered frame stays `22 × 22` — that is the Settings row size, not the palette's `rowIcon`.
- **Do not touch `IconCache`** — not its cost limits, not `displayPixel`, not its caching strategy.
- Preserve the no-placeholder-flash behaviour: `AppIconView.init` seeds `_image` synchronously from the
  cache. If that is lost, the pane flickers on every reopen.
- Delete `AppEntry.icon`. If a caller exists you cannot safely convert, **leave the property and name
  the caller in your summary** — a half-deleted property is worse than a documented one.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "IconCache.icon(forFile" Tinycast     # expect only the internal call inside IconCache
```

The whole diff should be roughly 20 lines. If it is much larger, you have touched something you should
not have.

## Summarise

Use the system-prompt format. State the final line count of the diff.
