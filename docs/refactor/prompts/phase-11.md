# Phase 11 kickoff — Observation pilot: `FavoritesStore`

Read `docs/refactor/phases/11-observation-pilot-favorites-store.md` completely before editing.

## Task

Migrate **exactly one** store — `FavoritesStore` — from `ObservableObject`/`@Published` to
`@Observable`, and update its two consumers.

**The real deliverable is the recipe**, not the diff. Seven later phases follow it.

## Hard gates

- **One type.** Do not migrate anything else "since we're here". If another store appears in the diff,
  the phase has failed.
- `private(set) var keys: [String]` keeps its access control and type.
- **`revision` stays and keeps incrementing** on `toggle`, `remove` and `replace`. It feeds
  `AppIndex`'s result memo, which is a value cache, not a view dependency — `@Observable` does not
  replace it.
- Use the **non-optional** `@Environment(FavoritesStore.self)` form and inject with `.environment(_:)`.
  Do not let optionality leak into the view; it hides a missing injection.
- `PaletteWindowController.ensurePanel()` has ~15 `.environmentObject` calls. Convert **one**.
- Do not change any method signature, any UserDefaults key, or the `ordered(_:)` split logic.
- Remove `import Combine` only from files where nothing else needs it.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only    # expect 3 files
```

**Then run the app and actually add and remove a favourite.** A missing `@Environment` registration
compiles cleanly and fails silently at runtime — the build proves nothing here.

## Summarise

Use the system-prompt format, **plus a section titled `### Migration recipe`** covering:

- the exact `@Observable` / `@Environment` edit pattern, as a before/after snippet
- how `.environmentObject` injection sites convert
- which `import Combine` lines can go and which cannot
- what `@ObservationIgnored` is for and when a property needs it
- the manual check that proves a view still updates

Write it for someone who has not read this conversation. It is the input to phases 12–18.
