# Phase 21 — Screens: `quicklinks` and `emoji`

---

## Status

| Field                         | Value                                        |
| ----------------------------- | -------------------------------------------- |
| **Status**                    | Complete                                     |
| **Started**                   | 2026-08-05                                   |
| **Completed**                 | 2026-08-05                                   |
| **Operator**                  | abue-ammar                                   |
| **Branch**                    | `refactor/21-screens-quicklinks-and-emoji`   |
| **Commit**                    | single commit on the branch                  |
| **Claude conversations used** | 1                                            |
| **Actual effort**             | ~35 min vs. estimate of M (2–4 h)            |

---

## Completed tasks

- [x] Objective 1 — `QuicklinkListScreen` and `EmojiScreen` conform to `PaletteScreen`
- [x] Objective 2 — their chords moved out of `RootPaletteView`'s global handlers into the screens
- [x] Objective 3 — both modes' arms removed from every switch except the `screen` factory

## Acceptance criteria

- [x] AC1 — both conform, no arm left — verified by: four adopters of `PaletteScreen`; `.emoji` and
      `.quicklinks` survive only in the `screen` factory switch
- [x] AC2 — one protocol member, justified — verified by: the diff on `PaletteScreen.swift` is one
      method plus `PaletteAxis` and a `nil` default; see *The protocol member* below
- [~] AC3 — ↑/↓ move one visual grid row, spilling by column — **structural + harness**;
      `EmojiGridGeometry.up/down` are called, not reimplemented. Not exercised interactively
- [~] AC4 — ←/→ move one cell and are consumed — **structural**; `EmojiScreen.move` returns non-`nil`
      on both axes, so the key returns `.handled`
- [~] AC5 — ←/→ still move the caret everywhere else — **structural**; the extension default returns
      `nil`, which reaches the existing `.ignored` path on the other three screens and on every
      unmigrated mode (where `screen` is `nil`)
- [~] AC6 — ⌘P pins and the row jumps to the top — **structural**; `core.toggleQuicklinkPinned` and
      the store's pinned-first order are outside the diff
- [~] AC7 — ⌘⌫ honours "confirm before deleting" — **structural**; the call is
      `core.deleteQuicklink(id:)` with its default `confirming: true`, unchanged
- [x] AC8 — ⌘↵ only with a handler override — verified by: `secondary(at:)` returns `false` unless
      `openWithBundleID != nil`, so the key stays unhandled on every other row exactly as before
- [x] AC9 — `palette-selection-test` covers grid row movement — verified by: 111,066 assertions
      (1,007 before), exit 0, plus a deliberate-break proof
- [x] AC10 — skin tone at both points — verified by: render tone passed as `settings.emojiSkinTone`
      into `EmojiGridView`; copy-time tone stays in `AppCore`, outside the diff

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                          |
| -------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + Debug build, exit 0. **0 compiler warnings against a 0 baseline** measured by a clean build on this branch before any edit; the one `warning:` line is `appintentsmetadataprocessor` (no AppIntents dependency) |
| `checklists/testing.md`    | PASS   | All 17 harnesses as one `bash -eu -o pipefail` sweep from the `## Tests` fence — exit 0, zero `FAIL` lines. Phase gates: `palette-selection-test`, `emoji-test`, `quicklink-test`                                                |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC3–AC7 are therefore unexercised**, as is the whole manual checklist: four-direction grid spill across a section boundary, ←/→ caret in the launcher, ⌘P/⌘⌫/⌘↵, skin-tone re-render  |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                                                                                                                                                |

### The protocol member

```swift
/// The selection an arrow key lands on, or nil to leave the key to the palette's own default.
func move(_ delta: Int, axis: PaletteAxis, from selection: Int) -> Int?
```

One member, defaulted to `nil` in an extension so no phase-20 adopter changed. `nil` means "no screen
override", which lets `RootPaletteView` keep its **existing per-axis default**: vertical falls back to
the linear `move(delta)`, horizontal falls through as `.ignored` to the field editor. That asymmetry
is the whole design — it satisfies AC3, AC4 and AC5 together, because `EmojiScreen` is the only type
that ever returns non-`nil` and therefore the only screen where ←/→ are consumed.

`PaletteAxis` (`.vertical` / `.horizontal`) is the enum the phase document's own example signature
names; it is two cases in `PaletteScreen.swift`, not a navigation subsystem.

### The three chords with no protocol member

⌘P, ⌘⌫ and ⌥↵ are screen-level but the hard gate allows exactly one new member (navigation). They are
routed by a concrete downcast in the existing handlers — `screen as? QuicklinkListScreen` and
`screen as? EmojiScreen` — calling `pin(at:)`, `delete(at:)` and `pasteKeepingWindowOpen(at:)` on the
screen. No `vm.mode` sniffing, all logic owned by the screen, and phase 23 deletes the call sites.
Three more protocol members was the alternative, and the gate forbids it.

### Measurements

| Metric                    | Before | After   | Δ                                   |
| ------------------------- | ------ | ------- | ----------------------------------- |
| `RootPaletteView.swift`   | 1066   | 982     | **−84**                             |
| `switch vm.mode` count    | 8      | 8       | 0 — arms removed, switches remain    |
| Compiler warnings (Debug) | 0      | 0       | 0                                   |
| Harness count             | 17     | 17      | 0                                   |
| `palette-selection-test`  | 1,007  | 111,066 | +110,059 assertions                 |
| Diff size                 | —      | —       | 9 files, +434 / −231 (expected 7 files, +260 / −220) |
| Binary size (Release)     | —      | —       | not measured                        |
| Clean install verified?   | —      | n-a     | nothing persists here               |

---

## Failed tasks

None.

---

## Issues encountered

- **The first column invariant in the harness was too weak to catch the bug it was written for.**
  Asserting `column(down(i)) <= column(i)` passes even when a section spill drops the column to zero —
  the deliberate-break run caught only 2 explicit cases. Rewritten to assert the *exact* expected
  column, `min(sourceColumn, cellsInTargetRow - 1)`, the same break produces **4,044 failures and
  exit 1**. A property assertion that admits the failure mode is worse than no assertion, because it
  reads like coverage.
- **`EmojiGridGeometry.down` misbehaves when a section is followed by an empty one** — `counts: [5, 0]`
  gives `down(from: 2) == 4`, moving *backwards* into the same visual row, because
  `min(local % columns, counts[s + 1] - 1)` is `-1`. Unreachable: `EmojiGrid.sections` guards
  `!entries.isEmpty` before appending. The file is on the must-not-change list, so the harness
  deliberately exercises non-empty shapes only, with a one-line note recording why.
- **The phase document's "seven files" is nine.** Two new screens plus the seven listed, because
  `docs/development.md` has to carry the harness's new compile input (below) and `project.pbxproj` is
  regenerated. Same class of miscount as the harness count in `progress/19` and the switch count in
  `progress/20`.

---

## Deviations from the phase document

- **`docs/development.md` is an eighth file the phase does not list.** The harness cannot gain grid
  cases without compiling `EmojiGridGeometry.swift`, so its `## Tests` command line gains that input
  and the doc must move with it or the sweep breaks. Operator-approved before implementing.
  `EmojiGridGeometry.swift` itself is absent from the diff, as required.
- **⌥↵ is routed by downcast, not by `secondary(at:)`.** `secondary` is ⌘↵ by contract (phase 20), and
  emoji's ⌥↵ is a second, different chord. See *The three chords* above.
- **`command` is still tested before `option` in the ↵ handler**, so ⌘⌥↵ copies rather than pasting
  in place — preserving today's behaviour, which the naive restructuring would have inverted.
- **`PaletteRowIndex` still has no app-code adoption.** Unchanged from phase 20's reasoning; the emoji
  screen indexes `sections.flatMap(\.entries)` exactly as before. The index type gains the grid shapes
  in the harness, where it is now cross-checked *against* `EmojiGridGeometry` — the two agree on flat
  row order for every shape tested.

---

## Follow-up work

| Observation                                                                                                              | Where                                | Suggested phase |
| -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | --------------- |
| `EmojiGrid.sections` is built twice per render in emoji mode (`screen.rows.count`, then `screen.body`) — one build before | `Features/RootPaletteView.swift`     | 23              |
| Two `as?` downcasts in the key handlers exist only until the last switch arm goes                                        | `Features/RootPaletteView.swift`     | 23              |
| `EmojiGridGeometry.down` moves backwards across a trailing empty section (unreachable today)                             | `Core/Emoji/EmojiGridGeometry.swift` | 34 or later     |
| Interactive regression for both screens was waived — AC3–AC7 unexercised                                                 | Emoji + Quicklinks sweeps            | before merge    |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. The two screen files disappear, both Actions menus return to
  their view files, `RootPaletteView` regains its arms and `moveEmojiRow`, and `PaletteScreen` returns
  to its phase-20 shape. Re-run `xcodegen generate` afterwards. Nothing persists and no stored format
  is involved.
- **Dependent phases that must also be reverted:** none yet. Phase 22 depends on this one, so a revert
  must happen *before* 22 lands.
- **Data risk on revert:** none.

---

## Sign-off

- [~] All acceptance criteria met — AC1, AC2, AC8, AC9, AC10 verified; AC3–AC7 structural only
      because interactive verification was waived
- [~] All four checklists passed — `build.md` and `testing.md` PASS; `regression.md` and `review.md`
      waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — pushed to `origin`, merge pending
- [x] **Stopped.** Next phase is a separate session.
