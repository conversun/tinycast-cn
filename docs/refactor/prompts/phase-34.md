# Phase 34 kickoff — Comment budget, comment pass, final measurement

Read `docs/refactor/phases/34-comment-budget-and-final-measurement.md` completely.

**Work one subsystem per conversation and one subsystem per commit.** A reviewer must be able to read a
pure comment diff.

## Task

Three parts, in this order:

1. Write the six-rule comment budget into `AGENTS.md` — **its own commit, first**.
2. Triage every stacked comment block and every over-cap line, one subsystem per commit.
3. Re-measure the phase-01 baselines and update `docs/architecture.md`.

## Hard gates

- **The budget goes in first, before any source is touched.** It is the durable deliverable; the cleanup
  is not. Without a greppable cap, whatever this pass removes grows straight back.
- **Triage, in this order of preference:**
  1. **Delete** if it restates the code.
  2. **Compress** to one clause under 100 characters if it names a real gotcha.
  3. **Relocate** to the owning `docs/<subsystem>.md`, leaving a one-line pointer, if it is genuinely a
     paragraph of rationale.

  **Relocation is the default for anything explaining an invariant.**

- **Never delete a comment you do not understand.** If its meaning is unclear, relocate it verbatim to
  `docs/`. Losing an explanation is worse than an over-long one.
- **Do not touch code. Not one statement.** If a comment is only necessary because the code is unclear,
  record it under follow-up work; do not fix it here.
- Do not reflow, re-indent or re-wrap anything.
- **Do not open `DesignSystem/Scrolling/EdgeDissolve.swift` or `ThinScrollbar.swift`** — off-limits by
  `AGENTS.md`, including their comments. They have been moved twice in this roadmap and never opened.
- Do not edit `*.generated.swift`.
- Do not edit `docs/architecture-review.md` — it is a fixed artefact.

## Verify before you summarise

Per subsystem commit:

```
git show --stat
git show | grep '^[-+]' | grep -v '^[-+][-+]' | grep -v '^\s*[-+]\s*//'
```

**The second command must return nothing** — that is the proof the commit contains only comment lines.

At the end:

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release CODE_SIGNING_ALLOWED=NO
```

Re-run the four H-1 metrics:

```
# stacked blocks
find Tinycast -name "*.swift" ! -name "*.generated.swift" -exec \
  awk '/^[[:space:]]*\/\//{r++; if(r==2) b++; next} {r=0} END{print b+0}' {} \; | awk '{s+=$1} END {print "stacked:", s}'
# over-cap comment lines
grep -rhE '^\s*(//|///)' Tinycast --include="*.swift" | awk 'length>100' | wc -l
```

Run all 19 harnesses.

## Summarise

Use the system-prompt format, plus:

- the four comment metrics, before and after
- for every **deleted** paragraph of rationale: where that knowledge went
- the complete final measurement table from the phase document, every row filled in — including any
  metric that regressed
