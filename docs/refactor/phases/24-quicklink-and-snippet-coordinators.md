# Phase 24 — `QuicklinkCoordinator` and `SnippetExpansionCoordinator`

**Milestone:** M4 · **Effort:** L · **Risk:** Med · **Context:** High

---

## Overview

Move the two largest orchestration blocks out of `AppCore` — ~185 lines of quicklink flow and ~160 lines
of snippet expansion — into coordinators that take their collaborators in `init`.

## Why this phase exists

`AppCore` is 1,348 lines doing thirteen jobs. These two are the biggest, the most tangled, and the most
clearly separable: both are multi-step flows over a fixed set of collaborators, and neither is reachable
by any harness today because `AppCore` imports AppKit and SwiftUI.

## Architecture Review reference

**C-1** · Roadmap W5.1–W5.2

## Objectives

1. Add `QuicklinkCoordinator`: open flow, argument submit/cancel, CRUD, import/export, failure recovery,
   presence reconciliation.
2. Add `SnippetExpansionCoordinator`: `expandSnippet`, `promptSnippetArguments`,
   `completeSnippetExpansion`, `clipboardHistoryForExpansion`, listener start.
3. `AppCore` constructs both, exposes them, and retains thin forwarding methods for existing call sites.

## Expected files to modify

| File                                                           | Change                                           |
| -------------------------------------------------------------- | ------------------------------------------------ |
| `Tinycast/Features/Quicklinks/QuicklinkCoordinator.swift`      | **New.** ~200 lines moved.                       |
| `Tinycast/Features/Snippets/SnippetExpansionCoordinator.swift` | **New.** ~170 lines moved.                       |
| `Tinycast/Core/AppCore.swift`                                  | −345 lines of body, +2 properties, + forwarders. |

## Files that must NOT change

- `Tinycast/Core/Quicklinks/*` — the store, launcher, destination, archive and argument session
- `Tinycast/Core/Snippets/*` — the store, repository, template engine, listener, injector, policies
- `Tinycast/Core/Dialog/*`, `Tinycast/Core/HUD/*`
- Any view file — the forwarders exist precisely so views need no change in this phase

## Implementation boundaries

- **Coordinators take collaborators in `init`, never `AppCore.shared`.** That is the whole point: it is
  the first orchestration code in the app a harness could conceivably reach.
- **Code moves verbatim.** No logic changes, no reordering, no "while I'm here". Verify with
  `git diff -M`.
- The **funnel invariant** must survive: `openQuicklink` remains the one path for palette activation, the
  ⌘K menu and the global shortcut, so neither the feature switch nor the argument prompt can be
  bypassed. Same for `expandSnippet`.
- **Ordering that must not change:**
  - `openQuicklink`: feature-switch guard → resolve target app → decide encoding → capture context →
    selection fallback → expand → if arguments remain, begin the session and show the prompt → else open.
  - `expandSnippet`: the interactive path gates with `prepareInteractiveExpansion` **before** the
    argument prompt; the automatic path was already gated by `beginAutomaticExpansion` and must not be
    re-gated.
- `pendingQuicklinkForcesDefaultApp` moves with the quicklink flow. It carries the menu's default-app
  override across the argument prompt.
- `Self.selectionArgument` and `Self.clipboardHistoryDepth` move with their respective coordinators.
- Dialog and HUD presentation still route through `AppCore.showNotice` / `confirm` / the message HUD —
  `DialogController` stays single-owned by `AppCore`. Pass a small closure or an `AppCore` reference for
  presentation only; do **not** give a coordinator its own `DialogController`.
- Keep `AppCore`'s public method names as forwarders (`openQuicklink`, `submitQuicklinkArgument`,
  `deleteQuicklink`, …). Phase 32 deletes them once call sites move.
- Presence reconciliation (`applyQuicklinksPresence`, `applySnippetsLauncherPresence`,
  `applySnippetsEnabled`) moves too — but the `withObservationTracking` registration from phase 18 stays
  in `AppCore.start()` and calls into the coordinator.

## Detailed acceptance criteria

1. Both coordinators exist, are `@MainActor`, and reference no `AppCore.shared`.
2. `AppCore.swift` drops by ~345 lines.
3. `git diff -M` shows the moved bodies as renames/moves, not rewrites.
4. Every quicklink entry point still works: palette ↵, Actions menu, global shortcut, ⌘K "Open with
   Default", the Quicklinks command.
5. Every snippet entry point still works: palette activation, keyword expansion, argument prompt.
6. The feature switches still gate both — a registered shortcut with the feature off does nothing.
7. Deleting a quicklink still unwinds its hotkey, favourite, visibility and ranking references.
8. Failure recovery still offers "Open with Default" when the handler app is missing.

## Manual verification checklist

- [ ] `checklists/build.md` including **startup timing**
- [ ] `checklists/testing.md` — `quicklink-test`, `snippets-test`
- [ ] `checklists/regression.md` — Core sweep + **Quicklinks** + **Snippets** in full
- [ ] Open a quicklink from the launcher, from its Actions menu, and from a global shortcut
- [ ] Turn quicklinks **off**, press a bound quicklink shortcut → nothing opens
- [ ] A quicklink with two arguments → prompt flow works end to end
- [ ] A quicklink using `{selection}` with no selection → the configured fallback applies
- [ ] Set an "open with" app, uninstall/rename that app, open the quicklink → failure dialog offers
      "Open with Default", and taking it works
- [ ] Delete a quicklink that has a shortcut, is a favourite and is hidden → all three references clear
- [ ] Import and export quicklinks
- [ ] Expand a snippet by keyword; expand one from the launcher
- [ ] A snippet with `{argument}` → prompt → delivery
- [ ] Turn snippets off → keyword expansion stops, launcher entries disappear, the tap tears down
- [ ] Turn them back on → everything returns without a new permission prompt

## Regression risks

| Risk                                                                                                       | Mitigation                                            |
| ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **A funnel is bypassed** — e.g. the shortcut path no longer checks the feature switch                      | AC6 + the "feature off, press shortcut" test          |
| The snippet gating order flips and the interactive path prompts before checking the target                 | Boundary spells out the order; AC5                    |
| `pendingQuicklinkForcesDefaultApp` is left behind and ⌘K "Open with Default" stops working across a prompt | Test that exact combination                           |
| A coordinator acquires its own `DialogController`, so a held hotkey can stack dialogs                      | Boundary + `grep -c "DialogController()"` must stay 1 |
| Reference cleanup on delete is partially moved                                                             | AC7                                                   |

## Rollback strategy

`git revert <sha>`. No persisted state changes shape.

## Expected commit size

3 files, +390 / −350 lines. `AppCore` net −345.

## Suggested commit message

```
Extract QuicklinkCoordinator and SnippetExpansionCoordinator

The two largest orchestration blocks in AppCore, ~345 lines together.
Both take their collaborators in init rather than reaching AppCore.shared,
which makes them the first orchestration code a harness could reach.
AppCore keeps thin forwarders so no view changes yet. Bodies moved
verbatim; the open/expand funnels and their gating order are unchanged.
```

## Dependencies

**Phase 23 (hard).** Blocks 25.

## Definition of Done

- All acceptance criteria met
- Every entry point for both features exercised by hand
- `git diff -M` confirms moves rather than rewrites
- Merged

## Estimated difficulty

**High** by volume; medium by concept.

## Estimated Claude context usage

**High.**

## Notes for reviewers

- **Use `git diff -M50%` and read what it calls a rewrite.** Anything not recognised as a move deserves
  line-by-line attention.
- `grep -rn "AppCore.shared" Tinycast/Features/Quicklinks Tinycast/Features/Snippets` must return
  nothing in the two new files.
- `grep -c "DialogController()" Tinycast` must be 1.
- The single most valuable manual test: turn a feature **off** and press its still-registered global
  shortcut. That is the funnel invariant, and it is the thing a refactor of this shape most easily
  breaks.
