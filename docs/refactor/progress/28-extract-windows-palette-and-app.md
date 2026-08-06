# Phase 28 — Extract `Windows/`, `Palette/` and `App/`

---

## Status

| Field                         | Value                                             |
| ----------------------------- | ------------------------------------------------- |
| **Status**                    | Complete                                          |
| **Started**                   | 2026-08-06                                        |
| **Completed**                 | 2026-08-06                                        |
| **Operator**                  | abue-ammar                                        |
| **Branch**                    | `refactor/28-extract-windows-palette-and-app`     |
| **Commit**                    | single commit on the branch                       |
| **Claude conversations used** | 1                                                 |
| **Actual effort**             | ~15 min vs. estimate of M (2–4 h)                 |

---

## Completed tasks

- [x] Objective 1 — `Tinycast/Windows/` created; `Dialog/` (5 files), `HUD/` (6 files), `About/` (1) and
      `AuxWindowController.swift` moved into it
- [x] Objective 2 — `Tinycast/Palette/` created; panel, controller, root view, screen protocol,
      coordinator and the two extracted state files moved into it
- [x] Objective 3 — `Tinycast/App/` consolidated: `AppCore.swift` joins `TinycastApp` and `AppDelegate`
- [x] `AuxWindowController` cut out of `AboutView.swift` into `Windows/AuxWindowController.swift`
- [x] `PaletteViewModel` cut out of `AppCore.swift` into `Palette/PaletteViewModel.swift`
- [x] `PaletteMode` + `PasteTarget` cut out of `AppCore.swift` into `Palette/PaletteMode.swift`
- [x] Six emptied directories pruned
- [x] `xcodegen generate` re-run and the regenerated `project.pbxproj` staged

## Acceptance criteria

- [x] AC1 — every listed file at its new path — verified by: `git diff -M --cached --summary` shows 16
      renames plus 3 creates. See _Deviations_ for `OnboardingState.swift`
- [x] AC2 — 100 % similarity for every pure move — verified by:
      `git diff -M --cached --summary` shows **16 of 16** pure moves at `(100%)`; the only non-100 %
      entries are the two extraction parents, `AppCore.swift (81%)` and `AboutView.swift (66%)`, which
      lost a type each
- [x] AC3 — `AuxWindowController` is its own file and `AboutView.swift` no longer declares it —
      verified by: `grep -c AuxWindowController` in `AboutView.swift` is 0; `AboutLink` and
      `AboutLinkRow` are still there and still `private`
- [x] AC4 — the three types are out of `AppCore.swift`, which is shorter — verified by: 642 → 543 lines
- [x] AC5 — `PaletteWindowController` byte-identical — verified by:
      `rename Tinycast/{Core => Palette}/PaletteWindowController.swift (100%)`. The file was never
      opened. `PalettePanel.swift` is likewise 100 %
- [x] AC6 — all 17 harnesses pass, no command line changed — verified by: the `## Tests` fence of
      `docs/development.md` run under `bash -e`, exit 0; `palette-selection-test` 111,684, unchanged.
      The phase's "no harness references any file in this phase" claim was **checked before being
      relied on** — every harness input lives in `Core/`, `DesignSystem/`, `Platform/` or
      `Features/PaletteRowIndex.swift`, none of which this phase touches. `ci.yml` likewise unchanged
- [~] AC7 — Debug and Release succeed; UI pixel-identical — **builds met, pixel-identity argued not
      observed.** Both configurations build clean at 0 compile warnings against a pre-phase Debug
      baseline of 0. Pixel-identity was **not** visually verified: every view and panel file moved at
      100 % similarity and the three extraction diffs are byte-identical to `HEAD`, so no view body,
      layout token or animation curve can have changed — but no screenshot pair was taken

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                            |
| -------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | Debug **and** Release, `CODE_SIGNING_ALLOWED=NO`. 0 → 0 compile warnings against a pre-phase Debug baseline. `xcodegen generate` twice → `project.pbxproj` identical              |
| `checklists/testing.md`    | PASS    | All 17 harnesses, `bash -e`, exit 0. `palette-selection-test` 111,684 unchanged                                                                                                   |
| `checklists/regression.md` | NOT RUN | **Waived by the operator**, who declined further testing. See _Issues encountered_ — this is the one gap in this phase's record and the three aux-window runtime checks are in it |
| `checklists/review.md`     | PASS    | Content delta proven by `diff` against `git show HEAD:…` rather than by eye, on all three extractions and both parents. Comment delta 0                                           |

### Measurements

Not a performance or size phase. Content delta is near zero by construction: 16 files moved with zero
changed lines, and the three extractions are byte-identical cut-and-paste.

---

## Failed tasks

None.

---

## Issues encountered

- **`regression.md` was waived, and unlike phases 25–27 that waiver is not free here.** Those phases'
  waivers were sound because their acceptance criteria were structural. This phase's regression risks
  are **runtime**: the `DispatchQueue.main.async` re-assertion of key status, and `windowWillClose`
  restoring `.accessory`. Both survive in source verbatim — the extracted body `diff`s clean against
  `HEAD`, so nothing can have been dropped — but the phase document asks for three runtime checks and
  none was performed:

  - open Settings **from the menu bar** and confirm you can type in it immediately
  - close the last aux window and confirm the Dock icon disappears
  - open Settings, then click the Dock icon, and confirm the existing window is focused, not duplicated

  The byte-identity argument is strong (the failure mode this guards against is a *lost* re-assertion,
  and it demonstrably was not lost) but it is not the same as having watched the window take focus.
  Anyone who trips over an aux-window focus bug later should start here.

- **The emoji generator ran by accident and proved something useful.** Extracting the `## Tests` fence
  of `docs/development.md` by `awk` picks up the `node Tools/gen-emoji.js` line that follows the
  harnesses, so `EmojiData.generated.swift` was regenerated mid-run. It came back **byte-identical** to
  the committed file, so nothing was staged — but the generator is not idempotent by contract, only in
  fact, and a Unicode revision upstream would have silently dirtied the diff. Slice the fence at the
  last `swiftc` line, not by `head -n`.

- **`git mv` leaves the emptied directories on disk.** Six of them (`Core/Dialog`, `Core/HUD`,
  `Features/About`, `Features/Dialog`, `Features/HUD`, `Features/Palette`). Git does not track them so
  nothing complains, but XcodeGen derives sources from the directory tree and a stray empty group is
  noise. `find Tinycast -type d -empty -delete`.

---

## Deviations from the phase document

- **`Core/OnboardingState.swift` was not moved.** The phase's `App/` table lists it going to
  `Features/Onboarding/OnboardingState.swift`, annotated _"(with its view, in phase 29)"_. Read as: the
  destination is recorded here, the move happens in 29 — which is also what "Do not reorganise
  `Features/` — phase 29" requires. It stays in `Core/`. **Phase 29 must move it**; it is one of the
  files AC6 there depends on to delete `Core/`.

- **`Palette/PaletteViewModel.swift` imports `Foundation`, not `AppKit`.** The source file imported
  `AppKit` because `PasteTarget` needs `NSRunningApplication`; the view-model needs only `UUID`. The
  narrower import is the honest one and `PaletteMode.swift`, which carries `PasteTarget`, keeps
  `AppKit`.

- **`Windows/AuxWindowController.swift` imports both `AppKit` and `SwiftUI`.** `show` is generic over
  `View`, takes a `@ViewBuilder` and constructs an `NSHostingView`, so neither import is droppable.

- **Doc paths were updated although no acceptance criterion asked.** Phase 27 established this and its
  progress note flagged stale paths as the real cost: `AGENTS.md` (2 inline paths + the Project Layout
  section, which gained `Palette/` and `Windows/` bullets), `docs/architecture.md` (4) and `docs/ui.md`
  (2 section headings). `docs/architecture-review.md` carries four now-stale paths and was **left
  alone** deliberately — it is the historical review, rank 5 on the precedence ladder, never an
  instruction.

- **The `Windows/` file count differs from the phase's table arithmetic.** The table lists
  `Features/About/AboutView.swift → Windows/About/AboutView.swift` and `AuxWindowController` as
  separate rows, which is what was done: `Windows/About/` holds the view, `AuxWindowController.swift`
  sits at `Windows/` root next to `Dialog/` and `HUD/`. `Dialog/` and `HUD/` were **not** merged.

---

## Follow-up work

| Observation                                                                             | Where                                   | Suggested phase           |
| --------------------------------------------------------------------------------------- | --------------------------------------- | ------------------------- |
| `OnboardingState.swift` still in `Core/`, by this phase's reading of its own move table  | `Tinycast/Core/OnboardingState.swift`   | 29 (already required)     |
| `Tinycast/Core/` still holds 24 files                                                    | `Tinycast/Core/`                        | 29 — its AC6 deletes it   |
| Four stale paths in the architecture review                                              | `docs/architecture-review.md` 251, 643, 649, 903 | 34, with the docs pass |
| The three aux-window runtime checks this phase skipped                                   | Settings / About / Onboarding windows   | Fold into 29's regression |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. Pure moves plus three cut-and-paste extractions; no storage,
  no persisted format, no behaviour. Re-run `xcodegen generate` after reverting.
- **Dependent phases that must also be reverted:** none yet. **29 hard-depends on this**, so reverting
  after 29 lands means reverting 29 too.
- **Data risk on revert:** none.

---

## Sign-off

- [x] All acceptance criteria met — AC7 partially: builds verified, pixel-identity argued from
      byte-identity rather than observed
- [ ] All four checklists passed — **three of four.** `regression.md` not run; waived by the operator
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main` — branch pushed, not merged
- [x] **Stopped.** Next phase is a separate session.
