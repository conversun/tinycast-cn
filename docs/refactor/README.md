# Tinycast Refactor — Execution Playbook

This directory turns [`docs/architecture-review.md`](../architecture-review.md) into something you can
execute one small step at a time, mostly by driving Claude Code, without ever leaving the repository in
a half-finished state.

The architecture review says **what** is wrong and **why**. This playbook says **in what order**,
**with what boundaries**, and **how you know a step is actually done**.

> **The review is the source of truth for rationale. Do not edit it.**
> If a phase here contradicts the review, the review wins and the phase is wrong — fix the phase.

---

## What is in here

> **Just want to get going?** [`DAILY.md`](DAILY.md) is the one-page loop. Read this file once, then work
> from that.
>
> **Before any phase touching storage, read [`POLICY.md`](POLICY.md).** It sets the migration and
> compatibility rules and it overrides every other document here.

| Path                       | Purpose                                                                                                                 |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `README.md`                | This file. How to run the roadmap.                                                                                      |
| `DAILY.md`                 | The daily driver — five steps, the exact instruction to give Claude, the four replies you need.                         |
| `POLICY.md`                | **Authoritative.** Migration and compatibility rules; overrides the phases, the checklists, the review and `AGENTS.md`. |
| `ROADMAP.md`               | Execution order, dependency graph, effort, risk, milestones.                                                            |
| `phases/NN-*.md`           | One file per phase. The complete specification of a single unit of work.                                                |
| `prompts/system-prompt.md` | The standing contract handed to Claude on **every** phase.                                                              |
| `prompts/phase-NN.md`      | The per-phase kickoff prompt. Short by design — see below.                                                              |
| `checklists/build.md`      | Build verification. Run after every phase.                                                                              |
| `checklists/regression.md` | Manual behaviour sweep. Run after every phase.                                                                          |
| `checklists/review.md`     | How to review Claude's diff before committing.                                                                          |
| `checklists/testing.md`    | The `Tools/` harnesses and when each is mandatory.                                                                      |
| `progress/template.md`     | Copy per phase into `progress/NN-<slug>.md`.                                                                            |

### Why the phase prompts are short

`prompts/phase-NN.md` does **not** duplicate the phase specification. It points at
`phases/NN-*.md` and carries only the hard gates. This is deliberate: a duplicated spec drifts, and a
drifted spec is worse than no spec because the operator cannot tell which copy is authoritative. One
place to edit, one place to read.

---

## The 37 phases at a glance

Nine milestones' worth of work, sequenced so that **stopping after any completed phase leaves a
shippable app**. See `ROADMAP.md` for the dependency graph.

| Milestone | Phases | Theme                                                                     |
| --------- | ------ | ------------------------------------------------------------------------- |
| **M0**    | 01     | Baselines — measure before changing anything                              |
| **M1**    | 02–10  | Zero-risk performance and hygiene wins                                    |
| **M2**    | 11–18b | Observation (`@Observable`) migration                                     |
| **M3**    | 19–23  | Palette decomposition (`PaletteScreen`)                                   |
| **M4**    | 24–26  | `AppCore` decomposition into coordinators (includes 25b)                  |
| **M5**    | 27–29  | Folder restructure                                                        |
| **M6**    | 30–33  | Naming, exhaustiveness, harness coverage                                  |
| **M7**    | 34–35  | Comment budget, final measurement, docs, retiring dead compatibility code |

---

## How to execute a phase

Work one phase at a time. One phase = one conversation = one commit.

### 1 · Prepare (you, 5 minutes)

```
git status                 # must be clean
git checkout main && git pull
git checkout -b refactor/NN-<slug>
```

Read `phases/NN-*.md` **yourself**, front to back, before starting Claude. If you cannot summarise the
phase's objective in one sentence, do not start it.

Check `ROADMAP.md`: every phase this one depends on must be **merged**, not just written.

### 2 · Baseline (you, 2 minutes)

Build and launch the app _before_ Claude touches anything. You need to know the app was working when
you started, otherwise you will spend the phase debugging a pre-existing problem.

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug
```

### 3 · Run (Claude, one conversation)

Open a new Claude Code conversation. Paste, in this order:

1. The entire contents of `prompts/system-prompt.md`
2. The entire contents of `prompts/phase-NN.md`

Then let it work. **Do not paste the phase document yourself** — the prompt instructs Claude to read it,
and you want it reading the file on disk so you are both looking at the same text.

### 4 · Verify (you, 10–20 minutes)

In order, and do not skip:

1. `checklists/build.md` — it compiles and launches
2. `checklists/testing.md` — the relevant harnesses pass
3. `checklists/regression.md` — the behaviour sweep for this phase's blast radius
4. `checklists/review.md` — read the diff properly

### 5 · Record and commit

Copy `progress/template.md` to `progress/NN-<slug>.md`, fill it in, then:

```
git add -A
git commit -m "<the suggested commit message from the phase doc>"
```

Commit the progress file **in the same commit** as the work. A progress note that lands separately gets
forgotten.

### 6 · Merge, then stop

Merge to `main`. Then genuinely stop — close the conversation, take a break, come back for the next
phase. The most common way this goes wrong is chaining three phases in one session and losing the
ability to bisect when something breaks a week later.

---

## When NOT to continue to the next phase

Stop the roadmap — do not start the next phase — if any of these are true:

- **The build is red.** Obvious, but it gets rationalised away as "I'll fix it in the next phase."
- **A regression checklist item failed and you have not root-caused it.** A behaviour change you cannot
  explain is a behaviour change you cannot preserve.
- **The diff is materially larger than the phase's "Expected commit size."** More than ~2× is a signal
  that Claude expanded scope. Revert and re-run with tighter constraints rather than reviewing 900 lines
  you did not ask for.
- **Claude modified a file in the phase's "Files that must NOT change" list.** Revert. No exceptions —
  that list exists because those files are either off-limits by `AGENTS.md` or load-bearing for an
  invariant.
- **You do not understand a hunk of the diff.** Ask Claude to explain it in the same conversation. If the
  explanation does not satisfy you, revert the hunk.
- **A `Tools/` harness that used to pass now fails.** The harnesses are the only automated correctness
  signal in this repo. Treat a red harness as a hard stop.
- **You are about to start an M3, M4 or M5 phase and an M2 phase is unmerged.** These milestones assume
  the previous one landed completely. Half-migrated observation state plus a palette split is a bad
  afternoon.

---

## Recovering from an interrupted phase

### Claude ran out of context mid-phase

1. `git stash` or commit to a scratch branch — **do not throw the work away yet**.
2. Open the phase doc. Determine which objectives are complete.
3. Start a fresh conversation with the system prompt + phase prompt, and add:
   _"Objectives 1–3 are already complete on this branch. Verify them, then complete objective 4 only."_
4. If more than half the phase remains, prefer `git reset --hard` and split the phase in two — amend the
   phase doc to record the split so the next engineer inherits the smaller unit.

### Claude produced a broken build it cannot fix

Give it two attempts. If the second fails:

```
git reset --hard HEAD
```

Then re-run with the failing error pasted into the prompt as additional context. If it fails a third
time, the phase is mis-specified. Write up what went wrong in `progress/NN-<slug>.md` under **Issues
encountered**, mark the phase **Blocked** in `ROADMAP.md`, and move to the next independent phase.

### You committed, then found a regression

```
git revert <commit>
```

Revert, do not fix forward. Every phase is designed to be independently reversible precisely so that
this is a one-command decision rather than a debugging session. Record the revert in the progress file
and re-plan the phase.

### The branch has drifted behind `main`

Rebase, never merge:

```
git fetch origin && git rebase origin/main
```

Phase branches are short-lived by construction. If a rebase is painful, the phase took too long.

---

## How to review Claude's work

Full checklist in `checklists/review.md`. The three questions that catch the most:

1. **Did anything change that the phase did not ask to change?** `git diff --stat` first, always. Scope
   creep is the dominant failure mode and it is visible in the file list before you read a line of code.
2. **Did behaviour change, or only structure?** Almost every phase here is a pure restructuring. If a
   diff contains a new condition, a changed comparison, a reordered statement with side effects, or a
   different default value, that is either a bug or an undocumented decision. Both need explaining.
3. **Did comments grow?** Per H-1 in the review, this codebase's comment volume is a tracked problem. A
   refactor that adds explanatory prose to justify itself has made the codebase worse even if the code
   is better. See the comment budget in `prompts/system-prompt.md`.

---

## Invariants that outrank this playbook

These come from `AGENTS.md` and hold in every phase without being restated:

- `EdgeDissolve.swift` and `ThinScrollbar.swift` are **off-limits**. Phase 27 moves the files; nothing
  ever edits their contents.
- The flat `selection` index must match visible row order exactly, calculator card included.
- `PaletteWindowController` solely owns the palette frame; `sizingOptions = []` stays.
- The app is locked to `.darkAqua`. No light-mode styling, ever.
- The pure-layer files listed in `AGENTS.md` stay Foundation-only so their `Tools/` harness still
  compiles them.
- Uninstall moves to the Trash and never deletes; `removeItem` must never appear in that feature.
- Every networked feature ships off and is consent-gated.
- Consent flags live on their owning store, never in `AppSettings`.

If a phase appears to require breaking one of these, **the phase is wrong**. Stop and re-plan.

**Superseded by [`POLICY.md`](POLICY.md):** `AGENTS.md`'s clauses about the legacy
`KeyboardShortcuts_<name>` keys and `HotKeyBinding`'s `Codable` compatibility seam no longer apply —
there are no existing users to stay compatible with. Phase 35 removes them and amends `AGENTS.md`.
