# Phase 19 — `PaletteScreen` scaffold and the selection harness

**Milestone:** M3 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

Introduce the `PaletteScreen` protocol and — before any screen migrates — land
`Tools/palette-selection-test.swift`, the harness that protects the flat-selection invariant through the
rest of M3. **No screen migrates in this phase.**

## Why this phase exists

`RootPaletteView` carries the same 7-way `switch vm.mode` in eight places, and the flat-selection
invariant is maintained by eight independent pieces of index arithmetic. Phases 20–23 rewrite all of
that. Doing it without an automated guard on the invariant would be reckless: it is the single most
load-bearing rule in the app and a violation is silent — the highlight is simply on the wrong row.

## Architecture Review reference

**C-2** · Roadmap W4, including its explicit mitigation requiring the harness first

## Objectives

1. Add `Tinycast/Palette/PaletteScreen.swift` (or `Features/` until phase 28 moves it) declaring the
   protocol from the review:
   `rows`, `primaryActionTitle`, `actions(for:)`, `activate(_:)`, `body(selection:scroll:)`.
2. Add `Tools/palette-selection-test.swift` asserting, over the **pure `rows` arrays only**, that the
   flat index maps 1:1 onto visible row order — including the calculator card at index 0 when present.
3. Register the harness in `docs/development.md` and `AGENTS.md`.

## Expected files to modify

| File                                    | Change                                                |
| --------------------------------------- | ----------------------------------------------------- |
| `Tinycast/Features/PaletteScreen.swift` | **New.** The protocol. ~25 lines, no implementations. |
| `Tools/palette-selection-test.swift`    | **New.** The harness.                                 |
| `docs/development.md`                   | Add the harness command line.                         |
| `AGENTS.md`                             | Register the harness and its purity requirement.      |
| `docs/refactor/checklists/testing.md`   | Add the row to the harness table.                     |

## Files that must NOT change

- `Tinycast/Features/RootPaletteView.swift` — **not one line.** No screen migrates in this phase.
- Any `Features/*/…List.swift` or `…View.swift`
- Any store

## Implementation boundaries

- **Nothing adopts the protocol yet.** This phase compiles a protocol and a test. If `RootPaletteView`
  appears in the diff, the phase is wrong.
- The harness must be **Foundation-only**, like every other harness. It cannot import SwiftUI, so it
  cannot test a `body`. It tests the **row-order contract**: given a set of section counts and an
  optional leading calculator card, index _n_ resolves to the same element the view would highlight.
- Model that contract as a small pure type the screens will later use — a `PaletteRowIndex` or similar
  — placed in a Foundation-only file so both the harness and the screens can use it. Keep it under ~40
  lines. **Do not** build a general-purpose list abstraction.
- The protocol uses an `associatedtype Row: Identifiable`. Do not introduce type erasure, existentials
  or a `AnyPaletteScreen` wrapper in this phase — the adoption phases will show what is actually needed.
- Do not add default implementations. An empty protocol with no defaults is the correct starting point.
- `@MainActor` on the protocol, matching everything else in the palette.

## Detailed acceptance criteria

1. `PaletteScreen` exists, is `@MainActor`, and declares exactly the five members listed.
2. Nothing conforms to it yet.
3. `Tools/palette-selection-test.swift` compiles standalone with `swiftc -swift-version 6` against only
   Foundation and the new pure index type.
4. The harness covers at least: no calc card; calc card present; empty list; single section; multiple
   sections; selection clamped at both ends.
5. `docs/development.md`, `AGENTS.md` and `checklists/testing.md` all list the new harness.
6. `RootPaletteView.swift` is byte-identical to before.
7. All 17 harnesses pass.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — all 17, including the new one
- [ ] `checklists/regression.md` — Core sweep (should be trivially unchanged)
- [ ] Run `palette-selection-test` and read its output — confirm it actually asserts something
- [ ] Deliberately break the pure index type in a scratch edit → the harness **fails**. Revert the break.
      _(A test that cannot fail is not a test.)_
- [ ] `git diff --stat` shows `RootPaletteView.swift` absent

## Regression risks

| Risk                                                                      | Mitigation                                                                 |
| ------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| The harness passes vacuously and gives false confidence through all of M3 | The "deliberately break it" step is mandatory                              |
| The protocol is over-designed before any screen has adopted it            | Five members, no defaults, no erasure                                      |
| `RootPaletteView` gets "started on"                                       | AC6, and the reviewer checks `--stat` first                                |
| The pure index type drifts from what the screens actually need            | Phase 20 is the first adopter and may amend it — that is expected and fine |

## Rollback strategy

`git revert <sha>`. Additive only — a protocol nothing conforms to and a test nothing depends on.

## Expected commit size

5 files, +180 / −0 lines (mostly the harness).

## Suggested commit message

```
Add the PaletteScreen protocol and the selection harness

Scaffold for the palette split. The harness lands first, deliberately:
the flat-selection invariant is currently maintained by eight independent
index computations that phases 20–23 rewrite, and a violation is silent.
Nothing conforms to the protocol yet.
```

## Dependencies

**Phase 18 (hard).** Blocks 20–23.

## Definition of Done

- All acceptance criteria met
- The harness proven to fail on a deliberate break
- Docs updated in the same commit
- Merged

## Estimated difficulty

**Medium.** Designing the pure index contract is the real work.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Check `git diff --stat` for `RootPaletteView.swift` first.** Its absence is the phase's main
  discipline.
- Read the harness assertions properly. A harness that asserts `count == count` passes forever and buys
  nothing, and you will be relying on it for the next four phases.
- Do the deliberate-break test yourself. It takes 60 seconds and it is the only proof the guard works.
- Push back on any type erasure, `AnyView` wrapper or associated-type workaround introduced _before_ a
  single screen has adopted the protocol. Let phase 20 discover what is needed.
