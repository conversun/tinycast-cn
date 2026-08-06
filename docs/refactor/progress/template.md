# Phase NN — <title>

> Copy this file to `docs/refactor/progress/NN-<slug>.md` when you start the phase.
> Commit it **in the same commit as the work**. A progress note that lands separately gets forgotten.

---

## Status

| Field                         | Value                                                     |
| ----------------------------- | --------------------------------------------------------- |
| **Status**                    | Not started / In progress / Complete / Blocked / Reverted |
| **Started**                   | YYYY-MM-DD                                                |
| **Completed**                 | YYYY-MM-DD                                                |
| **Operator**                  |                                                           |
| **Branch**                    | `refactor/NN-<slug>`                                      |
| **Commit**                    | `<sha>`                                                   |
| **Claude conversations used** | 1                                                         |
| **Actual effort**             | Nh vs. estimate of Nh                                     |

---

## Completed tasks

Tick each objective from the phase document.

- [ ] Objective 1 — <as written in the phase doc>
- [ ] Objective 2
- [ ] Objective 3

## Acceptance criteria

- [ ] AC1 — <criterion> — verified by: <how>
- [ ] AC2 —
- [ ] AC3 —

---

## Verification

| Checklist                  | Result      | Notes                |
| -------------------------- | ----------- | -------------------- |
| `checklists/build.md`      | PASS / FAIL |                      |
| `checklists/testing.md`    | PASS / FAIL | Harnesses run:       |
| `checklists/regression.md` | PASS / FAIL | Sections run: Core + |
| `checklists/review.md`     | PASS / FAIL |                      |

### Measurements

Only for phases that claim a performance or size effect.

| Metric                     | Before | After          | Δ   |
| -------------------------- | ------ | -------------- | --- |
| Binary size (Release)      |        |                |     |
| Clean install verified?    | —      | yes / no / n-a |     |
| Cold launch, median of 3   |        |                |     |
| RSS after 10 palette opens |        |                |     |
| Phase-specific signpost    |        |                |     |

---

## Failed tasks

Anything attempted and abandoned. Empty is a valid answer — say "none" rather than deleting the section.

| What | Why it failed | Decision                                    |
| ---- | ------------- | ------------------------------------------- |
|      |               | Deferred to phase NN / Dropped / Re-planned |

---

## Issues encountered

Free text. Things that surprised you, cost time, or that the next engineer would want to know. Be
specific — "it was fiddly" helps nobody.

-

---

## Deviations from the phase document

Anything done differently from the spec, and why. If there are none, say so explicitly — an empty
section reads as "not filled in".

-

---

## Follow-up work

Out-of-scope issues Claude reported, or that you noticed during review. Do **not** fix them here.

| Observation | Where | Suggested phase |
| ----------- | ----- | --------------- |
|             |       |                 |

---

## Rollback notes

Fill this in **before** you need it.

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes / No — if no, explain what else must be undone
- **Dependent phases that must also be reverted:** <from `ROADMAP.md`, or "none">
- **Data risk on revert:** none — local data is disposable under `POLICY.md`. If the revert leaves stale
  data behind, wipe the Dev channel and relaunch.

---

## Sign-off

- [ ] All acceptance criteria met
- [ ] All four checklists passed
- [ ] `ROADMAP.md` status table updated
- [ ] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [ ] **Stopped.** Next phase is a separate session.
