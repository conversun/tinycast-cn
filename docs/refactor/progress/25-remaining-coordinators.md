# Phase 25 — Palette, SystemAction, Uninstall and CustomCommand coordinators

---

## Status

| Field                         | Value                                              |
| ----------------------------- | -------------------------------------------------- |
| **Status**                    | Complete                                           |
| **Started**                   | 2026-08-05                                         |
| **Completed**                 | 2026-08-05                                         |
| **Operator**                  | abue-ammar                                         |
| **Branch**                    | `refactor/25-remaining-coordinators`               |
| **Commit**                    | single commit on the branch                        |
| **Claude conversations used** | 1                                                  |
| **Actual effort**             | ~40 min vs. estimate of L (4–8 h)                  |

---

## Completed tasks

- [x] Objective 1 — `PaletteCoordinator`: the three toggles, `showPalette`/`hidePalette`,
      `paletteIsCollapsed`, `expandFromCompact`, `syncPaletteSize`, `handleReopen`, the five
      aux-window methods, and the one permitted target-app helper
- [x] Objective 2 — `SystemActionCoordinator`: `runSystemAction`, `perform`, `presentFailure`,
      `quitAllApps`, `showsVolumeFeedback`, the volume/message-HUD branch
- [x] Objective 3 — `UninstallCoordinator`: `beginUninstall`, `performUninstall`, copy/reveal/info,
      `removeUninstalledReferences`, `presentUninstallReport`
- [x] Objective 4 — `CustomCommandCoordinator`: CRUD, `runCustomCommand`,
      `removeCustomCommandReferences`, `presentCustomCommandFailure`, presence reconciliation
- [x] `AppCore` constructs all four, retains a forwarder for every call site

## Acceptance criteria

- [x] AC1 — all four are `@MainActor` and reference no `AppCore.shared` — verified by:
      `grep -rn "AppCore.shared"` over the four new files returns nothing
- [ ] **AC2 — `AppCore.swift` under ~300 lines — NOT MET: 746.** Unreachable inside this phase's
      boundaries, and the phase document contradicts itself on the number. See *Deviations*
- [x] AC3 — `grep -c "DialogController()" Tinycast` is 1 — verified by: still `AppCore.swift` alone
- [x] AC4 — `PaletteWindowController` unchanged — verified by: absent from `git diff --name-only`
- [~] AC5 — every summon path works (hotkey, menu bar, Dock reopen, "Open Tinycast", command
      entries) — **structural**; all five reach the one `showPalette`
- [~] AC6 — compact↔expanded swaps with the top edge anchored — **structural**; no frame logic moved
- [~] AC7 — Pop to Root Search behaves at every timeout — **structural**; `consumePreservedState`
      and the timer never left `PaletteWindowController`
- [~] AC8 — every system action confirms where it did, with the same icon — **structural**; the
      `confirmation` switch and `action.sfSymbol` are byte-identical by body diff
- [~] AC9 — uninstall end to end including cleanup and index refresh — **structural**; the ten-step
      sequence is byte-identical by body diff
- [~] AC10 — custom commands: gate, success pill, failure dialog with the shell-environment hint —
      **structural**; `presentCustomCommandFailure` moved intact including the `127` branch

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                             |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + **Debug and Release**, both exit 0. **0 compiler warnings against a 0 baseline** measured by a clean Debug build on this branch before any edit. Startup timing **not** measured |
| `checklists/testing.md`    | PASS   | **All 17 harnesses** via the `## Tests` fence, exit 0, no `FAIL` lines. All five phase gates included — `system-action-test`, `uninstall-test`, `custom-command-test`, `volume-test`, `window-command-test`. `palette-selection-test` 111,684, unchanged (this phase adds no rows) |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC5–AC10 are therefore unexercised**, including the two runs the kickoff names: the compact-mode top-edge check and the held-hotkey dialog-stacking check |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                                                                                   |

### Hard gates

| Gate                                                    | Result                                                                    |
| ------------------------------------------------------- | ------------------------------------------------------------------------- |
| `PaletteWindowController` in the diff                   | **absent** — the frame owner is untouched                                 |
| `grep -c "DialogController()" Tinycast`                 | **1** — still `AppCore.swift` alone                                       |
| `grep -rn "AppCore.shared"` in the four new files       | empty                                                                     |
| Files from **Files that must NOT change** in the diff   | none — `SystemActionRunner`, `SystemAction`, `Core/Uninstall/`, `CustomCommand`, `ShellCommandRunner`, `Core/Dialog/`, `Core/HUD/` and `AboutView.swift` all absent |
| `runWindowCommand` still on `AppCore`                   | yes — no coordinator was created for it                                   |

### How the moves were verified

`git diff -M` cannot pair these bodies while `AppCore.swift` still exists, so — as in phase 24 — the
pre-change blocks were extracted from `HEAD` and diffed line-by-line against the four new files.
**Every difference is a receiver rename, an access rewrite, or the one helper the phase authorises:**

| Old                                                       | New                                       |
| --------------------------------------------------------- | ----------------------------------------- |
| `uninstall.`                                              | `session.`                                |
| `customCommands.`                                         | `store.`                                  |
| `launcherRanking.`                                        | `ranking.`                                |
| `dialogs.reportFailure` / `dialogs.pickVolume`            | `core.reportFailure` / `core.pickVolume`  |
| `messageHUD.show(message:tone:)`                          | `core.showMessage(_:tone:)`               |
| `confirm` / `showNotice` / `showSettings`                 | `core.`- / `paletteCoordinator.`-prefixed |
| `.environment(self)` and four `self.<store>` injections   | `self.core` / `self.core.<store>`         |
| `windowController.isVisible ? … : NSWorkspace…frontmost`  | `paletteCoordinator.targetApp`            |

No condition, no ordering, no string literal and no control-flow shape changed. The three sequences
the phase pins are intact:

- **`performUninstall`**: guard → confirm → quit if running → `setTrashing(true)` → trash →
  `setTrashing(false)` → cleanup → `appIndex.refresh()` → `prepare(mode: .launcher)` → report.
- **`perform`**: `.computed` → `quitAllApps` and return; `.required` → confirm gate; `.none` → straight
  through. `setVolume` still takes the slider branch; `showsVolumeFeedback` still wins over `feedback`.
- **`runCustomCommand`**: feature switch → lookup → hide → confirmation gate → run → pill or failure.

### Measurements

| Metric                      | Before  | After   | Δ                                                              |
| --------------------------- | ------- | ------- | -------------------------------------------------------------- |
| `AppCore.swift`             | 1021    | **746** | **−275**                                                       |
| `DialogController()` count  | 1       | 1       | 0                                                              |
| Coordinators                | 2       | 6       | +4 — `AppCore` is no longer the only orchestrator              |
| `AppCore` properties        | —       | —       | +4 coordinators, −2 (`volumeHUD`, `auxWindows` moved with their features) |
| Compiler warnings (Debug)   | 0       | 0       | 0                                                              |
| Harness count               | 17      | 17      | 0                                                              |
| `palette-selection-test`    | 111,684 | 111,684 | 0 — no row-order surface touched                               |
| Diff size                   | —       | —       | 6 files, +595 / −334 (expected 5 files, +420 / −380)           |
| Binary size (Release)       | —       | —       | not measured                                                   |
| Clean install verified?     | —       | n-a     | no persisted state changes shape                               |

The diff is 6 files rather than 5 because `Tinycast.xcodeproj/project.pbxproj` is regenerated for the
four new sources — a consequence of `xcodegen generate`, which `build.md` explicitly permits.

---

## Failed tasks

None.

---

## Issues encountered

**`dialogs.pickVolume` needed a façade the phase does not budget for.** Exactly as `progress/24`
predicted. `DialogController` must stay single-owned, so `SystemActionCoordinator` cannot hold it;
`AppCore.pickVolume(current:)` was added alongside phase 24's `showMessage` / `reportFailure`. This is
the third façade forced by the same constraint, and phase 32 deletes all of them.

**`volumeHUD` did not need one.** `progress/24` flagged it alongside `pickVolume`, but
`VolumeHUDController` is not `DialogController` and `SystemActionCoordinator` is its only caller, so
ownership moved with the feature instead of a fifth façade method. Same for `AuxWindowController`,
whose only callers are the aux-window methods that moved to `PaletteCoordinator`.

**`import SwiftUI` in `AppCore.swift` became dead** once `showSettings` and `showOnboarding` left with
their `SettingsRootView` / `OnboardingView` references. Removed under workflow step 6, and confirmed
dead by building without it.

---

## Deviations from the phase document

- **AC2 is unreachable, and the phase document disagrees with itself.** AC2 asks for "under ~300
  lines"; the same document's *Expected commit size* budgets "`AppCore` net −370", which from 1021
  lands at ~651. Neither reaches 300. The extraction delivered −275 and the file sits at **746**. What
  remains, and why:

  | Block                                                                             | Lines | Owner                    |
  | --------------------------------------------------------------------------------- | ----- | ------------------------ |
  | `PaletteMode`, `PasteTarget`, `PaletteViewModel` — not `AppCore` at all           | ~99   | **phase 28** extracts them |
  | Forwarders kept by this phase's own instruction                                   | ~99   | **phase 32** deletes them  |
  | Ownership, `init`, `start()`, `prepareForTermination`, feature-switch tracking    | ~160  | stays — this is the composition root |
  | Dialog façade                                                                     | ~42   | stays                    |
  | `runWindowCommand` + `applyWindowCommandsPresence` — the phase says leave them    | ~25   | stays                    |
  | Palette-UI action methods (`launch`, `runCommand`, clipboard, emoji, calculator, snippets gestures) | ~195 | **no phase** — see *Follow-up work* |

  Only the last row is genuine debt. Chasing 300 inside this phase would have meant inventing
  extractions no phase authorises, which the standing contract forbids.

- **The target-app helper covers two of three sites, not three.** The boundary permits one helper on
  `PaletteCoordinator`; `AppCore.runWindowCommand` and `SystemActionCoordinator.runSystemAction` both
  use it. `QuicklinkCoordinator.openQuicklink` keeps its inline copy — it is phase 24's file and is not
  in this phase's *Expected files to modify*.

- **`AuxWindowController` and `VolumeHUDController` changed owner**, which the phase does not
  explicitly authorise but its objectives imply ("the aux-window show methods", "the volume-HUD
  choice"). Neither type's contents were touched; `AboutView.swift`, which still declares
  `AuxWindowController`, is absent from the diff.

- **`hotKeys.on*` callbacks were re-pointed at the coordinators** rather than at `AppCore`'s
  forwarders, matching what phase 24 did for `onOpenQuicklink`. The funnel is unchanged either way —
  this only removes one hop.

---

## Follow-up work

| Observation                                                                                                                                                                                                                                                        | Where                              | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------- | --------------- |
| **~195 lines of palette-UI actions have no owning coordinator in any phase** — `launch`, `runCommand`, `resetRanking`/`showInFinder`/`quit`, the six clipboard actions, the three emoji actions, the three calculator actions, `setSnippetsEnabled`/`revealSnippetsInFinder`. Phase 29's feature table lists a coordinator for Quicklinks, Snippets, Uninstall, SystemActions and CustomCommands but **none** for Launcher, Clipboard, Emoji or Calculator. **This blocks phase 32's stated objective**, which assumes every call site has a coordinator to be pointed at | `AppCore.swift`                    | **25b** (new)   |
| The 128 lines of palette chrome `progress/23` flagged as homeless are part of the same gap and are covered by the same proposal                                                                                                                                       | `RootPaletteView` / `AppCore`      | **25b** (new)   |
| `progress/23` filed the three palette types as "a gap in 29". They are **not** a gap — phase 28's expected-moves table extracts `PaletteViewModel` and `PaletteMode`/`PasteTarget` from `AppCore.swift` by name                                                       | `AppCore.swift`                    | **28** (already planned) |
| Phase 28 says "confirm all **18** still pass". The harness count is **17**, as `progress/19` first recorded. Same stale number as phases 19–24                                                                                                                        | `phases/28-*.md`                   | fix in **28**   |
| Six coordinators now instantiate lazily during `start()`, pulling `windowController`'s creation forward from first palette show. `PaletteWindowController.init` only stores a reference, so no real work moved onto the launch path — but startup timing is still unmeasured, as `progress/24` also noted | `AppCore` `init` / `start()`       | **34**          |
| Interactive regression waived — AC5–AC10 unexercised, including the compact-mode top-edge check and the held-hotkey dialog-stacking check                                                                                                                             | palette + system-action sweeps     | before merge    |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. The four coordinator files disappear and `AppCore` regains the
  four blocks verbatim, including `volumeHUD`, `auxWindows` and `import SwiftUI`. Re-run
  `xcodegen generate` afterwards. No persisted state changes shape and no stored format is involved.
- **Dependent phases that must also be reverted:** none yet. Phases 26 and 32 depend on this one, so a
  revert must happen before either lands.
- **Data risk on revert:** none.

---

## What was not verified

Stated plainly, because these are the two checks the kickoff calls out by name:

- **The compact-mode top-edge check was not run.** Typing in compact mode to confirm the top edge does
  not move needs a running app and a human at the screen. What *is* proven: `PaletteWindowController`
  is absent from the diff, so `applyCollapsed`, `positionPanel`, `resolveAnchor` and the session anchor
  are byte-identical, and `paletteIsCollapsed` is still one computed property with one definition.
- **The held-hotkey dialog-stacking check was not run.** What *is* proven: `DialogController()` still
  greps to exactly 1, so the presenter that refuses a second dialog is still the only one.
- `checklists/regression.md` and `checklists/review.md` were waived by the operator.
- Startup timing and Release binary size were not measured.

---

## Sign-off

- [~] All acceptance criteria met — AC1, AC3, AC4 verified; **AC2 not met (746 lines)** for the
      documented reason; AC5–AC10 structural only because interactive verification was waived
- [~] All four checklists passed — `build.md` PASS (Debug **and** Release), `testing.md` PASS (all 17
      harnesses, all five phase gates); `regression.md` and `review.md` waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [x] **M4's Definition of Done is not yet true** — `AppCore` is not "the composition root and nothing
      else" while ~195 lines of palette-UI actions remain. Phase 25b is proposed to close it
- [ ] Merged to `main` — pushed to `origin`, merge pending
- [x] **Stopped.** Next phase is a separate session.
