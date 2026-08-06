# Phase 23 — Screen: `launcher`, and collapsing the calc offset

---

## Status

| Field                         | Value                                            |
| ----------------------------- | ------------------------------------------------ |
| **Status**                    | Complete                                         |
| **Started**                   | 2026-08-05                                       |
| **Completed**                 | 2026-08-05                                       |
| **Operator**                  | abue-ammar                                       |
| **Branch**                    | `refactor/23-screen-launcher-and-offset-collapse` |
| **Commit**                    | single commit on the branch                      |
| **Claude conversations used** | 1                                                |
| **Actual effort**             | ~45 min vs. estimate of L (4–8 h)                |

---

## Completed tasks

- [x] Objective 1 — `LauncherScreen` conforms to `PaletteScreen`
- [x] Objective 2 — the last arm is gone from every mode switch; only the screen factory remains
- [x] Objective 3 — every `calcCount` / offset computation collapsed into `rows[0]`
- [x] Objective 4 — the `openActions()` workaround removed (phase 09 is merged)

## Acceptance criteria

- [x] AC1 — conforms; no `switch vm.mode` over screens — verified by: `switch vm.mode` count 3 → 1,
      and the survivor is the factory that *builds* the screens, which phases 20–22 grew on purpose.
      Every behaviour and rendering mode switch is gone. See *AC1's wording* below
- [ ] AC2 — `RootPaletteView` under ~400 lines — **NOT MET at 665.** See *Why AC2 is unreachable* below
- [x] AC3 — `grep -rn "calcCount" Tinycast` returns nothing — verified by: empty output
- [~] AC4 — section order identical — **structural**; `LauncherView.swift` is absent from the diff, so
      the nine-section table and its explicit type annotation are byte-identical. No pre-phase
      screenshot was taken and no visual comparison was made
- [~] AC5 — favourites pin to the top, in order, excluded from later sections — **structural**; the
      `favoriteCount` prefix and the `rest` filter moved verbatim into the screen
- [~] AC6 — a typed query collapses to one Results section — **structural**; `showSections` is still
      "trimmed query is empty", now read inside the screen
- [~] AC7 — a calculation puts the Calculator section and card first — **structural**;
      `rows = [.calc] + entries` and `LauncherList`'s `calcRows` prefix are both unchanged in effect
- [~] AC8 — ⌘1–⌘5 launch the right favourites; "…" expands — **structural**; `compactFavoriteSlots`
      moved verbatim, the handler only changed how it reaches it
- [~] AC9 — ⌃⇧Q quits only a running application — **structural**; `quit(at:)` carries the same three
      conditions (`.entry`, `kind == .application`, `runningApps.isRunning`)
- [~] AC10 — ⌘↵ reveals only revealable kinds — **structural**; `secondary(at:)` gates on
      `app.canRevealInFinder` and returns false otherwise, leaving the key `.ignored` as before
- [x] AC11 — `palette-selection-test` covers nine sections + favourites + calc card — verified by:
      111,684 assertions (111,108 before), exit 0
- [x] AC12 — the `openActions` workaround is removed — verified by: phase 09 is `Complete`, so the
      `vm.mode == .launcher` guard and its unmemoized-`appResults` comment are both gone

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                  |
| -------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + **Debug and Release** builds, both exit 0. **0 compiler warnings against a 0 baseline** measured by a clean Debug build on this branch before any edit. Release took 37 s — the section table's annotation still holds |
| `checklists/testing.md`    | PASS   | **All 17 harnesses** via `bash -e`, exit 0, no `FAIL` lines. `palette-selection-test` 111,684 assertions. The phase doc says 18; `Tools/` holds 17 and the Tests fence lists 17 — the same miscount phases 19 and 20 recorded                |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC4–AC10 are therefore unexercised**, including the phase's own headline gate: the four slow ↑/↓ walks and the section-order screenshot comparison                                              |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                                                                                                                                                        |

### AC1's wording

"No `switch vm.mode` over screens" cannot mean literally zero — the factory *is* a switch on the mode,
and phases 20–22 each added an arm to it deliberately. One `switch vm.mode` survives:

```swift
private var screen: any PaletteScreen {
    switch vm.mode {
    case .launcher: return LauncherScreen(...)
    ...
    }
}
```

It is now **non-optional and exhaustive over all seven modes**, which is what removes the `default:`
arm and the `if let screen` fork at every call site. Every other `vm.mode` reference left in the file
is one the phase explicitly keeps palette-level: the header chevron and glyph, the search prompt,
`pillTint`, the Tab toggle, the argument-form pill exception, and the mode-change session cleanup.

### The calc card as `rows[0]`

```swift
var rows: [Row] {
    let entries = results.map(Row.entry)
    guard let calc else { return entries }
    return [.calc(calc)] + entries
}
```

Phase 22's pattern, applied to the last and largest screen. `calcCount` greps empty tree-wide, and the
eight hand-maintained offset computations are gone: `secondary`, `quit` and `isRunning` are card-safe
for free because `entry(at:)` returns nil on a `.calc` row, and `hasPrimaryAction` replaces
`calcSelected && !calcActionable` — which resolves one of phase 22's three follow-ups.

### Why AC2 is unreachable inside this phase

The doc's ~350-line target was written against a **1126-line** file. It is 832 today because phases
19–22 already removed the first 294 lines. What remains after this phase:

| Part                                                                                        | Lines |
| ------------------------------------------------------------------------------------------- | ----- |
| `RootPaletteView` itself — header, search field, footer, both menu overlays, ⌘K/Esc/Tab/⌘⌫/⌘P, frame sync, mode cleanup | 534   |
| `MenuCircleButton`, `BarButton`, `armedHover`, `EmptyResults`, `CompactFavoriteSlot`, `CompactFavoritesRow`, `CompactFavoriteButton` | 128   |

Every line of the first row is something the phase's own boundaries say **stays**. The second row is
five palette-chrome helpers the phase never mentions. Hitting ~400 would have required extractions no
phase authorises, so none were attempted — see *Follow-up work*, which raises this as a gap in
phase 29 rather than parking it.

### `selectionIsRunning` stays on the view

`@State private var selectionIsRunning` did **not** move into the screen, deliberately. It is the
sample `openActions` takes so an app launching elsewhere cannot add or drop the Quit row while the
menu is up, and its comment records that `RunningAppsMonitor` is *not* observed by the palette on
purpose. A screen is a fresh struct value per render with no storage, so the sample must live on the
view; had `actions(at:)` read `runningApps` directly it would have registered an observation
dependency in `RootPaletteView.body` and re-rendered the whole palette on every workspace
launch/terminate — a behavioural regression the boundary forbids.

### Measurements

| Metric                          | Before  | After   | Δ                                                     |
| ------------------------------- | ------- | ------- | ------------------------------------------------------- |
| `RootPaletteView.swift`         | 832     | 665     | **−167**                                                |
| `switch vm.mode` statements     | 3       | 1       | **−2** — only the screen factory remains                |
| `calcCount` occurrences         | 8       | 0       | **−8**                                                  |
| `PaletteScreen` adopters        | 6       | 7       | +1 — every mode is now a screen                         |
| Compiler warnings (Debug)       | 0       | 0       | 0                                                       |
| Harness count                   | 17      | 17      | 0                                                       |
| `palette-selection-test`        | 111,108 | 111,684 | +576 assertions                                         |
| Diff size                       | —       | —       | 4 files, +292 / −199 (expected 4 files, +450 / −800)    |
| Binary size (Release)           | —       | —       | not measured                                            |
| Clean install verified?         | —       | n-a     | nothing persists here                                   |

**The diff is not net negative, and that is not a sign the switches were replaced.** `calcCount`,
`appResults`, `modeContent`, `actionPillLabel`, `calcActionableResult` and `selectedAppEntry` all grep
empty. The expectation assumed a 1126-line starting file; `RootPaletteView` sheds 167 lines while the
screen that replaces its arms costs 177, and the harness adds 79.

---

## Failed tasks

None.

---

## Issues encountered

- **`primaryActionTitle` takes no selection, but the launcher's pill label depends on one.** Adding a
  parameter would have edited all six already-migrated screens, which the phase lists as
  must-not-change. `LauncherScreen` therefore re-derives the identical clamp
  (`min(max(vm.selection, 0), rows.count - 1)`) over the identical `rows`. It is duplication, accepted
  knowingly rather than hidden — the alternative was a protocol change touching six forbidden files.
- **Two chords had to route by `as?` downcast, like ⌘P and ⌘⌫ before them.** ⌃⇧Q and ⌘1–⌘5 are
  launcher-only and have no protocol member, so `screen as? LauncherScreen` replaces
  `vm.mode == .launcher`. This is safe rather than merely equivalent: `AppCore.paletteIsCollapsed`
  already requires launcher mode, so the compact-favourites and ⌘1–⌘5 downcasts can never be nil
  where the old mode check passed.
- **The footer pill's kind→title mapping disagrees with the Actions menu's, and always has.** Copied
  verbatim; see *Follow-up work*.

---

## Deviations from the phase document

- **`LauncherView.swift` is absent from the diff.** The phase lists it as expected-to-modify
  ("`LauncherList`, `AppRow`, `AppActionsMenu` move or are consumed by the screen") and the second
  option turned out to need no edit at all: `LauncherScreen` feeds the existing `LauncherList`
  verbatim, deriving `favoriteCount` and `showSections` on its side of the call. Nothing moved, so the
  nine-section table, its type annotation, the running dots and `AppRow` are untouched by construction
  rather than by care — which is the strongest form AC4 can take short of a screenshot.
- **The compact-favourites *views* stayed in `RootPaletteView.swift`.** The boundary moves the
  derivation and keeps the rendering palette-level; it says nothing about file placement, so only
  `compactFavoriteSlots` moved. `CompactFavoriteSlot`, `CompactFavoritesRow` and
  `CompactFavoriteButton` are where they were.
- **AC2 not met**, for the reasons tabulated above. No extraction was attempted to reach it.

---

## Follow-up work

| Observation                                                                                                                                                                                              | Where                                                              | Suggested phase   |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ----------------- |
| **User-visible.** The footer pill calls `.snippet` and `.windowCommand` "Open Application"; the Actions menu on the same row says "Paste Snippet" / "Move Window". Pre-existing on `main`, copied verbatim | `LauncherScreen.pillTitle` vs `AppActionsMenu.openTitle`           | **31** (or a small standalone fix on `main`) |
| **Phase 31 cannot satisfy its own AC4 as written.** Its `KindDescriptor` has one `openVerb`, but the two mappings above disagree for two kinds, so "every string character-identical" is unachievable until someone picks a wording | `phases/31-app-entry-kind-exhaustiveness.md`                       | decide before 31 starts |
| **Phase 29 has no home for five palette-chrome helpers.** Its Launcher row omits the compact-favourite types, and its "permitted verbatim splits" table excludes `RootPaletteView.swift` — so the file ends M5 with 8 top-level declarations, against the one-view-per-file rule phase 29 itself declares. This is why AC2 is unreachable, and nothing later reduces it | `Features/RootPaletteView.swift`                                   | **29** — needs a fourth permitted split |
| `rows` is rebuilt ~7× per render in launcher mode (count, `hasPrimaryAction`, `primaryActionTitle` ×2, then three times inside `content`). Each rebuild is a `map` over the memoized results, so the search never re-runs, but the array allocation does. Threading `rows` through `body(selection:scroll:)` would touch every screen. **Carried forward from phase 22, unresolved** | `PaletteScreen` + all seven screens                                | 26                |
| `as?` downcast routing for ⌘P, ⌘⌫, ⌥↵, ⌃⇧Q and ⌘1–⌘5 is now the settled pattern, not a temporary one; it grew by one type here. **Carried forward from phase 22, unresolved** — phase 21 established the gate allows one member, so this may simply be the answer | `Features/RootPaletteView.swift`                                   | 25 or none        |
| `pillTint`'s `vm.mode == .uninstall` is the last per-mode styling in the footer. Considered and **declined**: expressing it as a protocol member would touch all seven screens to delete one correct ternary | `Features/RootPaletteView.swift`                                   | none — deliberate |
| Interactive regression waived — AC4–AC10 unexercised, including the four ↑/↓ walks this phase's risk register calls the real gate                                                                          | Launcher sweep                                                     | before merge      |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. `LauncherScreen.swift` disappears, `RootPaletteView` regains
  `appResults`, `calcResult`/`calcCount`, `selectedAppEntry`, `modeContent` and `actionPillLabel`, and
  `screen` returns to its optional phase-22 shape. Re-run `xcodegen generate` afterwards. Nothing
  persists and no stored format is involved.
- **Dependent phases that must also be reverted:** none yet. Phase 24 depends on this one, so a revert
  must happen *before* 24 lands.
- **Data risk on revert:** none.

---

## Sign-off

- [~] All acceptance criteria met — AC1, AC3, AC11, AC12 verified; **AC2 not met** at 665 lines;
      AC4–AC10 structural only because interactive verification was waived
- [~] All four checklists passed — `build.md` PASS (Debug **and** Release), `testing.md` PASS (all 17
      harnesses); `regression.md` and `review.md` waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — pushed to `origin`, merge pending
- [x] **Stopped.** Next phase is a separate session.
