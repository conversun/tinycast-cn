# Phase 24 kickoff — `QuicklinkCoordinator` and `SnippetExpansionCoordinator`

Read `docs/refactor/phases/24-quicklink-and-snippet-coordinators.md` completely.

## Task

Move the two largest orchestration blocks out of `AppCore` — ~185 lines of quicklink flow and ~160 lines
of snippet expansion — into coordinators.

## Hard gates

- **Coordinators take their collaborators in `init`, never `AppCore.shared`.** That is the point: it is
  the first orchestration code in the app a harness could conceivably reach.
  `grep -rn "AppCore.shared"` in the two new files must be empty.
- **Code moves verbatim.** No logic changes, no reordering. `git diff -M` should recognise the bodies as
  moves.
- **The funnel invariant survives:** `openQuicklink` remains the one path for palette activation, the ⌘K
  menu and the global shortcut, so neither the feature switch nor the argument prompt can be bypassed.
  Same for `expandSnippet`.
- **Ordering that must not change:**
  - `openQuicklink`: feature-switch guard → resolve target app → decide encoding → capture context →
    selection fallback → expand → if arguments remain, begin the session and show the prompt → else open.
  - `expandSnippet`: the **interactive** path gates with `prepareInteractiveExpansion` _before_ the
    argument prompt; the **automatic** path was already gated by `beginAutomaticExpansion` and must not
    be re-gated.
- `pendingQuicklinkForcesDefaultApp` moves with the quicklink flow — it carries the menu's default-app
  override across the argument prompt.
- **`DialogController` stays single-owned by `AppCore`.** Coordinators present through
  `AppCore.showNotice` / `confirm` / the message HUD. `grep -c "DialogController()" Tinycast` must stay 1.
  Giving a coordinator its own controller re-enables hotkey dialog stacking.
- **Keep `AppCore`'s public method names as thin forwarders.** Phase 32 deletes them. No view changes here.
- The `withObservationTracking` registrations stay in `AppCore.start()` and call into the coordinator.
- Do not touch anything under `Core/Quicklinks/`, `Core/Snippets/`, `Core/Dialog/` or `Core/HUD/`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -c "DialogController()" Tinycast -r      # must be 1
git diff -M50%                                 # read anything it calls a rewrite
```

Run `quicklink-test` and `snippets-test`.

**Then run the app and do this one test:** turn quicklinks **off**, press a bound quicklink shortcut.
Nothing must open. That is the funnel invariant, and it is what a refactor of this shape breaks.

## Summarise

Use the system-prompt format. State `AppCore`'s line count before and after, and confirm the two
gating orders above are unchanged.
