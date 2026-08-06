# Phase 23 kickoff — Screen: `launcher`, and collapsing the calc offset

Read `docs/refactor/phases/23-screen-launcher-and-offset-collapse.md` completely.

**This is the highest-risk phase in the roadmap.** Consider doing it as two commits on one branch:
rendering first, then chords.

## Task

Add `LauncherScreen`, empty `RootPaletteView`'s switches entirely, and collapse the last `calcCount`
computations.

## Hard gates

- **The section table is the invariant.** Nine sections in this exact order, matching
  `AppIndex.publishEntries`'s slice order or the flat index breaks:
  `Favorites, Applications, System Settings, Quicklinks, Snippets, System Actions, Window Management,
Custom Commands, Commands`.
  **Copy it verbatim.** Do not re-derive it, sort it, or make it data-driven.
- **Keep the explicit type annotation on the section array.** Inference times out on it — that is why
  the annotation exists, and Release is the build that proves it.
- The `favoriteCount` prefix logic stays: with an empty query, favourites are the leading `favoriteCount`
  entries of `results`; `rest` is everything after, filtered by `kind`.
- **The calculator card is `rows[0]`**, as phase 22 established. After this phase
  `grep -rn "calcCount" Tinycast` must return **nothing**.
- **Chords into the screen:** ⌘↵ (Show in Finder, only when `canRevealInFinder`), ⌃⇧Q (quit, only for a
  running `.application`), ⌘1–⌘5 (compact favourite slots).
- **These stay in `RootPaletteView`:** header and search field, footer bar, both menu overlays, ⌘K,
  Escape, Tab, bare-Backspace routing, ⌘, and ⌘W, the compact/expanded frame sync, and
  `onChange(of: vm.mode)`'s session cleanup.
- The compact favourites strip is rendered in the **header** (palette-level). Move the _derivation_ into
  the screen and let the header ask for it — do not duplicate it.
- Remove `openActions()`'s `if vm.mode == .launcher` workaround and its comment, **only if phase 09 is
  merged**. If not, leave it and say so.
- Do not change `AppActionsMenu`'s rows, ordering or conditions. Do not touch `AppIndex.swift`,
  `FavoritesStore`, `VisibilityStore`, `RunningApps` or `AppCore.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release CODE_SIGNING_ALLOWED=NO
grep -rn "calcCount" Tinycast     # must be empty
```

Extend the selection harness with nine sections + favourites + calc card. Run **all** harnesses.

The diff should be **net negative** — roughly +450 / −800. A net-positive diff means the switches were
replaced rather than removed.

## Summarise

Use the system-prompt format. State `RootPaletteView`'s final line count and confirm no `switch vm.mode`
over screens remains in it.
