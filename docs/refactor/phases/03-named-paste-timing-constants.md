# Phase 03 — Named paste-timing constants

**Milestone:** M1 · **Effort:** S · **Risk:** Low · **Context:** Low

---

## Overview

`Paster` guards a timing-sensitive synthetic-⌘V handshake with three unnamed literals — `0.08`, `0.05`,
`0.05`. Name them. Change nothing else.

## Why this phase exists

These three delays are the most fragile numbers in the app: they compensate for the gap between
`NSRunningApplication.activate()` and the target process being ready to receive a keystroke. An
unlabelled `0.08` is an invitation for a future contributor — human or agent — to "clean it up" into a
`0` or a `0.1` and silently break pasting into slow-to-activate apps.

## Architecture Review reference

**L-7**

## Objectives

1. Introduce two named `private static let` constants on `Paster`:
   - one for the delay after `activate()` before posting ⌘V (`0.08`)
   - one for the delay before a direct `postToPid` with no activation (`0.05`)
2. Replace all three literals with the constants.
3. Give each constant a **single ≤100-character comment** saying what it compensates for.

## Expected files to modify

| File                         | Change                                   |
| ---------------------------- | ---------------------------------------- |
| `Tinycast/Core/Paster.swift` | Two constants; three call sites updated. |

## Files that must NOT change

- Everything else. This is a one-file phase.
- `Tinycast/Core/Snippets/SnippetTextInjector.swift` — it has its own separate timing model. Do **not**
  attempt to unify them; they compensate for different things.

## Implementation boundaries

- **Values are frozen.** `0.08` stays `0.08`. `0.05` stays `0.05`. This phase renames; it does not tune.
- Do not convert `DispatchQueue.main.asyncAfter` to `Task.sleep`. That changes scheduling semantics on a
  path where the current behaviour is known-good.
- Do not merge the two constants into one even though two sites share `0.05` — they are the same value
  by coincidence, not by meaning. Keep them separate only if the two sites genuinely mean different
  things; if both `0.05` sites are the same "direct post" case, one constant is correct.
- Do not add a third constant for a value that does not exist.

## Detailed acceptance criteria

1. No numeric literal remains in a `asyncAfter(deadline:)` call in `Paster.swift`.
2. Constant values are byte-identical to the literals they replace.
3. Each constant carries at most one comment line, ≤100 characters.
4. `SnippetTextInjector` is untouched.
5. Zero behaviour change.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/regression.md` — Core sweep + **Clipboard**
- [ ] Paste text from clipboard history into a **slow-launching** app (Xcode, Photoshop) — lands correctly
- [ ] Paste into a fast app (TextEdit) — lands correctly
- [ ] ⌥↵ paste-in-place: palette stays open, text lands in the background app
- [ ] Paste an emoji from the emoji grid — lands correctly
- [ ] Paste an image from clipboard history — lands correctly

## Regression risks

| Risk                                                          | Mitigation                                        |
| ------------------------------------------------------------- | ------------------------------------------------- |
| A value is transcribed wrong (0.08 → 0.8)                     | AC2; and the manual paste tests will hang visibly |
| The two 0.05 sites get merged when they mean different things | Boundary note; reviewer reads both call sites     |
| Someone "improves" the delay while renaming                   | AC2 and reviewer diff check                       |

## Rollback strategy

`git revert <sha>`. One file, no state.

## Expected commit size

1 file, +6 / −3 lines.

## Suggested commit message

```
Name Paster's synthetic-⌘V timing constants

The three literals guard the gap between activating the target app and
posting the keystroke. Values unchanged.
```

## Dependencies

Phase 01.

## Definition of Done

- All acceptance criteria met
- Paste verified into both a fast and a slow-activating app
- Merged

## Estimated difficulty

**Low.**

## Estimated Claude context usage

**Low.**

## Notes for reviewers

- Read the two `0.05` sites carefully before accepting one shared constant. `pasteInPlace` and
  `pasteStringInPlace` are the same case; if a third site differs, it needs its own name.
- This is the kind of phase where a model wants to be helpful and "modernise" `asyncAfter` to
  `Task.sleep`. Reject it — the ordering guarantees are not identical and the current form is proven.
