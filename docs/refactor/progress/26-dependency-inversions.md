# Phase 26 — Fix the three dependency inversions

---

## Status

| Field                         | Value                                 |
| ----------------------------- | ------------------------------------- |
| **Status**                    | Complete                              |
| **Started**                   | 2026-08-06                            |
| **Completed**                 | 2026-08-06                            |
| **Operator**                  | abue-ammar                            |
| **Branch**                    | `refactor/26-dependency-inversions`   |
| **Commit**                    | single commit on the branch           |
| **Claude conversations used** | 1                                     |
| **Actual effort**             | ~15 min vs. estimate of M (2–4 h)     |

---

## Completed tasks

- [x] Objective 1 — `HotKeyManager.displayName` is an injected `((HotKeyAction) -> String?)?`; the four
      store-backed cases call it, the five static-catalog cases still resolve in the manager
- [x] Objective 2 — `KeyShortcut.collapsedModifierSymbols(from:hyperKey:replacesGlyph:includesShift:)`
      is pure, non-`@MainActor`, and reads no global state
- [x] Objective 3 — `SystemActionRunner.onAsyncFailure` replaces the `AppCore.shared` reach inside the
      `openApplication` completion handler
- [x] `AppCore.start()` wires all three, once, next to the existing `hotKeys.on*` block

## Acceptance criteria

- [ ] **AC1 — `grep -rn "AppCore.shared" Tinycast/Core` empty — NOT MET.** All three named sites are
      gone; six references remain in `Core/Backup/BackupActions.swift`, a **fourth** inversion this
      phase never names. Scope confirmed with the operator before implementing. See *Deviations*
- [x] AC2 — no protocol introduced — verified by: `git diff | grep protocol` is empty; all three
      injections are closures
- [x] AC3 — `collapsedModifierSymbols` is pure — verified by: four value parameters, `@MainActor`
      dropped, no `AppCore` / `AppSettings` / static read in the body
- [~] AC4 — the conflict message names all six owner kinds — **structural.** Both switches are
      exhaustive with no `default`, so a resolver wired for four of six is a **compile error**, not a
      silent gap; every fallback string (`bundleID`, `"Custom Command"`, `"Quicklink"`) is preserved
      verbatim. The six-owner sweep needs keystrokes into Settings and was **not run**
- [~] AC5 — ✦ collapse identical in launcher rows, Settings recorders and the callout — **structural.**
      All three sites reach the same pure function through the same injected closure
- [~] AC6 — turning "Replace with ✦" off restores the full glyphs — **structural.** The injection is a
      **closure, not a snapshot**, so a Settings toggle still re-renders every keycap; see *Deviations*
- [~] AC7 — a screen-saver launch failure still surfaces its dialog — **by inspection.** Not triggerable
      without deleting a system file, which the phase's own checklist anticipates
- [x] AC8 — `start()` wires all three, once — verified by: three consecutive assignments at
      `AppCore.swift:243`, none of them in a loop, a callback or a re-armed observation

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                     |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + **Debug and Release**, both exit 0, **0 warnings against a 0 baseline**. `project.pbxproj` is unchanged — this phase adds no files. Startup timing **not** measured |
| `checklists/testing.md`    | PARTIAL | The **three harnesses the phase names as gates** — `hotkey-test` (34), `callout-test` (30), `system-action-test` (78) — all exit 0 with unchanged command lines. The other 14 were **not** run at the operator's instruction; none compiles a file in this diff |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC4–AC7 are therefore unexercised**, including the six-owner conflict sweep the kickoff calls the one check that catches a partially-wired resolver |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                                                                                           |

### Hard gates

| Gate                                                       | Result                                                                                          |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Closures, not protocols                                    | **held** — three closures; `grep protocol` over the diff is empty                                |
| `displayName`'s resolver is as narrow as possible          | **held** — `(HotKeyAction) -> String?`, returning `nil` for all five catalog cases               |
| `HotKeyManager` keeps its static-catalog fallbacks         | **held** — `.togglePalette`, `.toggleClipboard`, `.toggleEmoji`, `.systemAction`, `.windowCommand` never consult the resolver |
| `collapsedModifierSymbols` produces the same glyphs        | **held** — the ✦ collapse still keys on configuration, and leftovers keep canonical order after it |
| `SystemActionRunner`'s `Task { @MainActor in … }` retained | **held** — only the destination inside it changed                                                |
| No file made harness-compiled                              | **held** — no harness command line changed                                                       |
| `HotKeyManager.capture` / `doubleTapMonitor` stay `let`    | **held** — both absent from the diff                                                             |
| Files from **Files that must NOT change** in the diff      | none — `HotKeyBinding`, `HotKeyCenter`, `DoubleTapMonitor`, `SystemAction`, `AppIndex`, `CustomCommand`, `QuicklinkStore` and every phase 24/25/25b coordinator are all absent |

### How behaviour was held constant

`HotKeyManager.displayName(of:)` keeps its fallbacks, so each of the four store-backed cases composes to
exactly the pre-change expression:

| Case             | Before                                                  | After                                             |
| ---------------- | ------------------------------------------------------- | ------------------------------------------------- |
| `.app`           | `apps.first { .application && id }?.name ?? bundleID`   | resolver (same lookup) `?? bundleID`              |
| `.settingsPane`  | `apps.first { .systemSettings && id }?.name ?? bundleID`| resolver (same lookup) `?? bundleID`              |
| `.customCommand` | `customCommands.command(id:)?.name ?? "Custom Command"` | resolver `?? "Custom Command"`                    |
| `.quicklink`     | `quicklinks.quicklink(id:)?.name ?? "Quicklink"`        | resolver `?? "Quicklink"`                         |

`.app` and `.settingsPane` now share one `case` arm in the manager because both fall back to `bundleID`;
the **kind filter that distinguishes them moved intact** into `AppCore.hotKeyDisplayName(for:)`, which
switches on the same nine cases with no `default`.

For the ✦ collapse, `KeyShortcut.hyperDisplay` is a **closure evaluated per read**, not a value captured
at `start()`. `AppSettings` is `@Observable` (phase 16), and Observation records an access anywhere in
the synchronous call stack of a `body`, so reading the three preferences through the closure registers
the same dependency the direct `AppCore.shared.settings` read used to. A snapshot would have frozen the
glyphs at launch and silently failed AC6.

### Measurements

| Metric                                  | Before | After  | Δ                                                       |
| --------------------------------------- | ------ | ------ | -------------------------------------------------------- |
| `AppCore.shared` in `Tinycast/Core`     | 12     | **6**  | **−6** — every reference the three inversions held       |
| `AppCore.shared` tree-wide              | 52     | **46** | −6 — all six removals are in `Core/`                     |
| Files still holding `AppCore.shared`    | 23     | **20** | −3 — the three inverted files now hold none              |
| `AppCore.swift`                         | 618    | 642    | +24 — the wiring plus `hotKeyDisplayName(for:)`          |
| `HotKeyManager.swift`                   | 239    | 235    | −4                                                        |
| Compiler warnings (Debug / Release)     | 0      | 0      | 0                                                         |
| Harness count                           | 17     | 17     | 0 — no file became harness-compiled, by instruction      |
| Diff size                               | —      | —      | **5 files, +60 / −22** (expected 5 files, +60 / −45)     |
| Binary size (Release)                   | —      | —      | not measured                                              |
| Clean install verified?                 | —      | n-a    | no persisted state, key or format changes                |

---

## Failed tasks

None.

---

## Issues encountered

**Four doc comments I wrote exceeded the 100-character cap** (114–155) and were shortened before the
final Debug build. No comment was moved, so nothing inherited an over-length line, and no stacked block
was added. The longest added line in the final diff is 98 characters.

**The Release build ran before that shortening**, Debug after; the intervening edit was comment text
only.

---

## Deviations from the phase document

- **AC1 cannot be met inside this phase's scope, and the phase document does not know it.** The phase
  title, its objectives, and `architecture-review.md` §2.3 all say *three* inversions —
  `HotKeyManager:162,166,170,176`, `KeyShortcut:49`, `SystemActionRunner:69`. All three are gone. But
  `Core/Backup/BackupActions.swift` holds **six more**, and it is named nowhere in the phase: not in
  *Expected files to modify*, not in *Files that must NOT change*. It postdates the review section AC1
  was written from, which is why the review counts three.

  ```
  Tinycast/Core/Backup/BackupActions.swift:83:    if AppCore.shared.settings.snippetsEnabled {
  Tinycast/Core/Backup/BackupActions.swift:84:        await AppCore.shared.snippetsStore.start()
  Tinycast/Core/Backup/BackupActions.swift:87:        try await AppCore.shared.snippetsStore.importSnippets(result.snippets).count
  Tinycast/Core/Backup/BackupActions.swift:95:    ? 0 : AppCore.shared.clipboardStore.importEntries(result.clipboard)
  Tinycast/Core/Backup/BackupActions.swift:161:   return await AppCore.shared.confirm(
  Tinycast/Core/Backup/BackupActions.swift:181:   await AppCore.shared.showNotice(
  ```

  Two of the six are the `confirm` / `showNotice` façade that phases 24, 25 and 25b **deliberately kept**
  in every coordinator, so inverting `BackupActions` is a design decision about the façade, not a
  mechanical fix — and it would land in a file this phase was not scoped to open. Operator chose the
  three-sites-only scope explicitly. Phase 29's feature table already claims `BackupActions` for a
  Backup folder.

- **`collapsedModifierSymbols` needed a fourth argument.** The phase writes
  `(from:hyperKey:replacesGlyph:)`, but the ✦ set is `[.control, .option, .shift, .command]` or
  `[.control, .option, .command]` depending on `hyperKeyIncludesShift`. With only the two documented
  parameters the function cannot reproduce what it produced before, which the same phase forbids. The
  shipped signature is `(from:hyperKey:replacesGlyph:includesShift:)`.

- **`keycaps` takes the preference from an injected static closure, not from parameters.**
  `HotKeyBinding.keycaps` calls `shortcut.keycaps` as a **property**, and `HotKey/HotKeyBinding.swift`
  is in *Files that must NOT change* — so `KeyShortcut.keycaps` cannot grow parameters, and the five
  view call sites (`ShortcutRecorder`, `LauncherView`, `QuicklinkListView`, `OnboardingView`,
  `ShortcutRecorderPopover`) stay untouched. `KeyShortcut.hyperDisplay` is therefore one
  `@MainActor static var` closure set once in `start()` — literally what the hard gate asks for ("one
  closure property … set once in `AppCore.start()`"), just on a value type, where `static` is the only
  place to put it. Its default `(.none, false, true)` is the **no-collapse** state, so a build that
  forgot to wire it would render full glyphs rather than wrong ones.

- **The resolver's four store lookups live in `AppCore`, in a private helper rather than inline in
  `start()`.** A four-case switch inside the wiring closure would have been the only alternative;
  neither adds a type, and this keeps `start()` reading as wiring.

---

## Follow-up work

| Observation                                                                                                                                                                        | Where                          | Suggested phase |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------ | --------------- |
| **`BackupActions` is a fourth `Core → AppCore.shared` inversion.** Its four store reads invert cleanly; its two façade calls are the same `confirm`/`showNotice` shape every coordinator keeps, so decide the façade question once and apply it there | `Core/Backup/BackupActions.swift` | **29** or **32** |
| AC1's grep is worth re-running after 29 moves `BackupActions` out of `Core/` — at that point it goes empty for free, and the criterion becomes true rather than waived                | `Tinycast/Core`                | **29**          |
| The six-owner conflict sweep and the three-site ✦ check were both waived. Neither is expensive; both are the only things that catch a partially-wired resolver or a frozen preference | Settings recorders             | before merge    |
| `AppCore.presentSystemActionFailure` is now reached only by the injected callback and the coordinator; it is a pure forwarder                                                        | `AppCore.swift`                | **32**          |
| Startup timing still unmeasured — three closure assignments were added to `start()`, none of which does work                                                                          | `AppCore.start()`              | **34**          |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory wiring only: the three injected members disappear and
  the three call sites go back to reading `AppCore.shared`. No `xcodegen` re-run is needed — the project
  file is unchanged.
- **Dependent phases that must also be reverted:** none. Phase 27 depends on this one, so a revert must
  happen before 27 lands.
- **Data risk on revert:** none. No persisted key, path or format is involved.

---

## Does this block phase 27?

**No.** Phase 27 extracts `DesignSystem/` and `Platform/` — a file-move phase. Everything it depends on
from 26 is delivered: the three inversions are gone, so `HotKeyManager`, `KeyShortcut` and
`SystemActionRunner` can be moved between folders without dragging `AppCore` behind them. The one unmet
criterion (AC1's grep) concerns `BackupActions`, which 27 does not touch and 29 relocates anyway. M4
closes here; the natural stop point after 26 that the roadmap names is intact.
