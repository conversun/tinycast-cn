# Phase 19 — `PaletteScreen` scaffold and the selection harness

---

## Status

| Field                         | Value                                |
| ----------------------------- | ------------------------------------ |
| **Status**                    | Complete                             |
| **Started**                   | 2026-08-05                           |
| **Completed**                 | 2026-08-05                           |
| **Operator**                  | abue-ammar                           |
| **Branch**                    | `refactor/19-palette-screen-scaffold` |
| **Commit**                    | single commit on the branch          |
| **Claude conversations used** | 1                                    |
| **Actual effort**             | ~25 min vs. estimate of M (2–4 h)    |

---

## Completed tasks

- [x] Objective 1 — `Tinycast/Features/PaletteScreen.swift` declares the protocol from the review:
      `@MainActor`, `associatedtype Row: Identifiable`, and exactly `rows`, `primaryActionTitle`,
      `actions(for:)`, `activate(_:)`, `body(selection:scroll:)`. No defaults, no erasure, no adopters
- [x] Objective 2 — `Tools/palette-selection-test.swift` asserts the flat index maps 1:1 onto visible
      row order, calculator card at index 0 included, over the pure `PaletteRowIndex` type
- [x] Objective 3 — registered in `docs/development.md`, `AGENTS.md` and `checklists/testing.md`

## Acceptance criteria

- [x] AC1 — `PaletteScreen` exists, is `@MainActor`, declares exactly the five members — verified by:
      reading the 13-line file; `@ViewBuilder` on a protocol requirement compiles clean under Swift 6
- [x] AC2 — nothing conforms to it — verified by: `grep -rn ": PaletteScreen" Tinycast` is empty
- [x] AC3 — the harness compiles standalone against Foundation and the pure type — verified by:
      `swiftc -swift-version 6 Tinycast/Features/PaletteRowIndex.swift Tools/palette-selection-test.swift`
      with no other source on the command line
- [x] AC4 — coverage — verified by: 989 assertions covering no calc card, calc card present, lone calc
      card, empty list, all-empty sections, single section, multiple sections, an empty section in the
      middle, clamping at both ends (including `Int.min` / `Int.max`), out-of-bounds inversion, and an
      exhaustive sweep of 128 shapes (`hasCalculator` × three section counts 0…3)
- [x] AC5 — all three docs list the harness — verified by: the diff. `checklists/testing.md` already
      carried a placeholder row written by the roadmap; it now names the real compiled source
- [x] AC6 — `RootPaletteView.swift` byte-identical — verified by: `git diff --name-only | grep
      RootPaletteView` is empty, checked after every edit round
- [~] AC7 — "all 18 harnesses pass" — **the count is 17, not 18.** All 17 pass. See *Deviations*

---

## Verification

| Checklist                  | Result | Notes                                                                                     |
| -------------------------- | ------ | ----------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + Debug build succeeded; 0 warnings against a 0 baseline measured on `main` before branching |
| `checklists/testing.md`    | PASS   | All 17 harnesses, run as one `bash -eu -o pipefail` sweep from the `## Tests` fence — exit 0, zero `FAIL` lines |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. Trivially safe: the diff adds two unreferenced source files and touches no view, store or window |
| `checklists/review.md`     | WAIVED | Operator waived                                                                           |

### The deliberate-break proof

Mandatory for this phase, and performed. `row(at:)`'s
`var offset = hasCalculator ? index - 1 : index` was changed to `var offset = index` — dropping the
calculator card's shift, exactly the class of bug phases 20–23 could introduce silently.

The harness reported **302 failed, 687 passed, exit 1**, naming the defect rather than just counting:

```
FAIL: the first result follows the calculator card — got element(section: 0, offset: 1),
      want element(section: 0, offset: 0)
FAIL: launcher shape: section 1 offset 0 inverts to 2 — got Optional(3), want Optional(2)
FAIL: single section with calculator: index 3 resolves to a row
```

The break was reverted and the harness returned to 989 passed / 0 failed, exit 0. The guard works.

### Measurements

| Metric                     | Before | After | Δ                            |
| -------------------------- | ------ | ----- | ---------------------------- |
| Binary size (Release)      | —      | —     | not measured; additive phase |
| Clean install verified?    | —      | n-a   | nothing persists here        |
| Compiler warnings (Debug)  | 0      | 0     | 0                            |
| Harness count              | 16     | 17    | +1                           |
| Harness assertions added   | —      | 989   | +989                         |

---

## Failed tasks

None.

---

## Issues encountered

- **The pure type cannot live in `PaletteScreen.swift`.** That file needs `AnyView`, `ScrollIntent` and
  `PopoverMenuContent`, so it imports SwiftUI and the harness can never compile it. The phase's file
  table lists five files; the Implementation boundaries separately require the index type in a
  Foundation-only file. The boundaries win, so the phase lands six files.
- **The harness needs `@MainActor` on its test struct**, like `volume-test` and every other harness —
  static mutable counters are a data race under `-swift-version 6` otherwise. `PaletteRowIndex` itself
  is a plain `Sendable` value type and carries no isolation.
- **The comment budget bit twice.** The first draft of both new files used wrapped multi-line doc
  comments, which the standing contract forbids outright ("never two consecutive comment lines", hard
  cap 100 characters). Both were rewritten as single lines under 100 characters. Worth knowing before
  phases 20–23, which will be writing far more prose than this one.

---

## Deviations from the phase document

- **Six files, not five.** `Tinycast/Features/PaletteRowIndex.swift` is the extra one, for the reason
  above. **Operator chose `Features/` over `Core/`**, so this is the first harness-compiled
  Foundation-only file outside `Core/`. That is recorded in both `AGENTS.md` (on the flat-selection
  invariant itself) and `checklists/testing.md` (a purity checkbox), so phases 27–29 cannot move it
  without noticing the harness command line encodes its path.
- **The harness count is 17, not the document's 18.** There were 16 before this phase — `progress/18b`
  says the same. Every phase document from here on that says "18 harnesses" means 17.
- **`checklists/testing.md`'s row already existed**, written speculatively as "**Added in phase 19.**
  The palette screens' `rows` arrays." It was rewritten to name `Features/PaletteRowIndex.swift`, since
  that is what the harness actually compiles.
- `PaletteRowIndex` carries `index(section:offset:)`, the inverse of `row(at:)`, which the phase does
  not name. It is what makes the 1:1 claim testable rather than assertable, and it is the operation
  `RootPaletteView` already performs today in four places (`vm.selection = index + calcCount`,
  `clips.firstIndex(of:) ?? 0`).

---

## Follow-up work

| Observation                                                                                                              | Where                             | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------ | --------------------------------- | --------------- |
| `LauncherList.rows` runs nine `rest.filter` passes over the same array on every body evaluation                          | `Features/Launcher/LauncherView.swift` | 23              |
| `PaletteRowIndex` is unreferenced by app code until phase 20 adopts it; if 20 finds it wrong, amend it — that is expected | `Features/PaletteRowIndex.swift`  | 20              |
| Phase documents 20–23 say "18 harnesses"; the real count after this phase is 17                                          | `docs/refactor/phases/20–23`      | 34              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. The phase is purely additive — a protocol nothing conforms to,
  a type nothing calls, a test nothing depends on, and three doc edits. No runtime behaviour is reachable
  from any of it.
- **Dependent phases that must also be reverted:** none yet. Phases 20–23 depend on this one, so a
  revert must happen *before* 20 lands, not after.
- **Data risk on revert:** none — nothing here persists or reads anything.

---

## Sign-off

- [x] All acceptance criteria met (AC7 partial: 17 harnesses, not 18 — the document miscounts)
- [~] All four checklists passed — `build.md` and `testing.md` PASS; `regression.md` and `review.md`
      waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — pushed to `origin`, merge pending
- [x] **Stopped.** Next phase is a separate session.
