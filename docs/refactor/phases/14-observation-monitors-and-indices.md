# Phase 14 — Observation wave A: monitors and indices

**Milestone:** M2 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

Migrate `RunningAppsMonitor`, `EmojiIndex` and `CurrencyRateStore` — the three wave-A types that are
driven by something outside the app.

## Why this phase exists

These three are fed by a workspace notification, an async catalog load, and a network fetch
respectively. They are the first migrations where the _producer_ is not a user gesture, which makes them
the right place to confirm the recipe holds when updates arrive off the main flow.

`CurrencyRateStore` additionally carries a consent gate that must survive intact.

## Architecture Review reference

**C-3** · Roadmap W2 wave A

## Objectives

1. Migrate `RunningAppsMonitor`, `EmojiIndex` and `CurrencyRateStore` to `@Observable`.
2. Preserve `CurrencyRateStore`'s four consent guards exactly.
3. Preserve `RunningAppsMonitor`'s change-suppression (`guard next != runningBundleIDs`).

## Expected files to modify

| File                                                         | Change                                                     |
| ------------------------------------------------------------ | ---------------------------------------------------------- |
| `Tinycast/Core/RunningApps.swift`                            | `@Observable`.                                             |
| `Tinycast/Core/Emoji/EmojiIndex.swift`                       | `@Observable`.                                             |
| `Tinycast/Core/CurrencyRateStore.swift`                      | `@Observable`; drop `import Combine` if unused.            |
| `Tinycast/Core/PaletteWindowController.swift`                | Three injection sites.                                     |
| `Tinycast/Features/RootPaletteView.swift`                    | Two `@EnvironmentObject`s (`emojiIndex`, `currencyRates`). |
| `Tinycast/Features/Launcher/LauncherView.swift`              | `@EnvironmentObject private var runningApps`.              |
| `Tinycast/Features/Emoji/EmojiGridView.swift`                | If it consumes `emojiIndex`.                               |
| `Tinycast/Features/Settings/MiscellaneousSettingsView.swift` | `@ObservedObject … currencyRates` → plain `let`.           |

## Files that must NOT change

- `Tinycast/Core/Emoji/EmojiCatalog.swift`, `EmojiGridGeometry.swift`, `EmojiData.generated.swift` —
  harness-compiled
- `Tinycast/Core/Calculator/CalcCurrency.swift`, `CurrencyData.generated.swift` — harness-compiled
- `Tinycast/Core/NotificationToken.swift`

## Implementation boundaries

- **`CurrencyRateStore`'s consent model is frozen.** All four guards stay exactly where they are:
  1. `init` — no snapshot read without consent
  2. `source` — returns `.off` without consent
  3. `start()` — no pump without consent
  4. `fetchAndStore()` — re-checked **before** the request and again **after** the `await`

  The consent flag stays on this store, **not** in `AppSettings`. The `URLSession` stays `.ephemeral`
  with `urlCache = nil`. `setEnabled(false)` still deletes the cached file.

- `RunningAppsMonitor.refresh()` keeps its `guard next != runningBundleIDs` early return. Under
  `@Observable`, assigning an equal value still notifies observers — so removing that guard would
  re-render every launcher row on every helper-process launch.
- `EmojiIndex.load()` stays `async` and keeps its `Task.detached` parse. Do not make the catalog load
  eager or synchronous.
- `EmojiIndex`'s `searchCache` (or `Memo`, post phase 09) stays and keeps its invalidation.
- `RunningAppsMonitor` is deliberately **not** observed by `RootPaletteView` — only `LauncherList`
  observes it, so a workspace launch does not re-render the whole palette. **Preserve that.** Do not add
  it to `RootPaletteView`.

## Detailed acceptance criteria

1. All three types are `@Observable`.
2. `CurrencyRateStore`'s four consent guards are present and unchanged.
3. `RunningAppsMonitor`'s equality guard is present.
4. `RootPaletteView` still does **not** observe `RunningAppsMonitor`.
5. Launching or quitting an app updates the running dot in the launcher without re-rendering the palette.
6. The emoji grid shows "Loading emoji…" then populates.
7. With currency conversion off, a currency query produces no card and **no network request**.
8. Turning it on shows the consent sheet, then rates land and the inline card evaluates.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `emoji-test`, `calc-test`
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons** + **Calculator & currency**
- [ ] Launch an app from outside Tinycast while the palette is open → its running dot appears
- [ ] Quit it → the dot disappears
- [ ] With `Self._printChanges()` temporarily in `RootPaletteView.body`: launch an app → **the palette
      body must not re-evaluate**
- [ ] Open the emoji grid on a cold launch → loading state, then the grid
- [ ] Search emoji → results rank as before
- [ ] **Currency off:** type "100 usd to eur" → no card. Confirm with Console/Charles that no request
      leaves the machine
- [ ] Turn currency on → consent sheet names Frankfurter → accept → "Update Now" → a card appears
- [ ] Turn it off → the cached `currency-rates.json` is deleted from
      `~/Library/Caches/com.tinycast.app.dev/`

## Regression risks

| Risk                                                                                                                     | Mitigation                             |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------- |
| **A consent guard is dropped and the app fetches without permission.** A privacy regression, the most serious kind here. | AC2 + the network-off verification     |
| The cached rates file is not deleted on opt-out                                                                          | Explicit filesystem check              |
| `RunningAppsMonitor` gets added to `RootPaletteView` "for consistency"                                                   | AC4 + the `_printChanges` check        |
| The equality guard is removed, causing a re-render storm                                                                 | AC3                                    |
| Emoji catalog load becomes eager, hurting startup                                                                        | Boundary; check `AppCore.start` timing |

## Rollback strategy

`git revert <sha>`. The consent flag and the cached rates file are unaffected by a revert — both are
plain UserDefaults/file state read the same way either side.

## Expected commit size

8 files, +35 / −45 lines.

## Suggested commit message

```
Migrate the monitors and indices to @Observable

RunningAppsMonitor, EmojiIndex and CurrencyRateStore. The currency
consent guards, the running-apps equality guard, and the deliberate
choice not to observe RunningAppsMonitor from RootPaletteView are all
preserved.
```

## Dependencies

Phase 11.

## Definition of Done

- All acceptance criteria met
- Network-off behaviour verified by observation, not by reading the code
- `_printChanges` check confirms the palette is not re-rendering on app launches
- Merged

## Estimated difficulty

**Medium.** The consent surface is what makes this more than mechanical.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Read all four consent guards in the diff.** They are load-bearing privacy controls, not defensive
  programming. `AGENTS.md` names them.
- The `guard next != runningBundleIDs` line is three words long and easy to lose in a refactor. Find it.
- Verify `RootPaletteView`'s `@EnvironmentObject` count went down by two, not three.
- If `import Combine` was removed from `CurrencyRateStore`, confirm nothing else in the file needed it.
