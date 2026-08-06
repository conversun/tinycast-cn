# Phase 04 — Retire the last `NSAlert`

---

## Status

| Field                         | Value                                 |
| ----------------------------- | ------------------------------------- |
| **Status**                    | Complete                              |
| **Started**                   | 2026-08-05                            |
| **Completed**                 | 2026-08-05                            |
| **Operator**                  | abue-ammar                            |
| **Branch**                    | `refactor/04-retire-the-last-nsalert` |
| **Commit**                    | `a49e802`                             |
| **Claude conversations used** | 1                                     |
| **Actual effort**             | ~0.5h vs. estimate of S               |

---

## Completed tasks

- [x] Objective 1 — the `NSAlert` in `setSnippetsEnabled` replaced with `AppCore.confirm(…)`, dispatched
      through a `Task` so the pane's `Binding` setter stays synchronous
- [x] Objective 2 — text, button titles and the consent → persist → permission ordering preserved exactly
- [ ] Objective 3 — `grep -rn "NSAlert" Tinycast` returns nothing — **not achievable within the phase's
      own boundaries**; see Deviations and Follow-up work

## Acceptance criteria

- [ ] AC1 — `grep -rn "NSAlert" Tinycast` returns zero results — **NOT MET.** Three hits survive, none of
      them this call site and none reachable inside the phase's boundaries: two are comments naming the
      type (`Core/AppCore.swift:566` and `Core/Dialog/DialogController.swift:4`, the latter listed under
      **Files that must NOT change**), and the third is a second, genuine `NSAlert` in
      `Features/Snippets/SnippetArgumentsPrompt.swift:17` that the phase never lists. Recorded as a
      deviation, not a pass
- [x] AC2 — title and message character-identical, including "Keystrokes stay on this Mac." — verified
      by: `git diff -U0 | grep '^[-+].*"'` shows both strings moved verbatim (`messageText` → `title`,
      `informativeText` → `message`); no character changed
- [x] AC3 — buttons are "Continue" (primary, ↵) and "Cancel" (leading, Escape) — verified by:
      `DialogController.confirm` is unmodified and builds `[Continue, Cancel(.cancel)]` with
      `defaultIndex: 0` / `cancelIndex: 1`; leading-Cancel rendering and ↵/Escape handling are its
      standing behaviour. Confirmed on screen by the operator
- [x] AC4 — confirming enables snippets **then** requests Accessibility — verified by: the two statements
      are adjacent in the diff with `settings.snippetsEnabled = true` first, both inside the
      `guard await confirm(…) else { return }`
- [x] AC5 — cancelling changes nothing and requests nothing — verified by: the `guard … else { return }`
      precedes both statements. **Confirmed at runtime by the operator from a reset TCC state** — Escape
      leaves the feature off and raises no permission prompt
- [x] AC6 — the dialog uses the app's own dark surface, not an Aqua alert — verified by: presentation is
      `DialogPanel`, unmodified. Confirmed on screen by the operator
- [x] AC7 — turning snippets **off** still takes the early-return path with no dialog — verified by: the
      `if !enabled` branch is untouched above the diff hunk

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                  |
| -------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | §1–2 Debug `BUILD SUCCEEDED`; zero new warnings against a pre-phase baseline captured on the same tree. §3 Release `BUILD SUCCEEDED` (not required for this phase — run anyway for the size figure). §4 n-a, §5–6 do not list phase 04 |
| `checklists/testing.md`    | PASS   | Harnesses run: `snippets-test` — ALL PASSED. `AppCore.swift` compiles into no harness, so this is the adjacent-subsystem gate the kickoff names                                                                                        |
| `checklists/regression.md` | PASS   | Core sweep + **Snippets**, run by the operator from a `tccutil reset Accessibility com.tinycast.app.dev` state: cancel path, accept path, expansion in TextEdit, disable teardown, and the held-Return stacking check                  |
| `checklists/review.md`     | PASS   | §1–8 mechanically clean; 1 file, +14/−12                                                                                                                                                                                               |

### Measurements

| Metric                     | Before    | After     | Δ                          |
| -------------------------- | --------- | --------- | -------------------------- |
| Binary size (Release)      | 3,473,448 | 3,473,464 | +16 B (0.0005 %)           |
| Clean install verified?    | —         | n-a       | phase persists nothing new |
| Cold launch, median of 3   | —         | —         | n-a, not a startup path    |
| RSS after 10 palette opens | —         | —         | n-a, no allocation change  |
| Phase-specific signpost    | —         | —         | no signpost covers this    |

This phase claims no performance effect. The +16 bytes is the `Task` closure replacing the `NSAlert`
setup; `build.md` §3's 2 % growth budget is untouched.

> The 3,473,464-byte binary is over `build.md` §4's 3 MB upto 4MB budget, and was already over it at phase 02.
> That is a pre-existing condition of the refactor baseline, not something this phase moved.

---

## Failed tasks

| What                                       | Why it failed                                                                                                                                                                                                                                                  | Decision                                                              |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Objective 3 / AC1 — a clean `NSAlert` grep | A second `NSAlert` lives in `SnippetArgumentsPrompt.swift`, which the phase does not list as modifiable, and converting it needs a form-field dialog `DialogController` has no API for — building one would mean editing `Core/Dialog/*`, explicitly forbidden | Left alone. Recorded as follow-up work rather than widening the phase |

---

## Issues encountered

- **The phase's own grep gate cannot pass as written.** `grep -rn "NSAlert" Tinycast` matches comments
  as well as code, and one of those comments is inside `Core/Dialog/DialogController.swift` — a file the
  same phase forbids touching. Even with every real `NSAlert` gone, the check returns two hits. A future
  doc fix should scope it to `let alert = NSAlert()` or exclude comments.
- **`AppCore.confirm` requires a `symbol`; the phase names tone and role but not the glyph.** Resolved
  with `curlybraces` — snippets' own glyph in all three existing sites (`SettingsRootView`,
  `SnippetsSettingsView`, `RaycastImportSelection`) — per `AGENTS.md`'s rule that a dialog's icon is
  always the subject's own glyph and that tone never picks an icon.
- **"Cancel" is no longer spelled at the call site.** `DialogController.confirm` supplies it as the
  built-in `.cancel` action, so the string disappears from the diff without the button disappearing. AC3
  is met by the controller, not by the call site.

---

## Deviations from the phase document

- **AC1 not met**, for the reason in Failed tasks. No file outside the brief was touched to chase it: the
  changed-file list is exactly `Tinycast/Core/AppCore.swift`.
- **`SnippetsSettingsView.swift` was not modified**, though the phase lists it as a possible second file.
  Dispatching the `Task` inside `AppCore` keeps `setSnippetsEnabled` synchronous, so the pane's `Binding`
  setter needed no change. The phase permits this explicitly ("or dispatches into a `Task`") and it is
  the smaller diff.
- **`NSApp.activate(ignoringOtherApps: true)` retained.** The phase allows removing it only if manual
  verification confirms the dialog still comes forward; the operator verified with it in place, so
  "if in doubt, keep it" applies. Removing it is untested and out of scope.
- **Commit size is +14/−12 against an expected +20/−18.** Under, not over — the `Cancel` button title and
  the `alertStyle` line are supplied by `DialogController` rather than restated.

---

## Follow-up work

| Observation                                                                                                                                                                                                                                                                                                                                 | Where                                                                                               | Suggested phase   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------- |
| `SnippetArgumentsPrompt.run` still uses `NSAlert` + `runModal` with an `NSHostingView` accessory. Reachable from a snippet expansion, i.e. potentially from a held hotkey — the exact stacking case the invariant exists to prevent, unlike the Settings-click-only site this phase fixed. Needs a `DialogController` form-field affordance | `Features/Snippets/SnippetArgumentsPrompt.swift`                                                    | new phase         |
| Three SwiftUI `.alert(item:)` deletion confirmations present system alerts that `grep NSAlert` does not catch — same invariant, different spelling                                                                                                                                                                                          | `SnippetsSettingsView.swift:54`, `CommandsSettingsView.swift:25`, `QuicklinksSettingsView.swift:41` | new phase         |
| AC1's grep matches comments, including one in a file the phase forbids touching, so the gate is unpassable as written                                                                                                                                                                                                                       | `phases/04-retire-the-last-nsalert.md`                                                              | doc fix, no phase |
| Phase 29 relocates `SnippetArgumentsPrompt` but does not convert it; nothing in the roadmap does                                                                                                                                                                                                                                            | `phases/29-feature-folders.md`                                                                      | doc fix, no phase |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes — one file, one hunk, no persistence and no state shape change.
- **Dependent phases that must also be reverted:** none
- **Data risk on revert:** none. `snippetsEnabled` is a plain `Bool` either way, so a user who enabled
  snippets before the revert keeps them enabled.

---

## Sign-off

- [ ] All acceptance criteria met — **AC1 excepted**, recorded above as a deviation with its reason
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
