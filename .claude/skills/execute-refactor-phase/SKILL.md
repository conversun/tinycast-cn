---
name: execute-refactor-phase
description: Implement one phase of the Tinycast architecture refactor in docs/refactor/. Use this whenever the user asks to run, start, execute, continue or implement a refactor phase ("execute refactor phase 07", "do the next phase", "start phase 12", "which phase is next?") — even if they only give a bare number in a refactor context. It resolves the phase from ROADMAP.md and its dependencies, reads system-prompt.md → prompts/phase-NN.md → the phase document in that order, presents a plan for approval, then implements strictly inside the phase boundaries. It never commits, merges, or touches progress files — verify-and-record-phase does that afterwards.
---

# Execute a refactor phase

This covers step 3 of [`docs/refactor/DAILY.md`](../../../docs/refactor/DAILY.md) — implementation
only. Verification and recording are a separate skill (`verify-and-record-phase`) because a phase that
records itself as done before the checklists run is how a broken phase gets marked `Complete`.

The refactor documents are the specification. This skill sequences them and enforces the boundaries;
it never restates their content, because a duplicated spec drifts and then nobody can tell which copy
is authoritative.

## 1 · Resolve the phase

If the user named a number, use it. Otherwise read the **Status tracking** table at the bottom of
`docs/refactor/ROADMAP.md` and take the lowest phase that is `Not started` **and** whose `Depends on`
entries (from the phase table above it) are all `Complete`.

The dependency column is not advisory. If the lowest `Not started` phase is blocked by a dependency
that is `In progress`, `Blocked` or missing, say so and stop — do not quietly skip to a phase further
down the table. Offer the eligible alternatives and let the operator choose.

State the resolution in one line before doing anything else: phase number, title, dependencies and
their status.

## 2 · Preflight

- `git status --short` must be clean. Uncommitted work makes the whole verification stage useless,
  because every review step reads the working diff. If it is dirty, report what is there and ask.
- The expected branch is `refactor/NN-<slug>`, where `<slug>` matches the phase document's filename.
  If the branch does not exist, say so and offer to create it — do not create or switch branches
  without a yes.
- If the operator has not built yet this session, offer a pre-phase Debug build. `checklists/build.md`
  scores "zero **new** warnings" against a baseline, and without one that check cannot be made later.

## 3 · Read, in this order

1. `docs/refactor/prompts/system-prompt.md` — the standing contract. Its precedence ladder, its
   forbidden list and its required summary format govern everything below.
2. `docs/refactor/prompts/phase-NN.md` — the kickoff, which carries the hard gates.
3. The phase document it points at, `docs/refactor/phases/NN-*.md`, **completely**, before editing.
4. Every file in that document's **Expected files to modify**.

Read `docs/refactor/POLICY.md` as well when the phase touches storage — meaning it names
`UserDefaults`, `@AppStorage`, SQLite, an Application Support or Caches path, a persisted or exported
format, or the phase number appears in the **Clean install** list in `checklists/regression.md`.
POLICY outranks the phase document, but on migration and compatibility questions only.

`AGENTS.md` is already in context and describes the codebase the refactor is deliberately changing, so
contradictions with a phase are expected. Resolve them with the precedence ladder in the system
prompt rather than by judgement: a _structural_ rule a phase contradicts is a rule being changed —
proceed and note it in the summary. A _behavioural_ invariant a phase contradicts means the phase is
wrong — stop and say so.

## 4 · Plan, then stop

Present a short plan — roughly fifteen lines, because the operator is checking scope, not reading a
design doc:

- The phase and its objective in one sentence.
- Each file you will change, with one line on what changes in it.
- Anything ambiguous in the phase document, or any point where it collides with a behavioural
  invariant.

Then wait for explicit approval. "Looks good, but…" is not approval — resolve the "but" first.

If the plan comes out wider than the phase document's **Implementation boundaries**, that is a signal
to re-read the phase, not to ask permission for a bigger change. Under-delivering is re-runnable;
over-delivering gets the whole phase reverted.

## 5 · Implement

Work to the system prompt's required workflow: smallest diff that satisfies the objectives, then
build, then the harness gates the phase names, then delete anything your change orphaned.

Two checks that are cheap and catch the worst outcomes:

- Run `git diff --name-only` before you summarise and compare it against both lists in the phase
  document. If a file from **Files that must NOT change** appears, revert that file and report it.
  There is no partial rescue here — that list exists because those files are off-limits by `AGENTS.md`
  or load-bearing for an invariant.
- Keep to the comment budget: one line, never two consecutive, hard cap 100 characters, and never a
  comment explaining a change you just made. The diff is not the audience.

## 6 · Summarise, then stop

Use the **Required summary format** from the system prompt exactly, and claim nothing you did not
actually run — a false PASS is the single most damaging output here.

Then stop. This skill never runs `git commit`, `git merge` or `git push`, never writes to
`docs/refactor/progress/`, never edits the `ROADMAP.md` status table, and never starts the next phase.
Those are the operator's decisions, and the recording only happens once all four checklists have
passed.
