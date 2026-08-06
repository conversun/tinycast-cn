# Phase 31 — `AppEntry.Kind` exhaustiveness and `KindDescriptor`

**Milestone:** M6 · **Effort:** M · **Risk:** Med · **Context:** Med

> **Compatibility policy applies.** See [`../POLICY.md`](../POLICY.md). `Kind` raw values may be renamed; carve-out 2
> (every producer and consumer moves together) is what applies.

---

## Overview

Make every `AppEntry.Kind` switch exhaustive so the compiler enforces the recipe `AGENTS.md` currently
enforces by prose, then collapse the per-kind metadata into one table.

## Why this phase exists

`Kind` is switched on in nine places. Five are exhaustive; four use `default:`, which means adding a
launcher category silently does the wrong thing in those four rather than failing to build.

`AGENTS.md` already documents the recipe — "a new category means a new case, a slice in
`AppIndex.publishEntries()`, and the matching filter in `LauncherList.rows`, in that same order" — which
is an honest admission that the cost is real and manual.

## Architecture Review reference

**H-6**

## Objectives

1. Replace every `default:` in a `Kind` switch with explicit cases.
2. Collapse the per-kind metadata into a single `KindDescriptor` returned by one switch.
3. Leave `Kind` itself, and every existing behaviour, unchanged.

## The nine switch sites

| Location                                                    | Currently                           |
| ----------------------------------------------------------- | ----------------------------------- |
| `AppEntry.kindLabel`                                        | exhaustive                          |
| `AppEntry.hotKeyAction`                                     | exhaustive                          |
| `AppEntry.canRevealInFinder`                                | expression                          |
| `AppEntry.isSymbolIcon`                                     | expression                          |
| `AppEntry.symbolIconName`                                   | exhaustive                          |
| `AppCore` / coordinator `launch`                            | exhaustive                          |
| `LauncherList.rows` section table                           | **`filter` per kind, not a switch** |
| `AppActionsMenu.openTitle`                                  | exhaustive                          |
| `LauncherScreen.primaryActionTitle` (was `actionPillLabel`) | **`default:`**                      |

## Expected files to modify

| File                                        | Change                                              |
| ------------------------------------------- | --------------------------------------------------- |
| `Features/Launcher/Model/AppEntry.swift`    | Add `KindDescriptor`; fold five members into it.    |
| `Features/Launcher/UI/LauncherScreen.swift` | `default:` → explicit cases.                        |
| `Features/Launcher/UI/AppActionsMenu.swift` | Reads the descriptor.                               |
| `Features/Launcher/UI/LauncherList.swift`   | Section table reads the descriptor's section title. |

## Files that must NOT change

- `AppIndex.publishEntries()` — the slice order is the invariant `LauncherList.rows` mirrors. It stays.
- Any store
- Any other screen

## Implementation boundaries

- **`AppEntry.Kind`'s cases do not change.** Raw values _may_ be renamed under
  [`POLICY.md`](../POLICY.md), but they are persisted in `VisibilityStore.hiddenKinds`, so a rename must
  move the writer and the reader together. There is no reason to rename them in this phase — leave them.
- `KindDescriptor` is a **plain struct returned by one `switch`**, held as a `static let` table or
  computed per access — whichever is simpler. It is not a protocol, not a registry, not generic.
- Its members are exactly the five things currently derived per kind:
  `label`, `sectionTitle`, `openVerb`, `canRevealInFinder`, `isSymbolIcon`.
  `symbolIconName` stays a separate switch — it consults three catalogs and a per-entry override, which
  does not belong in a static table.
- **The section table stays a literal array in `LauncherList.rows`**, in the same order, with the same
  titles. It may read `sectionTitle` from the descriptor, but the _order_ stays hand-written — it must
  mirror `AppIndex.publishEntries`'s slice order and that relationship is clearer stated once than
  derived.
- The existing explicit type annotation on the section array must stay. It is there because inference
  times out on it, and the Release build is the gate that proves it.
- Do not add a `Kind` case. Do not remove one.
- Every string stays character-identical: "Application", "System Setting", "Open Application",
  "Run Custom Command", section titles, everything.

## Detailed acceptance criteria

1. `grep -n "default:" ` across the four launcher files returns no `Kind` switch.
2. Adding a hypothetical `Kind` case produces a **compile error** in every site that must be updated —
   verify by adding a scratch case, building, counting the errors, then reverting.
3. `KindDescriptor` exists with exactly the five listed members.
4. Every kind's label, section title and open verb is character-identical to before.
5. The launcher's section order is unchanged.
6. `VisibilityStore.hiddenKinds` still round-trips within this build.
7. Release build succeeds — the section-array annotation still holds.

## Manual verification checklist

- [ ] `checklists/build.md` including the **Release build**
- [ ] `checklists/testing.md` — `fuzz-test`, `ranking-test`, `palette-selection-test`
- [ ] `checklists/regression.md` — Core sweep + **Launcher & icons** + **Settings & backup**
- [ ] **The scratch-case test:** add `case scratch` to `Kind`, build, confirm errors appear at every site
      the recipe names, then `git checkout` the file. Record the error count.
- [ ] Empty-query launcher, fully scrolled → section order and titles identical to a pre-phase screenshot
- [ ] Each kind's row shows the correct trailing label ("Application", "Command", "Quicklink", …)
- [ ] Each kind's footer pill shows the correct verb ("Open Application", "Run System Action", …)
- [ ] Each kind's Actions menu shows the correct first row title
- [ ] Hide a category in Settings, quit, relaunch → it is still hidden (raw values intact)
- [ ] ⌘↵ reveals only for application / system setting / snippet

## Regression risks

| Risk                                                                           | Mitigation                            |
| ------------------------------------------------------------------------------ | ------------------------------------- |
| A label or verb changes while being moved into the table                       | AC4 — compare all eight kinds by hand |
| Section order changes                                                          | AC5 screenshot                        |
| `Kind` raw values change on one side only → hidden categories silently un-hide | AC6 + the relaunch test               |
| The descriptor absorbs `symbolIconName` and the catalogs get flattened into it | Boundary — it stays separate          |
| The section array loses its type annotation → Release type-check timeout       | AC7                                   |

## Rollback strategy

`git revert <sha>`. No data risk under [`POLICY.md`](../POLICY.md).

## Expected commit size

4 files, +90 / −110 lines.

## Suggested commit message

```
Make every AppEntry.Kind switch exhaustive

Four sites used `default:`, so adding a launcher category silently did
the wrong thing in each rather than failing to build. The per-kind label,
section title, open verb and reveal/symbol flags collapse into one
KindDescriptor; symbolIconName stays separate because it consults three
catalogs. The section order stays hand-written to mirror AppIndex's slice
order. Strings unchanged.
```

## Dependencies

**Phase 29 (hard).**

## Definition of Done

- All acceptance criteria met
- The scratch-case test performed and its error count recorded
- Section screenshot compared
- Merged

## Estimated difficulty

**Medium.**

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Do the scratch-case test yourself.** It is the only proof the phase achieved its actual goal, it
  takes two minutes, and the count of resulting errors tells you whether the recipe is now
  compiler-enforced or merely tidier.
- Compare all eight kinds' three strings against the pre-phase code. A table refactor is exactly where a
  string quietly changes case or loses a word.
- Confirm the section array kept its explicit type annotation — its absence is a Release-only failure
  and Debug will not catch it.
- If `KindDescriptor` grew a sixth or seventh member, ask what it absorbed and whether that thing is
  genuinely static per kind.
