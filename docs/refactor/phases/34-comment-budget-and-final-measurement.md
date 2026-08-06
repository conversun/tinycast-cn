# Phase 34 — Comment budget, comment pass, and final measurement

**Milestone:** M7 · **Effort:** L · **Risk:** Low · **Context:** High

---

## Overview

Write the comment budget into `AGENTS.md`, run the triage pass over the 181 stacked blocks and 572
over-120-character comment lines, then re-measure everything against the phase-01 baseline and update the
architecture documentation.

## Why this phase exists

Review finding H-1: 1,850 comment lines against 26,379 of non-generated source, **181 stacked blocks**
(a direct violation of the project's own rule), **953 comment lines over 100 characters — 51 % of every
comment in the codebase** — against only 158 code lines that long. The longest single comment line is
**588 characters**.

This is an agent-authored-code failure mode and it compounds: each pass reads the surrounding prose,
matches its register, and emits more. Without a **greppable budget**, whatever this pass removes grows
straight back.

## Architecture Review reference

**H-1** · §4.1b comment rules · Roadmap W7.6 and W8

## Objectives

1. Replace the `AGENTS.md` comment clause with the six-rule budget.
2. Triage every stacked block and every over-cap line: delete, compress, or relocate.
3. Re-measure all phase-01 baselines and publish the before/after table.
4. Update `docs/architecture.md` to describe the pure/effect/view layering as the named architecture.

## Expected files to modify

| File                                       | Change                                               |
| ------------------------------------------ | ---------------------------------------------------- |
| `AGENTS.md`                                | The comment budget, replacing the current clause.    |
| `docs/architecture.md`                     | The layering, and the folder tree as its expression. |
| `docs/<subsystem>.md`                      | Receive relocated explanations.                      |
| Source files, **one subsystem per commit** | The triage pass.                                     |
| `docs/refactor/progress/34-*.md`           | The final measurement table.                         |

## Files that must NOT change

- `Tinycast/DesignSystem/Scrolling/EdgeDissolve.swift`
- `Tinycast/DesignSystem/Scrolling/ThinScrollbar.swift`

  **Off-limits by `AGENTS.md` — including their comments.** They have been moved twice in this roadmap
  and never opened; do not open them now.

- `*.generated.swift` — regenerate rather than edit, and there is no reason to
- `docs/architecture-review.md` — the review is a fixed artefact

## Implementation boundaries

- **The budget goes in first, in its own commit**, before any source is touched. It is the durable part.

  > **Comments — minimal code, not annotated prose**
  >
  > 1. One line. **Never two consecutive comment lines.** If it needs two, it needs a named function, a
  >    named constant, or a type.
  > 2. **Hard cap: 100 characters, including indentation.** Longer belongs in `docs/<subsystem>.md`.
  > 3. Comment the _why_, the gotcha, or the invariant. Never restate the code, never narrate a
  >    sequence, never argue a decision at length in-line.
  > 4. `///` on a public type or method is exempt from rule 1, not from rule 2.
  > 5. **Prefer deleting a comment to updating it.**
  > 6. Never add a comment explaining a change you just made. The diff is not the audience.

- **Triage, in this order of preference:**
  1. **Delete** if it restates the code.
  2. **Compress** to one clause under 100 characters if it names a real gotcha.
  3. **Relocate** to the owning `docs/<subsystem>.md`, leaving a one-line pointer, if it is genuinely a
     paragraph of rationale.

  **Relocation is the default for anything explaining an invariant.** Most of the best long comments
  here — the `WindowLayout` AX-coordinate flip, the `CurrencyRateStore` consent gate, the
  `SpotlightNames` measurement, the `ClipboardStore` two-branch load query — are _already_ written up in
  `docs/`, so those are usually a delete plus a reference rather than a rewrite.

- **One subsystem per commit.** A reviewer must be able to read a pure comment diff. Suggested order:
  Calculator, Emoji, Snippets, Quicklinks, Uninstall, WindowManagement, HotKeys, Clipboard, Launcher,
  Palette, Windows, App.
- **Never delete a comment you do not understand.** If its meaning is unclear, relocate it verbatim to
  `docs/` — losing an explanation is worse than an over-long one.
- Do not touch code. Not one statement. If a comment is only necessary because the code is unclear,
  record it as follow-up work; do not fix it here.
- Do not reflow, re-indent or re-wrap anything.

## Detailed acceptance criteria

1. `AGENTS.md` carries the six-rule budget, in its own commit.
2. Stacked comment blocks: **0** outside the two off-limits files.
   ```
   find Tinycast -name "*.swift" ! -name "*.generated.swift" -exec \
     awk '/^[[:space:]]*\/\//{r++; if(r==2) b++; next} {r=0} END{print b+0, FILENAME}' {} \;
   ```
3. Comment lines over 100 characters: **0** outside the two off-limits files.
4. Every deleted paragraph of rationale is either genuinely redundant or present in `docs/`.
5. No code statement changed anywhere in the phase.
6. `docs/architecture.md` describes the pure / effect / view layering and the folder tree.
7. Final measurement table complete, all metrics compared to phase 01.
8. All 19 harnesses pass; Debug and Release build; UI pixel-identical.

## Manual verification checklist

- [ ] `checklists/build.md` including the **Release build** and binary size
- [ ] `checklists/testing.md` — all 19
- [ ] `checklists/regression.md` — **the full document**
- [ ] Re-run all four H-1 comment metrics; record before/after
- [ ] `git diff` per commit contains **only** comment lines — verify with
      `git show --stat` and by eye
- [ ] Spot-check five relocated explanations: each is findable in `docs/` from the pointer left behind
- [ ] Read `AGENTS.md` end to end — every path, every invariant, every harness command line is current

### Final measurement table

| Metric                         | Phase 01 baseline | Now | Δ                                   |
| ------------------------------ | ----------------- | --- | ----------------------------------- |
| Release binary size            |                   |     | must be < 3 MB upto 4MB             |
| Cold launch, median of 3       |                   |     | must be within 10 %                 |
| `AppCore.start`                |                   |     |                                     |
| `AppIndex.scan` cold / warm    |                   |     | expect a large warm drop (phase 07) |
| `PaletteWindowController.show` |                   |     |                                     |
| `UninstallScanner.scan`        |                   |     | expect 6–12× (phase 08)             |
| RSS after 10 palette opens     |                   |     | must be within 40–80 MB             |
| RSS after 50 clipboard images  |                   |     |                                     |
| `RootPaletteView` line count   | 1126              |     | target ~350                         |
| `AppCore` line count           | 1348              |     | target ~250                         |
| Comment lines / total          | 1850 / 26379      |     |                                     |
| Stacked blocks                 | 181               |     | target 0                            |
| Comments > 100 chars           | 953               |     | target 0                            |

## Regression risks

| Risk                                                                     | Mitigation                                                                           |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| **A load-bearing explanation is lost.** The one real risk in this phase. | Triage prefers relocation; "never delete what you do not understand"                 |
| A code line is changed inside a comment-only commit                      | AC5 + per-commit diff inspection                                                     |
| The off-limits files are edited                                          | They are on the must-not-change list for the third time                              |
| The budget is written but not enforced, and comments regrow              | It is greppable; add the two commands to `checklists/review.md` if not already there |
| A metric regressed and is quietly omitted from the table                 | AC7 requires every row filled                                                        |

## Rollback strategy

`git revert` the specific subsystem's commit. Comment-only commits are the safest revert in the
roadmap. The `AGENTS.md` budget commit should not be reverted — it is the durable deliverable.

## Expected commit size

1 commit for `AGENTS.md` (+30 / −6), ~12 comment commits (−700 to −900 lines total), 1 docs commit.

## Suggested commit message

For the budget:

```
Set a checkable comment budget in AGENTS.md

One line, never two consecutive; 100-character hard cap; longer
explanations belong in docs/<subsystem>.md. The existing rule was
satisfiable in letter by writing one 588-character line — 51% of comments
in the codebase exceed 100 characters against 158 code lines that long.
```

Per subsystem:

```
Trim comments in <subsystem> to the budget

Restatements deleted, gotchas compressed to one clause, rationale moved to
docs/<subsystem>.md behind a one-line pointer. No code changed.
```

## Dependencies

**Phase 33.** Effectively depends on everything — this is the closing phase.

## Definition of Done

- All acceptance criteria met
- Final measurement table complete and published in the progress file
- `AGENTS.md` and `docs/architecture.md` current
- `ROADMAP.md` status table fully filled in
- Merged

## Estimated difficulty

**Medium** per subsystem, **High** in aggregate. Judgement-heavy rather than technically hard.

## Estimated Claude context usage

**High.** One subsystem per conversation.

## Notes for reviewers

- **A comment-only commit must contain only comment lines.** `git show` each one. A code change hiding
  in a comment pass is the worst possible place for it, because nobody reads these diffs carefully.
- For every deleted paragraph, ask: _where did this knowledge go?_ If the answer is "nowhere, it was
  redundant", check that claim. If it is "docs/x.md", follow the pointer.
- The final measurement table is the roadmap's report card. Fill in every row, including any that
  regressed — a hidden regression is worse than an admitted one.
- After this phase, `AGENTS.md` is the only thing standing between this codebase and the comment volume
  growing straight back. Read it as though you were the next agent picking up a ticket.
