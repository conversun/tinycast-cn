# Phase 13 — Observation wave A: leaf stores

**Milestone:** M2 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

Migrate the three persisted leaf stores: `VisibilityStore`, `CalculatorHistoryStore`,
`FrequentEmojiStore`.

## Why this phase exists

These three persist to disk and back a visible list, so they exercise the recipe against a store whose
mutations must both persist _and_ invalidate a memo — a combination the pilot did not cover.

None is harness-compiled, none has manual `objectWillChange`, and each has a small, well-understood
consumer set.

## Architecture Review reference

**C-3** · Roadmap W2 wave A

## Objectives

1. Migrate `VisibilityStore`, `CalculatorHistoryStore`, `FrequentEmojiStore` to `@Observable`.
2. Preserve every persistence path and every memo invalidation exactly.
3. Verify each store's list updates immediately on mutation.

## Expected files to modify

| File                                                            | Change                                                                   |
| --------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `Tinycast/Core/VisibilityStore.swift`                           | `@Observable`.                                                           |
| `Tinycast/Core/CalculatorHistoryStore.swift`                    | `@Observable`.                                                           |
| `Tinycast/Core/Emoji/FrequentEmojiStore.swift`                  | `@Observable`.                                                           |
| `Tinycast/Core/PaletteWindowController.swift`                   | Three injection sites.                                                   |
| `Tinycast/Features/RootPaletteView.swift`                       | Three `@EnvironmentObject`s.                                             |
| `Tinycast/Features/Settings/LauncherItemsCard.swift`            | `visibility` consumption.                                                |
| `Tinycast/Features/Settings/WindowManagementSettingsView.swift` | `visibility` consumption.                                                |
| `Tinycast/Features/Calculator/CalculatorHistoryView.swift`      | If it consumes the store.                                                |
| `Tinycast/Features/Emoji/EmojiGridView.swift`                   | If it consumes the store.                                                |
| `Tinycast/Core/AppCore.swift`                                   | Only if a `.environmentObject` call for these appears in `showSettings`. |

## Files that must NOT change

- `Tinycast/Core/Emoji/EmojiCatalog.swift`, `EmojiGridGeometry.swift`, `EmojiData.generated.swift` —
  harness-compiled
- `Tinycast/Core/Calculator/*` — harness-compiled
- `Tinycast/Core/Memo.swift` — consumed, not modified
- `Tinycast/Core/AppIndex.swift`

## Implementation boundaries

- **Persistence is untouched.** Every `defaults.set(…)` and every `data.write(to:)` stays exactly where
  it is, on the same trigger. `@Observable` changes how observers are notified, not when data is saved.
- **Memo invalidation is untouched.** If phase 09 landed, `CalculatorHistoryStore` and
  `FrequentEmojiStore` route their caches through `Memo` and `VisibilityStore` carries a `revision`.
  All of that stays and keeps working — `@Observable` does not replace a value-level memo.
- `VisibilityStore.revision` must keep incrementing on all four mutating methods.
- Do not change `private(set)` on any published property.
- Do not change the `Set<String>` → `Array` conversions in the UserDefaults writes; the ordering is
  already non-deterministic and that is existing behaviour.
- Settings panes read these stores via `@EnvironmentObject` injected in `AppCore.showSettings`. Convert
  those injection sites too — a mismatch there is a runtime crash on opening Settings, not a compile
  error.

## Detailed acceptance criteria

1. All three types are `@Observable`.
2. Every injection site — palette **and** Settings window — converted consistently.
3. Hiding an item in Settings ▸ Applications immediately hides it in the launcher.
4. Hiding a whole category immediately removes its section.
5. Deleting a calculator history entry with ⌘⌫ removes the row immediately.
6. Using an emoji updates the Frequently Used section on the next open.
7. All three stores persist across a relaunch.
8. `VisibilityStore.revision` still increments; the launcher memo still invalidates.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `emoji-test`, `calc-test`
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons** + **Calculator** + **Settings**
- [ ] **Open the Settings window** — it must not crash (this is where a missed injection site shows up)
- [ ] Settings ▸ Applications: untick an app → it disappears from the launcher immediately
- [ ] Untick the "Show in launcher" category switch → the whole section disappears
- [ ] Settings ▸ Window Management: untick a command → it leaves the launcher
- [ ] Re-tick everything → everything returns
- [ ] Calculator History: ⌘⌫ on a row → it vanishes; relaunch → still gone
- [ ] Emoji grid: use three emoji → reopen → they are in Frequently Used, most-used first
- [ ] Quit and relaunch → hidden items, history and emoji frequencies all persist

## Regression risks

| Risk                                                                     | Mitigation                                                |
| ------------------------------------------------------------------------ | --------------------------------------------------------- |
| **A Settings pane crashes on open** because an injection site was missed | AC2 + "open the Settings window" as the first manual step |
| A store persists but the view goes stale                                 | AC3–AC6                                                   |
| `revision` dropped, launcher memo goes stale                             | AC8                                                       |
| Emoji frequency sort cache not invalidated                               | AC6                                                       |

## Rollback strategy

`git revert <sha>`. All three read from disk on init; nothing about their file format changes.

## Expected commit size

10 files, +40 / −45 lines.

## Suggested commit message

```
Migrate the persisted leaf stores to @Observable

VisibilityStore, CalculatorHistoryStore and FrequentEmojiStore. Both the
palette and the Settings-window injection sites are converted. Persistence
and memo invalidation are unchanged.
```

## Dependencies

Phase 11. Phase 09 if it landed (memo/revision interplay).

## Definition of Done

- All acceptance criteria met
- Settings window opened and every affected pane exercised
- Merged

## Estimated difficulty

**Low–Medium.** The Settings-window injection sites are the trap.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- `AppCore.showSettings` injects six objects into `SettingsRootView`. Count them in the diff — a partial
  conversion crashes the Settings window the first time a pane reads a missing environment value, and
  that crash may not surface on the pane you happen to test.
- Confirm nothing in these three stores stopped writing to disk. The easiest silent regression here is a
  `didSet` that got refactored away along with `@Published`.
- If `Memo` adoption from phase 09 was undone "to simplify", revert.
