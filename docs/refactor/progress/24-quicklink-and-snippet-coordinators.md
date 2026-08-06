# Phase 24 — `QuicklinkCoordinator` and `SnippetExpansionCoordinator`

---

## Status

| Field                         | Value                                                  |
| ----------------------------- | ------------------------------------------------------ |
| **Status**                    | Complete                                               |
| **Started**                   | 2026-08-05                                             |
| **Completed**                 | 2026-08-05                                             |
| **Operator**                  | abue-ammar                                             |
| **Branch**                    | `refactor/24-quicklink-and-snippet-coordinators`       |
| **Commit**                    | single commit on the branch                            |
| **Claude conversations used** | 1                                                      |
| **Actual effort**             | ~35 min vs. estimate of L (4–8 h)                      |

---

## Completed tasks

- [x] Objective 1 — `QuicklinkCoordinator`: open flow, argument submit/cancel, CRUD, import/export,
      failure recovery, presence reconciliation
- [x] Objective 2 — `SnippetExpansionCoordinator`: `expandSnippet`, `promptSnippetArguments`,
      `completeSnippetExpansion`, `clipboardHistoryForExpansion`, listener start
- [x] Objective 3 — `AppCore` constructs both, exposes them, retains thin forwarders for every call site

## Acceptance criteria

- [x] AC1 — both coordinators exist, are `@MainActor`, reference no `AppCore.shared` — verified by:
      `grep -rn "AppCore.shared"` over both new files returns nothing
- [x] AC2 — `AppCore.swift` drops by ~345 lines — verified by: 1342 → 1021, **−321 net**. Exactly 345
      lines of body left; ~24 returned as the 13 forwarders and the 2 new façade methods
- [x] AC3 — moved bodies are moves, not rewrites — verified by **direct body diff**, not by heuristic.
      See *How AC3 was actually verified* below
- [~] AC4 — every quicklink entry point works (palette ↵, Actions menu, global shortcut, ⌘K "Open with
      Default", the Quicklinks command) — **structural**; all four reach the one `openQuicklink`
- [~] AC5 — every snippet entry point works (palette activation, keyword expansion, argument prompt) —
      **structural**; the gating order is byte-identical, but nothing was exercised by hand
- [~] AC6 — the feature switches still gate; a registered shortcut with the feature off does nothing —
      **structural only, and this is the phase's headline gate.** See *What was not verified*
- [x] AC7 — deleting a quicklink unwinds hotkey, favourite, visibility and ranking — verified by:
      `removeQuicklinkReferences` moved intact and is still called from both `deleteQuicklink` and
      `replaceQuicklinks`
- [x] AC8 — failure recovery still offers "Open with Default" — verified by: `presentQuicklinkFailure`
      moved intact, including the `missingApplicationBundleID` branch and the retry through
      `performQuicklinkOpen(forcingDefaultApp: true)`

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                            |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `checklists/build.md`      | PASS   | `xcodegen generate` + **Debug and Release**, both exit 0. **0 compiler warnings against a 0 baseline** measured by a clean Debug build on this branch before any edit. Startup timing **not** measured             |
| `checklists/testing.md`    | PASS   | **All 17 harnesses** via the `## Tests` fence, exit 0, no `FAIL` lines. Both phase gates included — `quicklink-test` and `snippets-test`. `palette-selection-test` 111,684, unchanged (this phase adds no rows)   |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC4, AC5 and AC6 are therefore unexercised**, including the funnel test the phase doc calls "the single most valuable manual test"                                     |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                                                                                                                                  |

### Hard gates

| Gate                                                        | Result                                                     |
| ----------------------------------------------------------- | ---------------------------------------------------------- |
| `grep -rn "AppCore.shared"` in the two new files            | empty                                                      |
| `grep -c "DialogController()" Tinycast`                     | **1** — still `AppCore.swift` alone                        |
| Files from **Files that must NOT change** in the diff       | none — `Core/Quicklinks/`, `Core/Snippets/`, `Core/Dialog/`, `Core/HUD/` and every view file are absent |

### How AC3 was actually verified

`git diff -M` cannot pair these bodies: `AppCore.swift` still exists, so rename detection has nothing
to match. Instead the pre-change blocks were extracted from `HEAD` and diffed line-by-line against the
new files. **Every single difference is a receiver rename or an access-level widening:**

| Old                            | New                     |
| ------------------------------ | ----------------------- |
| `quicklinks.`                  | `store.`                |
| `snippetsStore.`               | `store.`                |
| `snippetTextInjector.`         | `injector.`             |
| `snippetListener.`             | `listener.`             |
| `quicklinkArguments.`          | `argumentSession.`      |
| `launcherRanking.`             | `ranking.`              |
| `clipboardHistoryForExpansion()` (quicklink side) | `clipboardHistory()` |
| `showPalette` / `hidePalette` / `showNotice` / `confirm` / `showSettings` / `pendingQuicklinkEdit` | `core.`-prefixed |
| `dialogs.reportFailure`        | `core.reportFailure`    |
| `messageHUD.show(message:)`    | `core.showMessage(_:)`  |
| `private func`                 | `func` (five members)   |

No condition, no ordering, no string literal and no control-flow shape changed. The two gating orders
the phase names are byte-identical:

- `openQuicklink`: feature-switch guard → resolve target → decide encoding → capture context →
  selection fallback → expand → arguments remain? begin session + prompt : open.
- `expandSnippet`: the interactive path still gates with `prepareInteractiveExpansion` **before** the
  argument prompt (`if automaticGeneration == nil`), and the automatic path is still not re-gated.

### Measurements

| Metric                        | Before  | After   | Δ                                                          |
| ----------------------------- | ------- | ------- | ------------------------------------------------------------ |
| `AppCore.swift`               | 1342    | 1021    | **−321**                                                     |
| `DialogController()` count    | 1       | 1       | 0                                                            |
| Coordinators                  | 0       | 2       | +2 — the first orchestration types outside `AppCore`         |
| Compiler warnings (Debug)     | 0       | 0       | 0                                                            |
| Harness count                 | 17      | 17      | 0                                                            |
| `palette-selection-test`      | 111,684 | 111,684 | 0 — no row-order surface touched                             |
| Diff size                     | —       | —       | 4 files, +551 / −372 (expected 3 files, +390 / −350)         |
| Binary size (Release)         | —       | —       | not measured                                                 |
| Clean install verified?       | —       | n-a     | no persisted state changes shape                             |

The diff is 4 files rather than 3 because `Tinycast.xcodeproj/project.pbxproj` is regenerated for the
two new sources — a consequence of `xcodegen generate`, which `build.md` explicitly permits.

---

## Failed tasks

None.

---

## Issues encountered

- **The phase's "+2 properties" budget is short by two.** `QuicklinkCoordinator` needs
  `dialogs.reportFailure` and `messageHUD.show`, both private on `AppCore`, and the boundary forbids
  giving a coordinator its own `DialogController`. `AppCore` therefore gains **four** members, not two:
  the two coordinators plus `reportFailure(title:message:symbol:recovery:)` and
  `showMessage(_:tone:)`, sitting beside the existing `showNotice` / `confirm` façade. This is the
  phase's own "route through `AppCore`" instruction taken literally, and phase 25 depends on it —
  see *Follow-up work*.
- **The two coordinators use different injection shapes, deliberately.** The boundary allows "a small
  closure **or** an `AppCore` reference for presentation only". `SnippetExpansionCoordinator` needs
  exactly one presentation call, so it takes a `showMessage` closure and ends up holding **no
  `AppCore` reference at all** — the closest this codebase has to harness-reachable orchestration.
  `QuicklinkCoordinator` needs six distinct capabilities (palette show/hide, Settings, notice, confirm,
  reportFailure, message HUD), so a bag of six closures would be worse than `unowned let core`.
- **`openQuicklink` shadows its own collaborator.** The moved body declares
  `var arguments: [MissingArgument]`, which would shadow a stored property named `arguments`. The
  session property is therefore named `argumentSession`, which keeps the moved body byte-identical
  rather than forcing `self.arguments` inside it.
- **`clipboardHistoryForExpansion` is snippet-owned but quicklink-consumed.** The phase assigns it and
  `clipboardHistoryDepth` to the snippet coordinator, yet `openQuicklink` calls it. It is injected into
  `QuicklinkCoordinator` as a `clipboardHistory` closure rather than duplicated or reached through
  `core`, so there is still exactly one depth constant and one implementation.
- **`windowController` is injected, not accessed through `core`.** `openQuicklink` and
  `performQuicklinkOpen` read `isVisible` / `previousApp`. Passing the controller in `init` keeps those
  three lines byte-identical and avoids widening `AppCore`'s surface with palette-state accessors that
  phase 25 would immediately move again.

---

## Deviations from the phase document

- **AC2 lands at −321, not −345.** 345 lines of body did leave `AppCore`; the 13 forwarders and 2
  façade methods the phase itself requires cost ~24 back. Not a shortfall in the extraction.
- **Four new `AppCore` members instead of two**, for the reason recorded above.
- **`setSnippetsEnabled` and `revealSnippetsInFinder` stayed on `AppCore`.** Neither is in Objective 2's
  list. `setSnippetsEnabled` is the consent gate and reads/writes `settings.snippetsEnabled` directly;
  moving it was not asked for, and "when in doubt, do less" applies.
- **All `onChange` / `onSnapshot` wiring stayed in `AppCore.start()`**, alongside the
  `withObservationTracking` registrations the kickoff pins there. Only the call targets changed.

---

## Follow-up work

| Observation                                                                                                                                                                                                                     | Where                                              | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | --------------- |
| **Phase 25 needs two more façade methods than it budgets for.** Its `SystemActionCoordinator` takes `perform`, which calls `volumeHUD.show(level:muted:)` and `dialogs.pickVolume(current:)` — both private on `AppCore`, neither named in phase 25. Same undercount this phase hit; plan for it rather than rediscovering it mid-extraction | `AppCore.perform` → `SystemActionCoordinator`      | **25**          |
| `AppCore` still calls `messageHUD.show` and `dialogs.reportFailure` directly in the system-action, custom-command and uninstall paths. **Not debt** — phase 25 objectives 2–4 move those exact methods, and its boundary (line 74) forces them onto the façade. Converting them now would be churn 25 deletes | `AppCore.swift`                                    | **25**          |
| Both coordinators are `lazy` and instantiate during `start()`, which pulls `windowController`'s creation forward from first palette show. `PaletteWindowController.init` only stores a reference — the panel is still built in `show()` — so no real work moved onto the launch path, but startup timing was not measured to confirm | `AppCore` init / `start()`                         | check in **25** |
| The target-app idiom `windowController.isVisible ? windowController.previousApp : NSWorkspace.shared.frontmostApplication` now appears in **four** places (three on `AppCore`, one in `QuicklinkCoordinator`). Phase 25 explicitly permits extracting it to one helper on `PaletteCoordinator` | `AppCore` + `QuicklinkCoordinator`                 | **25**          |
| Interactive regression waived — AC4, AC5 and AC6 unexercised, including the "feature off, press the bound shortcut" funnel test                                                                                                    | Quicklinks + Snippets sweeps                       | before merge    |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. Both coordinator files disappear and `AppCore` regains the two
  blocks verbatim. Re-run `xcodegen generate` afterwards. No persisted state changes shape and no
  stored format is involved.
- **Dependent phases that must also be reverted:** none yet. Phase 25 depends on this one, so a revert
  must happen *before* 25 lands.
- **Data risk on revert:** none.

---

## What was not verified

Stated plainly because AC6 is the criterion this phase's own risk register calls the failure mode:

- **The funnel test was not run.** Turning quicklinks off and pressing a still-registered global
  shortcut needs a running app and a real global keypress. What *is* proven: `guard
  settings.quicklinksEnabled` is still the first statement of `openQuicklink`, and all four entry
  points reach it — palette ↵ (`AppCore.launch`), `QuicklinkListScreen` ↵/⌘K, `hotKeys.onOpenQuicklink`,
  and the Quicklinks command. Structural, not observed.
- `checklists/regression.md` and `checklists/review.md` were waived by the operator.
- Startup timing and Release binary size were not measured.

---

## Sign-off

- [~] All acceptance criteria met — AC1, AC2, AC3, AC7, AC8 verified; AC4–AC6 structural only because
      interactive verification was waived
- [~] All four checklists passed — `build.md` PASS (Debug **and** Release), `testing.md` PASS (all 17
      harnesses, both phase gates); `regression.md` and `review.md` waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — pushed to `origin`, merge pending
- [x] **Stopped.** Next phase is a separate session.
