# Phase 14 — Observation wave A: monitors and indices

---

## Status

| Field                         | Value                                              |
| ----------------------------- | -------------------------------------------------- |
| **Status**                    | Complete                                           |
| **Started**                   | 2026-08-05                                         |
| **Completed**                 | 2026-08-05                                         |
| **Operator**                  | abue-ammar                                         |
| **Branch**                    | `refactor/14-observation-monitors-and-indices`     |
| **Commit**                    | single commit on the branch                        |
| **Claude conversations used** | 1                                                  |
| **Actual effort**             | ~25 min vs. estimate of M (2–4 h)                  |

---

## Completed tasks

- [x] Objective 1 — `RunningAppsMonitor`, `EmojiIndex` and `CurrencyRateStore` are `@Observable`; every
      `ObservableObject` conformance and every `@Published` is gone
- [x] Objective 2 — `CurrencyRateStore`'s four consent guards preserved exactly; none is inside the diff
- [x] Objective 3 — `RunningAppsMonitor`'s `guard next != runningBundleIDs` preserved; outside the diff

## Acceptance criteria

- [x] AC1 — all three types are `@Observable` — verified by: the diff; each type changes in three lines
      (attribute, conformance, `@Published`) plus one `@ObservationIgnored`
- [x] AC2 — the four consent guards present and unchanged — verified by: quoted below with line
      context, and by `git diff` showing no change inside `init`, `source`, `start()` or
      `fetchAndStore()`
- [x] AC3 — the equality guard is present — verified by: `RunningApps.swift:33`, outside the diff hunk
- [x] AC4 — `RootPaletteView` still does not observe `RunningAppsMonitor` — verified by: its
      `@EnvironmentObject` count went 7 → 5, **down by exactly two**, as the phase's reviewer note
      requires. Its only two `runningApps` reads are at `:505` (an `onKeyPress` closure) and `:855`
      (`openActions()`), both off the `body` evaluation path, so neither registers a dependency
- [ ] AC5 — launch/quit updates the running dot without re-rendering the palette — **not verified.**
      Interactive; the operator waived it. The `_printChanges` half was not run either
- [ ] AC6 — the emoji grid shows "Loading emoji…" then populates — **not verified.** `load()` is
      untouched: still `async`, still `Task.detached`
- [ ] AC7 — currency off produces no card and **no network request** — **not verified by observation.**
      Static state confirmed instead: the dev channel's `currencyRatesEnabled` reads `0` and no
      `~/Library/Caches/com.tinycast.app.dev/currency-rates.json` exists. **This is the privacy-critical
      check and it remains unmade** — see Follow-up work
- [ ] AC8 — turning it on shows consent, rates land, the card evaluates — **not verified**

### The four consent guards

```
 45   // Guard 1 — a disabled feature doesn't even read back a snapshot left on disk.
 46   guard isEnabled, let data = try? Data(contentsOf: fileURL) else { return }   ← init()

 50   /// What the calculator is allowed to use. Guard 2 — the read path: without consent the engine is
 52   var source: CurrencySource { isEnabled ? .on(rates) : .off }

 56   /// sooner. Guard 3 — no consent, no loop, so `AppCore.start()` can call this unconditionally.
 58       guard isEnabled else { return }                                          ← start()

102   // Guard 4 — re-checked at the network boundary itself: the pump may have been sleeping when
104   guard isEnabled, let fetched = try? await Self.fetch() else { return false }  ← before the request
107   guard isEnabled else { return false }                                         ← after the await
```

Also unchanged: the consent flag stays on this store (`consentKey = "currencyRatesEnabled"`, not in
`AppSettings`), the session stays `.ephemeral` with `urlCache = nil` (`:119–120`), and
`setEnabled(false)` still deletes the cached file (`:90`).

### Injection sites converted

| Window  | Site                                    | Values                                              |
| ------- | --------------------------------------- | --------------------------------------------------- |
| Palette | `PaletteWindowController.ensurePanel()` | `core.currencyRates`, `core.emojiIndex`, `core.runningApps` |

Three in total. The two Settings consumers reach their store through `AppCore.shared`, not the
environment, so they convert from `@ObservedObject` to a plain `let` and need no injection.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                                                                                                                          |
| -------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `checklists/build.md`      | PASS    | `xcodegen generate` clean, no `.xcodeproj` churn. Debug `BUILD SUCCEEDED`. **A pre-phase baseline was captured on this branch** — zero compiler warnings before, zero after, so "zero new warnings" is measured, not asserted; re-confirmed by `touch`ing all eight changed files and forcing a full recompile. Release build and binary size not measured |
| `checklists/testing.md`    | PASS    | Both harnesses the phase names as gates: `calc-test` (486 passed, 0 failed) and `emoji-test` (all checks passed, 2054 records). Neither compiles a changed file — they gate `Core/Calculator/*` and `Core/Emoji/{EmojiCatalog,EmojiGridGeometry,EmojiData.generated}`, all on the must-NOT-change list |
| `checklists/regression.md` | NOT RUN | **Waived by the operator.** No interactive pass was made: the palette was not opened, no app was launched or quit against it, the emoji grid was not loaded, and no currency query was typed. AC5–AC8 are unexercised, including the network-off observation |
| `checklists/review.md`     | PASS    | Self-check. §1 scope: 8 files, seven from the phase's expected list plus `BackupSettingsView` (see Deviations), **none from the must-NOT-change list**; +22/−19 against an expected +35/−45. §2 no condition, comparison, default, method signature or `UserDefaults` key changed; no user-visible string; no consent guard touched. §3 isolation unchanged — all three stay `@MainActor`, no `@unchecked`, no `nonisolated(unsafe)`; `fetch()` and `session` stay `nonisolated`. §4 nothing newly retained; `@Observable` swaps a `Published` subject for a registrar. §5 comments +0, stacked blocks +0. §6 nothing orphaned; no import changed. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                   | Before | After | Δ                                                                                                     |
| ------------------------ | ------ | ----- | ----------------------------------------------------------------------------------------------------- |
| Binary size (Release)    | —      | —     | not measured                                                                                          |
| Clean install verified?  | —      | n-a   | no storage change; `currencyRatesEnabled` and `currency-rates.json` are untouched in key, location and format |
| Cold launch, median of 3 | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`, and `EmojiIndex.load()` stays lazy and detached |
| Compiler warnings        | 0      | 0     | measured, not asserted — see `build.md` above                                                         |

The M2 re-render win still accrues across phases 15–18 and is not measurable from three types.

---

## Failed tasks

none

---

## Issues encountered

- **`RootPaletteView` reads `runningApps` twice and neither read needed changing**, which is the
  interesting result of this phase. Both go through `core.runningApps`, not the environment, and both
  sit in a deferred closure — an `onKeyPress` handler and `openActions()`. Under `@EnvironmentObject`
  the isolation came from the wrapper being absent; under `@Observable` it comes from the read being
  off the `body` path. The invariant survives for a different reason than before, so a future phase
  that hoists either read into a computed property would silently break AC4.
- **`EmojiIndex.searchMemo` needed `@ObservationIgnored`, `revision` did not** — phase 13's rule applied
  unchanged: ignore the memo storage, never the key it is memoized on. `search()` is reached from
  `RootPaletteView.emojiSections` during body evaluation, so a tracked `Memo` would write through
  `withMutation` mid render.
- **`RunningAppsMonitor.observers` and `CurrencyRateStore.pump` took `@ObservationIgnored`** on the
  precedent already in the tree (`ShortcutCaptureSession.monitors`, `UninstallSession.scanTask`), not
  on new judgement.

---

## Deviations from the phase document

- **`Features/Settings/BackupSettingsView.swift` is an eighth file the phase did not list.** It held
  `@ObservedObject private var runningApps = AppCore.shared.runningApps`, which stops compiling the
  moment the type drops `ObservableObject`. It is not on the must-NOT-change list and the fix is the
  same one-line change as `MiscellaneousSettingsView`.
- **`Features/Emoji/EmojiGridView.swift` was not touched.** It takes `index: EmojiIndex` as a plain
  parameter. The phase listed it conditionally ("if it consumes `emojiIndex`"), so this is the
  anticipated branch, not a shortfall.
- **No import changed.** The phase anticipated possibly dropping `import Combine` from
  `CurrencyRateStore`; that file imports Foundation only and never imported Combine, and neither do the
  other two.
- **Diff is +22/−19 against an expected +35/−45**, the same pattern as phases 11–13.
- **`checklists/regression.md` was not run**, on the operator's instruction, and the phase was recorded
  `Complete` without it. Recorded here rather than silently marked PASS.

---

## Follow-up work

| Observation                                                                                                                                                                                          | Where                                | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ | --------------- |
| **AC7 — the currency-off network observation — was never made.** The phase document calls a dropped consent guard "the most serious kind" of regression here. The guards are provably unchanged in the diff, but the behavioural confirmation is outstanding | `Core/CurrencyRateStore.swift`       | before merge    |
| AC5, AC6 and AC8 were not exercised, and the `_printChanges` palette check was not run                                                                                                              | —                                    | before merge    |
| AC4 now rests on both `runningApps` reads staying off the `body` path, a weaker guarantee than the missing wrapper used to give                                                                       | `Features/RootPaletteView.swift:505,855` | 19–23           |
| `RootPaletteView` still reads `AppCore.shared.settings` through `@ObservedObject`, a direct singleton read rather than an injection                                                                   | `Features/RootPaletteView.swift:20`  | 16              |
| `Memo` storage still needs `@ObservationIgnored` when `AppIndex` migrates, as phases 11 and 13 flagged                                                                                                | `Core/AppIndex.swift`                | 17              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory observation mechanism only — no persistence, no
  migration, no format change. The consent flag and the cached rates file are read the same way either
  side of the revert.
- **Dependent phases that must also be reverted:** none. Phases 15–18 list 11, not 14, as their
  dependency; nothing builds on this diff.
- **Data risk on revert:** none.

---

## Sign-off

- [x] AC1–AC4 met; AC5–AC8 not verified (interactive verification waived)
- [ ] All four checklists passed — three passed, `regression.md` not run
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Does not block phase 15.** Phase 15 depends on 06 and 11, both `Complete`; it shares no file
      with this diff
