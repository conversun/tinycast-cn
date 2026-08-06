# Daily driver — what to actually do

One page. Keep it open. Full detail is in `README.md`; this is the loop.

**One phase = one fresh conversation = one commit = one merge. Then stop.**

---

## The five steps

### 1 · Find your phase

Open `ROADMAP.md`, look at the status table, take the lowest number that is `Not started` **and whose
dependencies are all `Complete`**. Do not skip ahead — the dependency column is not advisory.

If the phase touches storage, skim [`POLICY.md`](POLICY.md) first. Short version: no migrations, no
legacy support, local data is disposable — but do **not** change what a _fresh install_ starts with.

### 2 · Branch

```bash
git status                      # must be clean
git checkout main && git pull
git checkout -b refactor/05-app-paths
```

### 3 · Start a **new** conversation and say this

In Claude Code, run `/clear` first — a fresh context per phase is part of the method, not an
optimisation.

> Execute refactor phase **05**.
>
> Read in this order: `docs/refactor/prompts/system-prompt.md`, then
> `docs/refactor/prompts/phase-05.md`, then the phase document it points to.
>
> Follow the required workflow in the system prompt. Show me your plan before editing. Stop after the
> summary — do not commit.

Change the two numbers. That is the whole instruction. Everything else is already written down.

### 4 · Verify — do not skip, do not reorder

| Order | Checklist                                                              | Time      |
| ----- | ---------------------------------------------------------------------- | --------- |
| 1     | `checklists/build.md`                                                  | ~3 min    |
| 2     | `checklists/testing.md`                                                | ~2 min    |
| 3     | `checklists/regression.md` — Core sweep + the sections the phase names | ~5–15 min |
| 4     | `checklists/review.md`                                                 | ~10 min   |

Start review with `git diff --stat`. If a file appears that the phase's **Files that must NOT change**
list forbids, stop and revert. That check takes ten seconds and catches the worst outcome.

### 5 · Record, commit, merge, **stop**

```bash
cp docs/refactor/progress/template.md docs/refactor/progress/05-app-paths.md
# fill it in, then:
git add -A
git commit -m "<the suggested commit message from the phase doc>"
```

Update the `ROADMAP.md` status row. Merge. Then genuinely stop — close the conversation and come back
later. Chaining phases in one session is how you lose the ability to bisect a regression three weeks from
now.

---

## The four replies you will actually need

**Plan looks wrong / too broad**

> That is wider than the phase document. Re-read the Implementation boundaries section and give me a
> narrower plan.

**Build failed twice**

> `git reset --hard`, then start over with this error as context: `<paste>`

**Scope creep in the diff**

> `<file>` is on this phase's "must not change" list. Revert it and redo the phase without touching it.

**You do not understand a hunk**

> Explain what `<file>:<lines>` changes about runtime behaviour, and why it was necessary for this phase.

If the explanation does not satisfy you, revert that hunk. "I couldn't follow it but it looked fine" is
how a silent regression ships.

---

## Pace

- **One to two phases per working day.** Your review capacity is the constraint, not Claude's speed.
- **Short on time?** Do a phase from M1 (02–10) — they are small, independent and low risk.
- **Do not start M3, M4 or M5 with under an hour free.** Those chain, and stopping mid-phase costs more
  than not starting.
- Natural stopping points where the codebase is fully coherent: after **10**, **18**, **23**, **26**, **29**.
- Wiping the Dev channel is now normal and supported. Commands are in `POLICY.md`.

---

## Stop the roadmap entirely if

- the build is red
- a regression check failed and you have not root-caused it
- a `Tools/` harness that used to pass now fails
- an M2 phase is unmerged and you are about to start M3, M4 or M5

Fix or revert first. Do not carry a known problem into the next phase.

---

## If something interrupts you

**Claude ran out of context mid-phase** — don't discard the work. Commit to a scratch branch, then start
fresh:

> Objectives 1–3 are already complete on this branch. Verify them, then complete objective 4 only.

If more than half remains, `git reset --hard` and split the phase in two. Amend the phase doc so the next
person inherits the smaller unit.

**You committed, then found a regression** — `git revert <sha>`. Revert, don't fix forward. Every phase
is independently reversible so this stays a one-command decision.

**Branch fell behind main** — `git fetch origin && git rebase origin/main`. Never merge. If the rebase
hurts, the phase took too long.

---

## Once a week

- Confirm `ROADMAP.md`'s status table matches reality
- Skim the **Follow-up work** sections in `progress/` — out-of-scope issues collect there and some will
  deserve their own phase
- Re-run the full harness suite from `docs/development.md`
