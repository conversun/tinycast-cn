# Phase 20 — Screens: `quicklinkArguments` and `uninstall`

---

## Status

| Field                         | Value                                                    |
| ----------------------------- | -------------------------------------------------------- |
| **Status**                    | Complete                                                 |
| **Started**                   | 2026-08-05                                               |
| **Completed**                 | 2026-08-05                                               |
| **Operator**                  | abue-ammar                                               |
| **Branch**                    | `refactor/20-screens-quicklink-arguments-and-uninstall`  |
| **Commit**                    | single commit on the branch                              |
| **Claude conversations used** | 1                                                        |
| **Actual effort**             | ~40 min vs. estimate of M (2–4 h)                        |

---

## Completed tasks

- [x] Objective 1 — `QuicklinkArgumentsScreen` and `UninstallScreen` conform to `PaletteScreen`
- [x] Objective 2 — both modes' arms removed from every `RootPaletteView` switch
- [x] Objective 3 — the protocol was amended, and the reason is stated below rather than assumed

## Acceptance criteria

- [x] AC1 — both conform, no arm left — verified by: `grep ": PaletteScreen"` finds two adopters;
      no `case .uninstall` or `case .quicklinkArguments` remains in `RootPaletteView`
- [~] AC2 — "line count drops by ~90" — **actual −59** (1125 → 1066). See *Deviations*
- [x] AC3 — `palette-selection-test` covers both shapes and passes — verified by: 1007 assertions,
      exit 0 (989 before, +18)
- [~] AC4 — two-argument prompt, Backspace step-back, ↵ on the last — **structural only**, the paths
      are copied verbatim; not exercised interactively
- [~] AC5 — an options argument filters its choices — **structural only**, same filter expression
- [x] AC6 — four states render, summary character-identical — verified by: the format string is
      unchanged (`"\(selectedCount) of \(total) files selected · \(size)"`); **not** compared to a
      pre-phase screenshot
- [~] AC7 — ⌘↵ toggles unlocked, locked unaffected — **structural only**; the lock guard moved intact
- [x] AC8 — every string unchanged — verified by: every user-visible literal moved verbatim, including
      both empty states, both placeholders and all five Actions rows

---

## Verification

| Checklist                  | Result | Notes                                                                                                   |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + Debug build, exit 0. **0 compiler warnings against a 0 baseline** measured by a clean build on this branch before any edit; the single `warning:` line is `appintentsmetadataprocessor` (no AppIntents dependency), not a compile warning |
| `checklists/testing.md`    | PASS   | All 17 harnesses as one `bash -eu -o pipefail` sweep from the `## Tests` fence — exit 0, zero `FAIL` lines. Phase gates: `palette-selection-test`, `quicklink-test`, `uninstall-test` |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC4, AC5 and AC7 are therefore unexercised**, as is the whole manual checklist (heavyweight-app scan, filter-by-location, locked-row ⌘↵, ↵ → dialog → Trash) |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                         |

### The protocol amendment

Three edits, all forced by adoption — which is what this phase existed to discover.

```swift
func actions(at selection: Int) -> PopoverMenuContent?   // was actions(for row: Row)
func activate(at selection: Int)                          // was activate(_ row: Row)
func secondary(at selection: Int) -> Bool                 // new, sixth member
```

Re-indexing the two callbacks by `Int` has **two independent justifications**, and both were proven by
compiling the shape rather than argued:

1. A free-text argument has **zero rows but a live ↵**, and uninstall's ↵ acts on the session's checked
   set, not the highlighted row. Neither can name a `Row`.
2. A `Row`-typed member is **uncallable through `any PaletteScreen`** — `error: member 'actions' cannot
   be used on value of type 'any Screen'` (`#ExistentialMemberAccess`) — and an existential is exactly
   how `RootPaletteView` must hold the screen for AC1 to be satisfiable. The `Int`-typed version
   compiles and runs; `rows.count`, `primaryActionTitle` and `body(selection:scroll:)` reach through
   the existential unchanged.

`secondary(at:)` covers ⌘↵, a per-screen advertised action derivable from neither `rows` nor
`activate`. Without it, uninstall's ⌘↵ arm has to stay in `RootPaletteView` and the screen is split
across two files.

### Measurements

| Metric                    | Before | After | Δ                                    |
| ------------------------- | ------ | ----- | ------------------------------------ |
| `RootPaletteView.swift`   | 1125   | 1066  | **−59** (AC2 expected ~−90)          |
| `switch vm.mode` count    | 7      | 7     | 0 — arms removed, switches remain    |
| Compiler warnings (Debug) | 0      | 0     | 0                                    |
| Harness count             | 17     | 17    | 0                                    |
| `palette-selection-test`  | 989    | 1007  | +18 assertions                       |
| Binary size (Release)     | —      | —     | not measured                         |
| Clean install verified?   | —      | n-a   | nothing persists here                |

---

## Failed tasks

None.

---

## Issues encountered

- **The phase document says "eight switches"; there are 7.** Same class of miscount as the harness
  count (17, not 18) already recorded in `progress/19`. Phases 21–23 inherit both.
- **Splitting `content` was the cheaper of two bad options.** Nesting the remaining five-arm switch
  inside an `else` forces a ~120-line re-indent — a formatting-only diff the standing contract forbids,
  and one that would hide every moved body from `git diff -M`. `content` therefore delegates to a new
  `modeContent`, costing a duplicated 5-line signature. This is most of the AC2 shortfall.
- **`actionPillLabel` has no neutral fallback.** The other three switches take `default: return 0` /
  `nil` / `break`, but a pill label has no safe empty value, so `case .launcher:` became `default:`.
  Behaviourally identical — the two migrated modes return before the switch — but it does mean a future
  mode silently inherits launcher labels until phase 23 deletes the switch.
- **Three switches now end in `default:`**, weakening `PaletteMode` exhaustiveness for the hybrid
  interval. Accepted: phases 21–23 remove these switches entirely.

---

## Deviations from the phase document

- **AC2 is not reachable at this scope: −59, not −90.** Beyond the `modeContent` signature above, the
  rest of the gap is code the phase explicitly told this phase to leave alone — the
  `onChange(of: vm.mode)` cleanup, and the `searchPrompt` / `pillTint` / `showActionGroup` ternaries,
  which are mode checks but not switch arms. Removing them is phase 23's cleanup.
- **A sixth protocol member was added**, which the phase permits with a stated reason. The reason is
  above; "it was easier" was not it.
- **`PaletteRowIndex` still has no app-code adoption.** Both screens are flat, single-section,
  calc-card-free lists where `rows.indices.contains(selection)` is exactly equivalent, so wrapping it
  in the index type would be ceremony. It gains harness coverage for both shapes here and earns its
  keep in phase 23's launcher. Operator-approved before implementing.
- **`QuicklinkArgumentsView`'s double-tap now calls `activate(at:)` directly** rather than
  `RootPaletteView.activateSelection`, so it no longer passes the `!isCollapsed` guard. Unreachable —
  the palette renders `Color.clear` instead of any content while collapsed.

---

## Follow-up work

| Observation                                                                                          | Where                            | Suggested phase |
| ------------------------------------------------------------------------------------------------------ | -------------------------------- | --------------- |
| `searchPrompt`, `pillTint` and `showActionGroup` still sniff `vm.mode` for the two migrated screens  | `Features/RootPaletteView.swift` | 23              |
| The `onChange(of: vm.mode)` cleanup still cancels both sessions from the root view                   | `Features/RootPaletteView.swift` | 23              |
| Four `default:` arms weaken `PaletteMode` exhaustiveness while the hybrid state lasts                 | `Features/RootPaletteView.swift` | 23              |
| `content` / `modeContent` collapse back into one function once the last switch arm goes               | `Features/RootPaletteView.swift` | 23              |
| Interactive regression for both screens was waived — AC4, AC5, AC7 unexercised                        | Uninstall + Quicklinks sweeps    | before merge    |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. `RootPaletteView` returns to its seven-arm switches, the two
  screen files disappear, `UninstallActionsMenu` returns to `UninstallView.swift`, and the protocol
  returns to its phase-19 shape. Nothing persists and no stored format is involved.
- **Dependent phases that must also be reverted:** none yet. Phase 21 depends on this one, so a revert
  must happen *before* 21 lands.
- **Data risk on revert:** none.

---

## Sign-off

- [~] All acceptance criteria met — AC2 missed (−59 vs ~−90, reasoned above); AC4, AC5, AC7 structural
      only because interactive verification was waived
- [~] All four checklists passed — `build.md` and `testing.md` PASS; `regression.md` and `review.md`
      waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — pushed to `origin`, merge pending
- [x] **Stopped.** Next phase is a separate session.
