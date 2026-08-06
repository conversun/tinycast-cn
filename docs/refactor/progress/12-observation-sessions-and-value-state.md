# Phase 12 — Observation wave A: sessions and value state

---

## Status

| Field                         | Value                                                   |
| ----------------------------- | ------------------------------------------------------- |
| **Status**                    | Complete                                                |
| **Started**                   | 2026-08-05                                              |
| **Completed**                 | 2026-08-05                                              |
| **Operator**                  | abue-ammar                                              |
| **Branch**                    | `refactor/12-observation-sessions-and-value-state`      |
| **Commit**                    | single commit on the branch                             |
| **Claude conversations used** | 1                                                       |
| **Actual effort**             | ~45 min vs. estimate of M (2–4 h)                       |

---

## Completed tasks

- [x] Objective 1 — `VolumeState` is `@Observable`, both consumers converted to a plain `let`
- [x] Objective 2 — `QuicklinkArgumentSession` is `@Observable`, both consumers on `@Environment`
- [x] Objective 3 — `ShortcutCaptureSession` is `@Observable`, its callout reads it as a plain `let`
- [x] Objective 4 — `UninstallSession` is `@Observable`, both consumers on `@Environment`

Migrated in the order the phase document specifies, with a Debug build between each.

## Acceptance criteria

- [x] AC1 — all four `@Observable`, none retaining `ObservableObject` or `@Published` — verified by:
      `grep -nE "ObservableObject|@Published"` over the four files returns nothing
- [x] AC2 — every consumer compiles without an optional `@Environment` lookup — verified by: all three
      declarations written with **no type annotation**, so the optional overload cannot be selected;
      `grep` for `environmentObject|EnvironmentObject|ObservedObject|StateObject` against any of the
      four type names returns nothing
- [x] AC3 — the volume dialog's slider tracks a drag and updates the readout live — verified by: the
      operator, interactively
- [x] AC4 — the volume HUD animates its bar in place on a repeat rather than replaying the entrance —
      verified by: the operator, interactively
- [x] AC5 — the quicklink argument prompt advances and steps back on Backspace — verified by: the
      operator, interactively
- [x] AC6 — the shortcut recorder shows held modifiers live and flashes a conflict for ~1.5 s —
      verified by: the operator, interactively. The highest-frequency observable in the app
- [x] AC7 — the uninstall screen transitions idle → scanning → ready and checkbox toggles update the
      summary line — verified by: the operator, interactively
- [x] AC8 — no other type's observation mechanism changed — verified by: 11 changed files, all from the
      phase's expected list; `PaletteWindowController`'s `environmentObject` count 14 → 12 and
      `.environment` 1 → 3; `HotKeyManager.swift`, `UninstallScanner.swift`, the five pure uninstall
      files and `VolumeLevel.swift` all have empty diffs

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                                                                                                        |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `checklists/build.md`      | PASS   | `xcodegen generate` clean with **zero `.xcodeproj` churn** (no files added). Debug `BUILD SUCCEEDED`, zero warnings against a pre-phase baseline captured on this branch — the first phase where "zero *new* warnings" is measured rather than asserted. No new Swift 6 diagnostics; no `@unchecked Sendable`, `nonisolated(unsafe)` or `assumeIsolated` added. Release `BUILD SUCCEEDED`, no type-checker timeout. §5 launch run by the operator; §6 startup timing N/A (phase 12 is not in its list) |
| `checklists/testing.md`    | PASS   | Harnesses run: `volume-test` (81 passed), `uninstall-test` (117 passed), `quicklink-test` (82/82), `hotkey-test` (34 passed) — all exit 0. By the harness → owning-source map **none** was mandatory: no changed file appears in its right column. The four are the phase document's own gates, so they are regression proof rather than compile gates. Purity intact — no import added anywhere in the diff                                     |
| `checklists/regression.md` | PASS   | Run by the operator, manually — Core sweep + Uninstall + Quicklinks + Hotkeys + System actions & window management, per the phase document. Note regression.md's own scoped-section phase lists name 12 nowhere, so the checklist alone would have required only the Core sweep; the phase document is stricter and wins. Clean install N/A. Claude ran no interactive verification in this session |
| `checklists/review.md`     | PASS   | §1 scope: 11 files, all from the expected list, **none from the must-NOT-change list**; 57 lines changed against a ~190 ceiling; no file created or deleted. §2 no condition, comparison, default, branch or early return changed, and **no string literal changed** — so no persisted key and no user-visible string moved. §3 no `@MainActor`/`nonisolated` added or removed, no new `assumeIsolated`, `Task.detached`, `DispatchQueue` or `Timer`. §4 no closure added, no new cache, nothing newly retained. §5 comments +0/−0, stacked +0, none over 100 chars. §6 the one orphan (`import Combine`) deleted; no TODO, shim or alias. §7 `sizingOptions = []` intact in `PalettePanel.swift`, uninstall still `trashItem`-only, no `NSAlert`, `EdgeDissolve`/`ThinScrollbar` untouched, no new singleton |

### Measurements

| Metric                     | Before    | After     | Δ                                                                          |
| -------------------------- | --------- | --------- | ---------------------------------------------------------------------------- |
| Binary size (Release)      | 3,542,936 | 3,526,472 | **−16,464 B (−0.465 %)** — the binary *shrank*                              |
| Clean install verified?    | —         | n-a       | no storage change; these four types are in-memory session state only        |
| Cold launch, median of 3   | —         | —         | no phase-01 baseline exists; nothing added to `init` or `start()`           |
| RSS after 10 palette opens | —         | —         | not measured                                                                |
| Phase-specific signpost    | —         | —         | per-type invalidation scoping not measured; see phase 11 AC7 and phase 34   |

The "before" is a **freshly built `main`** in a throwaway git worktree with its own derived-data root,
because phases 09, 10 and 11 recorded no size. That makes this the first measured point since phase 08
(3,507,576 B), and the +18,896 B between them is the unattributed cost of 09–11.

**The binary shrank**, which is the opposite of phases 06 and 08. Dropping `ObservableObject` and
`@Published` from four types removes more `Published<T>` and `ObservableObjectPublisher` generic
specialization than the `@Observable` registrar adds. Cumulative growth since the phase-01 baseline of
3,471,592 B is now +54,880 B (+1.581 %), inside the 2 % ceiling — and phases 13–18 should be expected
to keep reducing it.

---

## Failed tasks

none — all four types migrated; none had to be dropped to a follow-up phase.

---

## Issues encountered

- **`build.md` §4's size budget contradicts itself.** It reads "under **3 MB upto 4MB**
  (3,145,728 bytes)". 3,145,728 is 3 MB, and the phase-01 baseline was already 3.47 MB, so the 3 MB
  reading would have failed every phase to date. Scored against the 4 MB reading. The checklist should
  be corrected to state one number.
- **`regression.md`'s scoped-section phase lists are stale.** No section names phase 12, so following
  the checklist alone would have run only the Core sweep and skipped the four features whose session
  types this phase rewrote. The phase document caught it. Phases 13–18 will hit the same gap.
- **A stale `Tinycast Dev` was running again**, exactly as in phase 11 — PID 22871 from
  `build/DerivedData/` (an Xcode GUI build root), while `xcodebuild` writes to
  `~/Library/Developer/Xcode/DerivedData/Tinycast-faaxgapthtbqppbdpxhoiykymzjc/`. Flagged before the
  sweep so the operator tested the right binary. This is now twice; it is worth picking one root.
- **`@Environment(T.self)` non-optional is the whole runtime risk.** A missed injection site still
  compiles, because `.environmentObject(x)` is valid for an `@Observable` value. Here it would *trap*
  rather than read nil, which is the point of the annotation-free form. Backstopped statically:
  `RootPaletteView()` has exactly one instantiation site and it carries both new `.environment(…)`
  calls; `QuicklinkArgumentsView` and `UninstallList` mount only inside it.

---

## Deviations from the phase document

- **11 files changed, not the 13 the file table lists.** Two expected files needed no change:
  `Features/Settings/ShortcutRecorder.swift` names the capture session only inside a comment and has no
  consumption to update, and `Core/Dialog/DialogController.swift` only constructs `VolumeState(level:)`
  and reads/writes `.level` — none of which is observation API.
- **Diff is +30/−27 against an expected +45/−50.** The estimate assumed the two files above needed
  edits and that more import churn would follow.
- **One extension beyond the phase-11 recipe:** `@ObservationIgnored` on
  `ShortcutCaptureSession.detector`. Recipe §4 names retained `Task`/`AnyCancellable` handles;
  `detector` is a value type rather than a handle, but it is private, unreadable by any view, and
  mutated on every `flagsChanged` — the highest-frequency write in the app. The other four
  `@ObservationIgnored` sites (`monitors`, `resignObserver`, `conflictReset`, `scanTask`) are the
  recipe applied as written.
- **`UninstallSession.app` is now tracked where it previously was not.** It was a plain
  `private(set) var`, so `ObservableObject` never published it; `@Observable` tracks it. It is written
  only by `begin` and `cancel`, both of which also write `state`, so it adds no invalidation the
  `state` read did not already cause — the same reasoning phase 11 applied to `FavoritesStore.revision`.
  Left tracked deliberately rather than suppressed.
- **No deviation on the recipe's import question:** no `import Observation` was needed, as phase 11
  recorded. The only import touched is `import Combine`, deleted from `VolumeState.swift` because
  nothing else in that file used Combine.

---

## Follow-up work

| Observation                                                                                                                                                                                          | Where                                        | Suggested phase        |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- | ---------------------- |
| `VolumeState`'s doc comment opens "Published so a repeated command refreshes a HUD…". The word no longer names `@Published`. Still correct as plain English; left alone rather than improved in passing | `Core/VolumeState.swift:3`                   | 34 (comment pass)      |
| `regression.md`'s scoped-section phase lists name no M2 phase, so the checklist under-scopes every observation phase                                                                                  | `docs/refactor/checklists/regression.md`     | 13 (or fix in place)   |
| `build.md` §4 states two different binary budgets in one line                                                                                                                                        | `docs/refactor/checklists/build.md:57,64`    | 13 (or fix in place)   |
| Two DerivedData roots keep producing a stale `Tinycast Dev` during verification — second occurrence                                                                                                  | environment, not source                      | none — operator choice |
| Per-type invalidation scoping still unmeasured; the M2 win stays qualitative                                                                                                                          | —                                            | 34 (final measurement) |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. All four types are in-memory session state — no persistence,
  no format, no key, no migration in either direction.
- **Dependent phases that must also be reverted:** none. Phases 13–18 list 11, not 12, as their
  dependency, and none builds on this diff. Reverting 12 alone is coherent provided no later phase has
  converted a consumer sharing one of the two `PaletteWindowController` injection sites.
- **Data risk on revert:** none.

---

## Sign-off

- [x] All acceptance criteria met
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
