# Phase 03 — Named paste-timing constants

---

## Status

| Field                         | Value                                      |
| ----------------------------- | ------------------------------------------ |
| **Status**                    | Complete                                   |
| **Started**                   | 2026-08-05                                 |
| **Completed**                 | 2026-08-05                                 |
| **Operator**                  | abue-ammar                                 |
| **Branch**                    | `refactor/03-named-paste-timing-constants` |
| **Commit**                    | `<sha>`                                    |
| **Claude conversations used** | 1                                          |
| **Actual effort**             | ~0.25h vs. estimate of S                   |

---

## Completed tasks

- [x] Objective 1 — two named `private static let` constants on `Paster`: one for the post-`activate()`
      delay (`0.08`), one for the direct `postToPid` delay (`0.05`)
- [x] Objective 2 — every delay literal replaced with a constant (four call sites, not three — see
      Deviations)
- [x] Objective 3 — one ≤100-character comment per constant, saying what it compensates for

## Acceptance criteria

- [x] AC1 — no numeric literal remains in an `asyncAfter(deadline:)` call in `Paster.swift` — verified
      by: `grep -n "asyncAfter" Tinycast/Core/Paster.swift` returns four lines, all reading
      `activationDelay` or `directPostDelay`
- [x] AC2 — constant values byte-identical to the literals replaced — verified by: `git diff` shows
      `0.08` and `0.05` moved verbatim into the declarations; no digit changed anywhere in the diff
- [x] AC3 — each constant carries at most one comment line, ≤100 characters — verified by: measured with
      `awk length($0)` — 95 and 99 characters including indentation. The first draft came in at 101 and
      was shortened before the final build
- [x] AC4 — `SnippetTextInjector` untouched — verified by: `git diff --name-only` returns exactly
      `Tinycast/Core/Paster.swift`
- [x] AC5 — zero behaviour change — verified by: same values, same `DispatchQueue.main.asyncAfter` form,
      no conversion to `Task.sleep`; `git diff -U0 | grep '^[-+].*"'` is empty. Confirmed at runtime by
      the operator's paste sweep below

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                  |
| -------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | §1–4. Pre-phase baseline + post-change Debug + Release all `BUILD SUCCEEDED`; zero new warnings; binary +0 B. §5–6 n-a (§6 does not list phase 03)                                     |
| `checklists/testing.md`    | PASS   | Harnesses run: `snippets-test` (not mandatory — `Paster.swift` is in no row of the source map; run because the harness stubs `Paster` at `Tools/snippets-test.swift:1480`). ALL PASSED |
| `checklists/regression.md` | PASS   | Core sweep + the phase's own paste sweep, run by the operator                                                                                                                          |
| `checklists/review.md`     | PASS   | §1–8 mechanically clean; 1 file, +10/−4                                                                                                                                                |

### Measurements

| Metric                     | Before    | After     | Δ                         |
| -------------------------- | --------- | --------- | ------------------------- |
| Binary size (Release)      | 3,473,448 | 3,473,448 | +0 B (0 %)                |
| Clean install verified?    | —         | n-a       | phase persists nothing    |
| Cold launch, median of 3   | —         | —         | n-a, not a startup path   |
| RSS after 10 palette opens | —         | —         | n-a, no allocation change |
| Phase-specific signpost    | —         | —         | no signpost covers this   |

This phase claims no performance effect — it is a naming change. The binary is byte-identical in size to
phase 02's recorded figure, which is the expected result for replacing literals with `private static let`
constants of the same value.

> The 3,473,448-byte binary is over `build.md` §4's 3 MB upto 4MB budget, and was already over it at phase 02.
> That is a pre-existing condition of the refactor baseline, not something this phase moved.

---

## Failed tasks

| What | Why it failed | Decision |
| ---- | ------------- | -------- |
| none | —             | —        |

---

## Issues encountered

- **The phase document undercounts the call sites.** It says "three unnamed literals — `0.08`, `0.05`,
  `0.05`", but `0.08` appears twice: `paste(_:store:previousApp:)` and `pasteString(_:previousApp:)`.
  Four sites, two values. The intended grouping is unaffected and the doc's own reviewer note
  ("`pasteInPlace` and `pasteStringInPlace` are the same case") confirms it, so all four were replaced.
- Both `0.05` sites are genuinely the same case — a direct `postToPid` with no activation to wait on — so
  they share one constant, which is the branch the phase's implementation boundaries call correct.

---

## Deviations from the phase document

- **Four call sites replaced, not three**, for the reason above. This is the phase document being wrong
  about the codebase, not a widened scope: no file, function or value outside the brief was touched.
- **Commit size is +10/−4 against an expected +6/−3.** The difference is the fourth call site plus the
  blank line separating the two constant declarations. Well inside review.md §1's ~2× tolerance.

---

## Follow-up work

| Observation                                                                      | Where                                       | Suggested phase   |
| -------------------------------------------------------------------------------- | ------------------------------------------- | ----------------- |
| Phase doc's literal count and expected commit size are both off by one call site | `phases/03-named-paste-timing-constants.md` | doc fix, no phase |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes — one file, two constants, no persistence and no state.
- **Dependent phases that must also be reverted:** none
- **Data risk on revert:** none — nothing is persisted by this phase.

---

## Sign-off

- [x] All acceptance criteria met
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
