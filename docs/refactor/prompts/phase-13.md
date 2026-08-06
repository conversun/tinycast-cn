# Phase 13 kickoff — Observation wave A: leaf stores

Read `docs/refactor/phases/13-observation-leaf-stores.md` completely, and follow the
`### Migration recipe` from `docs/refactor/progress/11-observation-pilot-favorites-store.md`.

## Task

Migrate `VisibilityStore`, `CalculatorHistoryStore` and `FrequentEmojiStore` to `@Observable`.

## Hard gates

- **Persistence is untouched.** Every `defaults.set(…)` and `data.write(to:)` stays where it is, on the
  same trigger. The easiest silent regression here is a `didSet` refactored away along with `@Published`.
- **Memo invalidation is untouched.** If phase 09 landed, these stores route caches through `Memo` and
  `VisibilityStore` carries a `revision`. All of it stays and keeps working.
- `VisibilityStore.revision` must keep incrementing on all four mutating methods.
- Keep `private(set)` on every published property.
- **Convert the Settings-window injection sites too.** `AppCore.showSettings` injects six objects into
  `SettingsRootView`. A missed one is a **runtime crash** when a pane first reads it — not a compile
  error, and possibly not on the pane you happen to test.
- Do not touch `Core/Calculator/*`, `Core/Emoji/EmojiCatalog.swift`, `EmojiGridGeometry.swift`,
  `EmojiData.generated.swift`, `Memo.swift` or `AppIndex.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run `emoji-test` and `calc-test`.

**Then run the app and open the Settings window**, then visit Applications, Window Management and every
other pane that reads one of these three stores. That is where a missed injection surfaces.

## Summarise

Use the system-prompt format. **List every injection site you converted**, palette and Settings window
separately, so the reviewer can count them against `AppCore.showSettings`.
