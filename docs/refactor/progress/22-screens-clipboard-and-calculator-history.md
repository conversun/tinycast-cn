# Phase 22 — Screens: `clipboard` and `calculatorHistory`

---

## Status

| Field                         | Value                                                    |
| ----------------------------- | -------------------------------------------------------- |
| **Status**                    | Complete                                                 |
| **Started**                   | 2026-08-05                                               |
| **Completed**                 | 2026-08-05                                               |
| **Operator**                  | abue-ammar                                               |
| **Branch**                    | `refactor/22-screens-clipboard-and-calculator-history`   |
| **Commit**                    | single commit on the branch                              |
| **Claude conversations used** | 1                                                        |
| **Actual effort**             | ~30 min vs. estimate of M (2–4 h)                        |

---

## Completed tasks

- [x] Objective 1 — `ClipboardScreen` and `CalculatorHistoryScreen` conform to `PaletteScreen`
- [x] Objective 2 — the calculator card is a prepended row in `rows`, not an offset variable
- [x] Objective 3 — the follow-the-moved-row behaviour moved intact, still keyed on the store

## Acceptance criteria

- [x] AC1 — both conform, both arms gone — verified by: six adopters of `PaletteScreen`; `.clipboard`
      and `.calculatorHistory` survive only in the `screen` factory switch
- [x] AC2 — no `calcCount`/offset in the history screen — verified by:
      `grep -rn "calcCount" Tinycast/Features/Clipboard Tinycast/Features/Calculator` is empty; every
      lookup goes through `row(at:)` over `[.calc(result)] + entries.map(Row.entry)`
- [x] AC3 — `palette-selection-test` covers a leading calc row — verified by: 111,108 assertions
      (111,066 before), exit 0, plus a deliberate-break proof
- [~] AC4 — a capture moves the selection only with an empty query — **structural**; the handler moved
      verbatim, guards and all. Not exercised interactively
- [~] AC5 — typing does not move the selection — **structural**; the change key still reads
      `store.items.first?.id`, so a query filtering `rows` cannot change it. See *The follow key* below
- [~] AC6 — pinning moves the row and the selection follows — **structural**;
      `core.togglePinnedClip` and the store's pinned-first order are outside the diff, and
      `vm.followToken` is still the second half of the key
- [~] AC7 — the card is row 0 and ↵ copies + records — **structural**; `activate(at:)` resolves
      `.calc` → `core.copyCalculatorResult`, unchanged
- [x] AC8 — ⌘⌫ never deletes the card — verified by: `delete(at:)` goes through `entry(at:)`, which
      returns nil for a `.calc` row; the harness also asserts index 0 is the only `.calculator`
- [x] AC9 — an error card shows no primary action and ⌘K opens nothing — verified by:
      `hasPrimaryAction(at:)` returns `result.isActionable`, gating both `showActionGroup` and the ⌘K
      early return; `actions(at:)` returns nil for it
- [~] AC10 — empty history centres one message across the panel — **structural**; the branch moved
      unchanged and still tests the *filtered* rows, so a no-match query renders it too, as before

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                    |
| -------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + Debug build, exit 0. **0 compiler warnings against a 0 baseline** measured by a clean build on this branch before any edit; the one `warning:` line is `appintentsmetadataprocessor` |
| `checklists/testing.md`    | PARTIAL | The three harnesses the phase names as gates — `palette-selection-test` (111,108 assertions), `clipboard-test` (23/23), `calc-test` (486/486) — all exit 0. The full 17-harness sweep was **not** run; no `Core/` file is in the diff |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC4–AC7 and AC10 are therefore unexercised**, including the phase's headline check: type a query, then copy in another app, and confirm the selection does not jump |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                                                                                                                          |

### The follow key

```swift
.onChange(of: ClipFollowKey(id: store.items.first?.id, token: vm.followToken)) { old, new in
    follow(from: old, to: new)
}
```

It still reads `store.items`, never the screen's filtered `rows` — that distinction is the entire
point of the handler, and it is what keeps a typed query from reading as a row that moved. Inside
`follow`, the nil-`old.id` first-load guard, the empty-query condition, the `old.id != new.id`
condition and the unconditional `scrollToFollow()` are all unchanged.

The one thing that did change is the mode guard: `guard vm.mode == .clipboard` is gone because it is
now **structural** — the handler exists only while `ClipboardScreen` is mounted, and mounting
registers the current value rather than firing. `scroll` is `@State` on `RootPaletteView`, so the
screen takes a `scrollToFollow` closure, the same injection `QuicklinkArgumentsScreen` uses for
`scrollToTop`.

### The calc card as `rows[0]`

```swift
var rows: [Row] {
    let entries = entries.map(Row.entry)
    guard let calc else { return entries }
    return [.calc(calc)] + entries
}
```

Every consumer resolves through `row(at:)` / `entry(at:)`, so there is no arithmetic to get wrong:
`secondary` and `delete` are naturally card-safe because `entry(at:)` returns nil on a `.calc` row,
and `isCardSelected` replaces `calc != nil && selection == 0`. This is the pattern phase 23 reuses on
the launcher, where the same offset appears in the remaining call sites.

### The protocol member

```swift
/// False when the selection can't be acted on, which hides the footer pill and swallows ⌘K.
func hasPrimaryAction(at selection: Int) -> Bool
```

Defaulted to `true` in the extension, so no phase-20/21 adopter changed. It exists because the error
card's "selectable but action-less" rule was previously carried by `RootPaletteView`'s
`calcSelected && !calcActionable`, computed from a `calcResult` that this phase narrows to the
launcher. Without the member, AC9 regresses: the pill would appear on an error card and ⌘K would set
`showActions` (freezing input behind an overlay that renders nothing).

### Measurements

| Metric                    | Before  | After   | Δ                                                    |
| ------------------------- | ------- | ------- | ---------------------------------------------------- |
| `RootPaletteView.swift`   | 982     | 832     | **−150**                                             |
| `switch vm.mode` count    | 8       | 8       | 0 — arms removed, switches remain                     |
| Compiler warnings (Debug) | 0       | 0       | 0                                                    |
| Harness count             | 17      | 17      | 0                                                    |
| `palette-selection-test`  | 111,066 | 111,108 | +42 assertions                                       |
| Diff size                 | —       | —       | 7 files, +424 / −292 (expected 7 files, +330 / −290)  |
| Binary size (Release)     | —       | —       | not measured                                         |
| Clean install verified?   | —       | n-a     | nothing persists here                                |

---

## Failed tasks

None.

---

## Issues encountered

- **The error card's pill/⌘K rule does not survive the migration on its own.** It was expressed in
  `RootPaletteView` in terms of a `calcResult` that this phase makes launcher-only, so a screen with
  an un-actionable selection had no way to say so. One defaulted protocol member, `hasPrimaryAction`,
  is the fix; three alternatives (an optional `primaryActionTitle`, reusing `actions(at:) != nil` as
  the gate, a downcast) each either touched all four existing adopters or changed behaviour for them.
- **⌘⌫ ownership is not the same shape as ⌘P.** Today the clipboard swallows ⌘⌫ whether or not a row
  is under the selection, but lets ⌘P fall through when there is nothing to pin — so `delete(at:)`
  returns `Void` and the call site returns `.handled`, while `pin(at:)` returns `Bool` like
  `QuicklinkListScreen`'s. Making both `Bool` would have let ⌘⌫ reach the field editor and delete a
  word on an empty list.

---

## Deviations from the phase document

- **The launcher's own logic is untouched, but two switches it shared collapsed.** Removing the
  sibling arms left `activateSelection` and the ↵ handler with a single-case `switch vm.mode`, now a
  `guard vm.mode == .launcher`. The launcher bodies inside them are byte-identical, and
  `modeContent`'s `case .launcher` is unchanged apart from the parameter list losing `clips`/`hist`.
- **One protocol member beyond the phase's stated edits**, justified above. Phases 20 and 21 each
  changed the protocol too; this is the smallest of the three changes.
- **`CalculatorCardView.swift` is absent from the diff.** `CalcActionsMenu` stayed there because the
  un-migrated launcher still calls it, so moving it would have created a cross-feature import for no
  gain. The phase document permits the move ("may move") rather than requiring it.
- **`PaletteRowIndex` still has no app-code adoption.** Unchanged from phases 20 and 21 — both new
  screens index a flat `rows` array directly. The index type gains the clipboard and history shapes
  in the harness instead.

---

## Follow-up work

| Observation                                                                                                            | Where                            | Suggested phase |
| ---------------------------------------------------------------------------------------------------------------------- | -------------------------------- | --------------- |
| Four `as?` downcasts in the key handlers (quicklinks, clipboard, history, emoji) exist only until the last arm goes    | `Features/RootPaletteView.swift` | 23              |
| `screen.rows` is built twice per render in every migrated mode (`screenRows`, then `screen.body`)                      | `Features/RootPaletteView.swift` | 23              |
| `hasPrimaryAction` and the launcher's `calcSelected && !calcActionable` say the same thing in two places until 23 lands | `Features/RootPaletteView.swift` | 23              |
| Interactive regression waived — AC4–AC7 and AC10 unexercised, incl. the query-then-copy check                          | Clipboard + Calculator sweeps    | before merge    |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. The two screen files disappear, both Actions menus return to
  their view files, `RootPaletteView` regains its arms, the follow handler and `ClipFollowKey`, and
  `PaletteScreen` returns to its phase-21 shape. Re-run `xcodegen generate` afterwards. Nothing
  persists and no stored format is involved.
- **Dependent phases that must also be reverted:** none yet. Phase 23 depends on this one, so a revert
  must happen *before* 23 lands.
- **Data risk on revert:** none.

---

## Sign-off

- [~] All acceptance criteria met — AC1, AC2, AC3, AC8, AC9 verified; AC4–AC7 and AC10 structural only
      because interactive verification was waived
- [~] All four checklists passed — `build.md` PASS, `testing.md` PARTIAL (phase gates only);
      `regression.md` and `review.md` waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — pushed to `origin`, merge pending
- [x] **Stopped.** Next phase is a separate session.
