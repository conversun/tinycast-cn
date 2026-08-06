# Phase 14 kickoff — Observation wave A: monitors and indices

Read `docs/refactor/phases/14-observation-monitors-and-indices.md` completely, and follow the
`### Migration recipe` from `docs/refactor/progress/11-observation-pilot-favorites-store.md`.

## Task

Migrate `RunningAppsMonitor`, `EmojiIndex` and `CurrencyRateStore` to `@Observable`.

## Hard gates

**`CurrencyRateStore`'s consent model is frozen. All four guards stay exactly where they are:**

1. `init` — no snapshot read from disk without consent
2. `source` — returns `.off` without consent
3. `start()` — no pump without consent
4. `fetchAndStore()` — re-checked **before** the request **and again after the `await`**, because
   consent can be withdrawn mid-flight

Also unchanged: the consent flag lives on this store and not in `AppSettings`; the `URLSession` is
`.ephemeral` with `urlCache = nil`; `setEnabled(false)` deletes the cached file.

- **`RunningAppsMonitor.refresh()` keeps its `guard next != runningBundleIDs` early return.** Under
  `@Observable`, assigning an equal value still notifies — removing that guard re-renders every launcher
  row on every helper-process launch.
- **`RootPaletteView` must NOT observe `RunningAppsMonitor`.** Only `LauncherList` does, deliberately, so
  a workspace launch does not re-render the whole palette. Do not "fix" this.
- `EmojiIndex.load()` stays `async` with its `Task.detached` parse. Do not make it eager or synchronous.
- `EmojiIndex`'s search cache and its invalidation stay.
- Do not touch `EmojiCatalog.swift`, `EmojiGridGeometry.swift`, `EmojiData.generated.swift`,
  `CalcCurrency.swift` or `CurrencyData.generated.swift` — all harness-compiled.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run `emoji-test` and `calc-test`.

**Then run the app**: with currency conversion **off**, type a currency query and confirm no card appears
and nothing leaves the machine. Launch an app externally and confirm the running dot appears.

## Summarise

Use the system-prompt format. **Quote all four consent guards** in your summary, with their line
context, so the reviewer can confirm each is present without opening the file.
