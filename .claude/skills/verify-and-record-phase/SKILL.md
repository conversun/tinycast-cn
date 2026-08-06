---
name: verify-and-record-phase
description: Verify a finished Tinycast refactor phase against docs/refactor/checklists/ and then record it. Use this whenever the user asks to verify, check, validate or sign off a refactor phase, to run the refactor checklists, to fill in the progress file, to update the ROADMAP status, or asks whether a phase is ready to commit ("verify phase 05", "run the checklists", "record this phase", "is it ready to merge?"). It runs build.md → testing.md → regression.md → review.md in that exact order, stops at the first failure, and only once every one has passed writes the progress document, updates the ROADMAP row and surfaces the phase's suggested commit message. It never commits, merges, or moves on to the next phase.
---

# Verify and record a refactor phase

This covers steps 4 and 5 of [`docs/refactor/DAILY.md`](../../../docs/refactor/DAILY.md). The order of
the four checklists is fixed and cheap to honour: the build gate is decisive and takes three minutes,
while the review gate is where a scope violation shows up. Reordering them mostly wastes the
operator's time on a phase that was going to be reverted anyway.

## 0 · Identify the phase and read its contract

Take the phase number from the argument, the branch name (`refactor/NN-<slug>`), or the working diff,
and confirm it in one line before running anything.

Then read `docs/refactor/phases/NN-*.md`. Every checklist below is scored against it — **Expected
files to modify**, **Files that must NOT change**, **Detailed acceptance criteria**, **Expected commit
size** and **Suggested commit message** — so verifying without it is just running commands.

## What you can verify, and what you cannot

`build.md` and `testing.md` are commands, so run them and report real output. `regression.md` is a
manual behaviour sweep against a running app, and most of it — focus restoration, the compact↔expanded
swap, whether the glass looks identical — cannot be checked from here. The launch and startup-timing
sections of `build.md` are the same.

Hand those to the operator as a scoped list and wait for their verdict. A checklist claimed as passed
without being run is worse than one skipped, because it lands in the progress file as evidence.

## 1 · `checklists/build.md`

Run `xcodegen generate`, then check `git status` for `.xcodeproj` churn the phase does not justify —
a project diff on a phase that added no files means something unexpected happened. Then the Debug
build, comparing new warnings against the pre-phase baseline; the Release build if section 3's
conditions apply; and the binary size against the 3 MB upto 4MB budget.

Hand sections 5 (launch) and 6 (startup timing, required for phases 05, 06, 09, 10, 16, 17, 18, 24, 25) to the operator.

On failure, report the error text and stop. Two fix attempts is the documented ceiling — beyond that
the README's recovery path is `git reset --hard` and a re-run, not a third try.

## 2 · `checklists/testing.md`

Derive the mandatory harnesses from that file's harness → owning source map against the files this
phase actually touched (`git diff --name-only`), not against what the phase intended to touch. Command
lines are in `docs/development.md` under **Tests**; run the whole suite at the milestone boundaries the
checklist names (phases 10, 18, 23, 26, 29, 33, 34).

Also walk the purity invariant section. A harness that fails to _compile_ rather than failing an
assertion almost always means a pure-layer file gained an `import AppKit` or `import SwiftUI`, and that
is the most likely way a refactor silently breaks the only automated correctness signal in this repo.

A harness that passed before this phase and fails now is a hard stop, with no "fix it next phase".

## 3 · `checklists/regression.md`

Assemble the applicable list: the Core sweep always, plus every scoped section whose phase list
includes this number, plus the Clean install section if this phase is named there — with the wipe
commands, since a fresh-install check against a dirty channel proves nothing.

Present it, wait, and record the operator's verdict as given, including partial results. A failure
they have not root-caused stops the roadmap; do not carry it into the recording step.

## 4 · `checklists/review.md`

Work its sections in order and present findings grouped by section, each with a `file:line`:

- **Scope** first, from `git diff --stat` and `--name-only`. A file from the must-NOT-change list, an
  unnamed new file, or a diff materially over ~2× the expected commit size is a stop, not a note.
- Then behaviour preservation, concurrency, memory, the comment-budget greps, dead and migration code,
  and the project invariants the phase's blast radius could reach.
- Finally check the implementation summary itself: **Behaviour changes** should read `NONE` or list
  only what the phase authorised, and every acceptance criterion should have something checkable
  behind it.

This pass is a first filter, not a substitute — the operator still reads the diff. Say plainly which
sections you checked mechanically and which need their eyes.

## 5 · Record — only once all four have passed

Copy `docs/refactor/progress/template.md` to `docs/refactor/progress/NN-<slug>.md` and fill it in:
status and dates, branch, the objectives and acceptance criteria ticked with _how_ each was verified,
the verification table reflecting what actually ran, measurements for any phase claiming a performance
or size effect, deviations from the phase document, and the follow-up table populated from the
out-of-scope issues in the implementation summary. Write "none" where a section is empty — a blank
section reads as unfilled.

Then update that phase's row in the `ROADMAP.md` status table — status, branch, date, notes — and only
that row.

Finally, present the phase document's **Suggested commit message** verbatim in a fenced block, and
note that the progress file belongs in the same commit as the work: a progress note that lands
separately gets forgotten.

## Never

Do not `git commit`, `git merge`, `git push` or tag, and do not start the next phase — chaining phases
in one session is what destroys the ability to bisect a regression weeks later.

If any checklist fails, do not write the progress file and do not touch `ROADMAP.md`. Report the
failure, and point at the relevant recovery path in `docs/refactor/README.md` — revert, or mark the
phase `Blocked` with a written-up reason.
