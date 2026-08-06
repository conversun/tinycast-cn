# Phase 18 — Observation: palette, `AppCore`, and retiring the Combine sinks

**Milestone:** M2 · **Effort:** L · **Risk:** High · **Context:** High

---

## Overview

The last two observable types — `PaletteViewModel` and `AppCore` — plus the reason M2 was worth doing to
the concurrency model: delete the eight Combine sink blocks and the `MainActor.assumeIsolated` hazards
they exist to bridge.

## Why this phase exists

Six near-identical sink blocks in `AppCore.start()`, one in `AppIndex.start()` and one in
`HyperKeyTap.start()` all follow the same triple-indirection shape:

```
publisher.dropFirst()
    .sink { [weak self] _ in
        MainActor.assumeIsolated {
            guard let self else { return }
            Task { self.applyXPresence() }   // deferred: @Published emits *before* the write
        }
    }
    .store(in: &cancellables)
```

`assumeIsolated` **traps at runtime** if the assumption is ever violated. The deferral `Task` exists only
because `@Published` emits before the property is written. `@Observable` emits after, so both disappear.

## Architecture Review reference

**C-3** wave B · **§6.2 K-1** ("delete ~30 `MainActor.assumeIsolated` blocks")

## Objectives

1. Migrate `PaletteViewModel` and `AppCore` to `@Observable`.
2. Replace all eight `settings.$…` sinks with `withObservationTracking`.
3. Delete the deferral `Task` wrappers and the `assumeIsolated` blocks those sinks required.
4. Remove `import Combine` and the `cancellables` sets wherever they become unused.

## Expected files to modify

| File                                          | Change                                                                                             |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `Tinycast/Core/AppCore.swift`                 | `@Observable` on both `PaletteViewModel` and `AppCore`; six sinks → tracking; drop `cancellables`. |
| `Tinycast/Core/AppIndex.swift`                | `searchScopes` sink → tracking; drop `cancellables`.                                               |
| `Tinycast/Core/HotKey/HyperKeyTap.swift`      | `hyperKey` sink → tracking; drop `cancellables`.                                                   |
| `Tinycast/Core/PaletteWindowController.swift` | `core` and `palette` injection.                                                                    |
| `Tinycast/Features/RootPaletteView.swift`     | `core` and `vm` observation.                                                                       |
| `Tinycast/Core/PalettePanel.swift`            | It holds `weak var paletteViewModel` — see boundaries.                                             |
| Various `Features/Settings/*`                 | `@ObservedObject private var core = AppCore.shared` sites.                                         |

## Files that must NOT change

- Any store migrated in phases 11–17
- `Tinycast/Core/Snippets/SnippetKeywordListener.swift` — its `assumeIsolated` blocks bridge **CGEvent
  tap callbacks**, not Combine. Those are correct and stay.
- `Tinycast/Core/HotKey/DoubleTapMonitor.swift`, `HotKeyCenter.swift` — same, C-callback bridges
- `Tinycast/Core/RunningApps.swift`, `Core/Snippets/SnippetsStore.swift` — their `assumeIsolated` blocks
  bridge `NotificationCenter` / `DispatchSource`, not Combine

## Implementation boundaries

- **Only the Combine-bridging `assumeIsolated` blocks are removed.** The ones bridging Carbon handlers,
  CGEvent taps, `DispatchSource` handlers, `Timer` blocks and `NotificationCenter` blocks are correct
  and load-bearing. Count them before and after: the expected delta is exactly the eight sink sites.
- **The reconciliation must still be correct.** Each of the six `AppCore` sinks reconciles a feature's
  presence. With `@Observable` the callback fires _after_ the write, so the deferral `Task` is no longer
  needed — **but `withObservationTracking`'s `onChange` fires once and must be re-registered**. Use a
  helper that re-arms, or the tracking silently stops after the first change. This is the single most
  likely bug in this phase.
- `PaletteViewModel.hoverHighlightArmed` and `menuOpen` are deliberately **not** `@Published` today —
  they are read at event time and must never drive a re-render. Under `@Observable` they must be
  `@ObservationIgnored`, or every mouse move re-renders the palette.
- `menuOpen`'s `didSet` fires `onMenuOpenChanged` — keep it.
- `PalettePanel.paletteViewModel` is `weak` and its `didSet` installs the caret hook. Keep both.
- `AppCore.pendingQuicklinkEdit` is the only `@Published` on `AppCore`; the Settings pane binds
  `$core.pendingQuicklinkEdit` to a `.sheet(item:)`. Convert to `@Bindable`.
- Do not touch the `Task { … }` calls in `start()` that kick off `clipboardStore.load()`,
  `appIndex.refresh()` and `emojiIndex.load()` — those are one-shot launches, not sinks.

## Detailed acceptance criteria

1. `PaletteViewModel` and `AppCore` are `@Observable`.
2. `hoverHighlightArmed` and `menuOpen` are `@ObservationIgnored`.
3. `grep -rn "import Combine" Tinycast` returns only files that genuinely still need it.
4. `grep -rn "cancellables" Tinycast` returns nothing.
5. `grep -rcn "assumeIsolated" Tinycast` drops by exactly 8 (the sink sites) and no more.
6. All six feature switches still reconcile the launcher — verified by toggling each **twice**, to catch
   a tracking registration that fires only once.
7. Search scopes still re-index on change, **twice in a row**.
8. Hyper Key still reconfigures on change, **twice in a row**.
9. Mouse movement over palette rows does not re-render the palette body.
10. The quicklink editor sheet still opens from "Create Quicklink" in the palette.

## Manual verification checklist

- [ ] `checklists/build.md` including **startup timing**
- [ ] `checklists/testing.md` — **all 17 harnesses**
- [ ] `checklists/regression.md` — **the full document**, every section
- [ ] **Toggle each feature switch twice**: custom commands, snippets, window management, quicklinks —
      and each "show in launcher" companion. The launcher must react **both** times
- [ ] Add a search scope, then add another → both re-index
- [ ] Change the Hyper Key twice → the tap reconfigures both times
- [ ] Sweep the mouse across the launcher rows with `_printChanges` active → **no body re-evaluations**
- [ ] Open a footer menu → typing is frozen, caret hidden; close it → typing resumes
- [ ] "Create Quicklink" from the palette → Settings opens on the Quicklinks pane with the editor showing
- [ ] Cold-launch timing within 10 % of baseline

## Regression risks

| Risk                                                                                             | Mitigation                                                             |
| ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| **`withObservationTracking` fires once and stops.** The signature bug of this migration.         | AC6/7/8 — _toggle everything twice_                                    |
| A non-Combine `assumeIsolated` is deleted, breaking a tap or timer bridge                        | AC5 counts the delta exactly; the must-not-change list names the files |
| `hoverHighlightArmed` becomes tracked → the palette re-renders on every mouse move               | AC2/AC9                                                                |
| `menuOpen` becomes tracked → menu open/close causes a full re-render and the caret hook misfires | AC2 + the menu check                                                   |
| Feature reconciliation ordering changes and a switch leaves the launcher inconsistent            | Toggle-twice checks on all six                                         |

## Rollback strategy

`git revert <sha>`. In-memory only.

This phase is the M2 keystone — if it is reverted, phases 19+ must not proceed, since M3 assumes the
palette is `@Observable`. Record that in `ROADMAP.md` if it happens.

## Expected commit size

~10 files, +100 / −140 lines.

## Suggested commit message

```
Migrate the palette and AppCore to @Observable, retire the Combine sinks

Eight settings.$x sinks become withObservationTracking, which removes
their deferral Tasks (only needed because @Published emits before the
write) and the eight MainActor.assumeIsolated blocks that bridged them —
each a runtime trap if the assumption were ever wrong. The assumeIsolated
blocks bridging Carbon, CGEvent, DispatchSource and NotificationCenter
callbacks are untouched. hoverHighlightArmed and menuOpen stay untracked.
```

## Dependencies

**Phases 16 and 17 (hard).** Blocks all of M3.

## Definition of Done

- All acceptance criteria met
- Every feature switch toggled **twice** and verified
- `assumeIsolated` count delta confirmed to be exactly 8
- Full regression document walked
- Merged

## Estimated difficulty

**High.** The re-arming subtlety plus a large blast radius.

## Estimated Claude context usage

**High.**

## Notes for reviewers

- **Toggle everything twice.** `withObservationTracking`'s `onChange` is a one-shot; a naive conversion
  works perfectly the first time and then silently stops. Nothing else in this checklist catches it.
- Count `assumeIsolated` before and after: `grep -rc "assumeIsolated" Tinycast --include=*.swift`. The
  delta must be exactly 8. If it is more, a tap or timer bridge was deleted and something will fail
  later, subtly.
- Confirm `hoverHighlightArmed` and `menuOpen` carry `@ObservationIgnored`. Their non-`@Published`-ness
  today is a deliberate performance decision documented in `AppCore.swift`.
- This is the phase whose result justifies M2. Ask for the `_printChanges` evidence.
