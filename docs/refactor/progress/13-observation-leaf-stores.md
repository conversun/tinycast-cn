# Phase 13 — Observation wave A: leaf stores

---

## Status

| Field                         | Value                                     |
| ----------------------------- | ----------------------------------------- |
| **Status**                    | Complete                                  |
| **Started**                   | 2026-08-05                                |
| **Completed**                 | 2026-08-05                                |
| **Operator**                  | abue-ammar                                |
| **Branch**                    | `refactor/13-observation-leaf-stores`     |
| **Commit**                    | single commit on the branch               |
| **Claude conversations used** | 1                                         |
| **Actual effort**             | ~35 min vs. estimate of M (3–4 h)         |

---

## Completed tasks

- [x] Objective 1 — `VisibilityStore`, `CalculatorHistoryStore` and `FrequentEmojiStore` are
      `@Observable`; every `ObservableObject` conformance and every `@Published` is gone
- [x] Objective 2 — every persistence path and every memo invalidation preserved exactly
- [ ] Objective 3 — "verify each store's list updates immediately on mutation" — **not run.** The
      operator waived interactive verification for this phase; see the Verification table

## Acceptance criteria

- [x] AC1 — all three types are `@Observable` — verified by: the diff; each type changes in three
      lines (attribute, conformance, `@Published`)
- [x] AC2 — every injection site converted, palette **and** Settings — verified by: four sites (below),
      plus `grep` over `Tinycast/` for `environmentObject((self.|core.)?(visibility|calcHistory|frequentEmoji))`
      and for `@EnvironmentObject`/`@ObservedObject` of the three type names → no matches. The three
      stores are instantiated only at `AppCore.swift:122/123/126`, so no injection path exists that
      those four sites do not cover
- [ ] AC3 — hiding an item in Settings ▸ Applications hides it in the launcher immediately — **not
      verified.** Mechanism in place: `visibility.revision` stays tracked and is read by
      `AppIndex.orderedResults`
- [ ] AC4 — hiding a category removes its section immediately — **not verified**, same mechanism
- [ ] AC5 — ⌘⌫ on a calculator history row removes it immediately — **not verified**
- [ ] AC6 — using an emoji updates Frequently Used on next open — **not verified**
- [ ] AC7 — all three persist across a relaunch — **not verified interactively.** No persistence call
      site was touched: `defaults.set`, `persist()` and both `data.write(to:)` calls are outside the
      diff
- [x] AC8 — `revision` still increments and the launcher memo still invalidates — verified by: every
      `revision` declaration and mutation site is outside the diff, in all three stores; phase 09's
      `Memo` adoption is intact in both memoized stores

### Injection sites converted

| Window   | Site                                     | Values                                            |
| -------- | ---------------------------------------- | ------------------------------------------------- |
| Palette  | `PaletteWindowController.ensurePanel()`  | `core.visibility`, `core.calcHistory`, `core.frequentEmoji` |
| Settings | `AppCore.showSettings()`                 | `self.visibility`                                 |

Four in total. The other five injections in `showSettings` (`self`, `appIndex`, `customCommands`,
`snippetsStore`, `quicklinks`) are not this phase's types and stay `.environmentObject`.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                                                                                                                                    |
| -------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | `xcodegen generate` clean, no `.xcodeproj` churn. Debug `BUILD SUCCEEDED`. **A pre-phase baseline was captured on this branch** — zero compiler warnings before, zero after, so "zero new warnings" is measured here rather than asserted. Release build and binary size not measured                     |
| `checklists/testing.md`    | PASS    | Both harnesses the phase names as gates: `calc-test` (486 passed, 0 failed) and `emoji-test` (all checks passed, 2054 records). Neither compiles any changed file — they gate `Core/Calculator/*` and `Core/Emoji/{EmojiCatalog,EmojiGridGeometry,EmojiData.generated}`, all on the must-NOT-change list |
| `checklists/regression.md` | NOT RUN | **Waived by the operator.** No interactive pass was made: the Settings window was not opened, and AC3–AC7 were not exercised. A missed injection site compiles cleanly, so the static backstop under AC2 is the only evidence covering it                                                                 |
| `checklists/review.md`     | PASS    | Self-check. §1 scope: 8 files, all from the phase's expected list, **none from the must-NOT-change list**; +22/−19 against an expected +40/−45. §2 no condition, comparison, default, method signature or `UserDefaults` key changed; no user-visible string. §3 isolation unchanged — all three stay `@MainActor`, no `@unchecked`, no `nonisolated(unsafe)`. §4 nothing newly retained; `@Observable` swaps a `Published` subject for a registrar. §5 comments +0, stacked blocks +0. §6 nothing orphaned. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                   | Before | After | Δ                                                                     |
| ------------------------ | ------ | ----- | --------------------------------------------------------------------- |
| Binary size (Release)    | —      | —     | not measured                                                          |
| Clean install verified?  | —      | n-a   | no storage change; `hiddenLauncherItems`, `hiddenLauncherKinds`, `calculator-history.json` and `emoji-frequency.json` are untouched in key, location and format |
| Cold launch, median of 3 | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`     |
| Compiler warnings        | 0      | 0     | measured, not asserted — see `build.md` above                         |

The M2 re-render win still accrues across phases 12–18 and is not measurable from three leaf stores.

---

## Failed tasks

none

---

## Issues encountered

- **`revision` had to stay tracked in both memoized stores, and that is not obvious.** On a memo hit
  `CalculatorHistoryStore.search(_:)` and `FrequentEmojiStore.top(_:)` read *only* `revision` —
  `entries` / `records` are read inside the build closure, which a hit never runs. Marking `revision`
  `@ObservationIgnored` alongside the memo would compile and silently stall the filtered history list
  and the Frequently Used grid. The rule that falls out: `@ObservationIgnored` the memo storage, never
  the key it is memoized on.
- **Both memos genuinely needed `@ObservationIgnored`**, as phase 11's recipe predicted. `search()` is
  reached from `RootPaletteView.histResults` and `top()` from `EmojiGrid.sections`, both computed
  properties read during body evaluation, so a tracked `Memo` would write through `withMutation` mid
  render — the "Modifying state during view update" failure.
- **Phase 12 landed mid-flight and this branch was rebased onto it.** This branch was cut from `main`
  at `9369d79`; phase 12 merged as `3a76e69` (#168) while the work was in progress, so the PR
  conflicted and was rebased. Both conflicts were adjacent-line only — `RootPaletteView`'s
  `frequentEmoji` (13) next to `uninstall` (12), and the two ROADMAP rows — and each side was kept.
  `PaletteWindowController` auto-merged.

---

## Deviations from the phase document

- **Two of the ten expected files were not touched.** `Features/Calculator/CalculatorHistoryView.swift`
  and `Features/Emoji/EmojiGridView.swift` take their store as a plain parameter, not from the
  environment. The phase's file table listed both conditionally ("if it consumes the store"), so this
  is the anticipated branch, not a shortfall.
- **Diff is +22/−19 against an expected +40/−45.** No import changed — Foundation already re-exports
  Observation, and none of the three files imported Combine.
- **`checklists/regression.md` was not run**, on the operator's instruction. Recorded above rather than
  silently marked PASS.

---

## Follow-up work

| Observation                                                                                                                                                                    | Where                          | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------ | --------------- |
| AC3–AC7 were never exercised interactively. A missed injection site is invisible to the compiler, and the Settings window is where one would surface                            | —                              | before merge    |
| `RootPaletteView` reads `AppCore.shared.settings` through `@ObservedObject`, a direct singleton read rather than an injection                                                    | `Features/RootPaletteView.swift:20` | 16              |
| Phase 12 merged as #168 with its ROADMAP row filled in but **no progress file** under `docs/refactor/progress/`                                                                  | `docs/refactor/progress/`      | —               |
| `Memo` storage still needs `@ObservationIgnored` when `AppIndex` migrates, as phase 11 flagged                                                                                  | `Core/AppIndex.swift`          | 17              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory observation mechanism only — no persistence, no
  migration, no format change, and all three stores read from disk on `init` exactly as before.
- **Dependent phases that must also be reverted:** none. Phases 14–18 list 11, not 13, as their
  dependency; nothing builds on this diff.
- **Data risk on revert:** none.

---

## Sign-off

- [x] AC1, AC2 and AC8 met; AC3–AC7 not verified (interactive verification waived)
- [ ] All four checklists passed — three passed, `regression.md` not run
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
