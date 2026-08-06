# Phase 25b — The remaining palette-UI action coordinators

---

## Status

| Field                         | Value                                              |
| ----------------------------- | -------------------------------------------------- |
| **Status**                    | Complete                                           |
| **Started**                   | 2026-08-06                                         |
| **Completed**                 | 2026-08-06                                         |
| **Operator**                  | abue-ammar                                         |
| **Branch**                    | `refactor/25b-palette-action-coordinators`         |
| **Commit**                    | single commit on the branch                        |
| **Claude conversations used** | 1                                                  |
| **Actual effort**             | ~25 min vs. estimate of M (2–4 h)                  |

---

## Completed tasks

- [x] Objective 1 — `LauncherCoordinator`: `launch` (one method, one funnel), private `runCommand`,
      `resetRanking`, `showInFinder`, `quit`
- [x] Objective 2 — `ClipboardCoordinator`: `paste`, `pasteKeepingWindowOpen`, `copyToClipboard`,
      `revealClipboardImage`, `togglePinnedClip`, and private `selectClip` moved with them
- [x] Objective 3 — `EmojiCoordinator`: `pasteEmoji`, `copyEmoji`, `pasteEmojiKeepingWindowOpen`
- [x] Objective 4 — `CalculatorCoordinator`: `copyCalculatorResult`, `copyHistoryEntry`,
      `copyHistoryExpression`
- [x] Objective 5 — `setSnippetsEnabled` and `revealSnippetsInFinder` folded into
      `SnippetExpansionCoordinator`; no new type
- [x] `AppCore` constructs all four and retains a forwarder for every call site

## Acceptance criteria

- [x] AC1 — all four are `@MainActor` and reference no `AppCore.shared` — verified by:
      `grep -rn "AppCore.shared"` over the four new files plus `SnippetExpansionCoordinator` is empty
- [ ] **AC2 — `AppCore.swift` under ~560 lines — NOT MET: 618.** Unreachable while the phase's own
      "keep the forwarders" instruction stands. See *Deviations*
- [x] AC3 — `grep -c "DialogController()" Tinycast` is 1 — verified by: still `AppCore.swift` alone,
      and **no new façade was needed**, exactly as the phase predicted
- [x] AC4 — `PaletteWindowController` and `Paster` unchanged — verified by: both absent from
      `git status --short`
- [~] AC5 — every launcher activation works per kind — **structural**; `launch` is one method
      (`grep -c "func launch"` = 1) still dispatching on `app.kind`, all eight arms byte-identical
- [~] AC6 — clipboard actions land the selection on the row that moved — **structural**; `selectClip`
      moved with the actions and `togglePinnedClip`'s three-step order is byte-identical
- [~] AC7 — emoji frequency on the base glyph, tone at copy time — **structural**; three bodies
      byte-identical
- [~] AC8 — inline card records then copies; a history row re-copies without re-recording —
      **structural**; three bodies byte-identical
- [~] AC9 — snippets confirms before Accessibility — **structural**, but the sequence was diffed
      **order-preserved**, not just sorted. See *How the moves were verified*
- [x] AC10 — `palette-selection-test` unchanged in count — verified by: **111,684**, identical to the
      figure `progress/25` records

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                             |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` + **Debug and Release**, both exit 0. **0 compiler warnings against a 0 baseline** measured by a clean Debug build on this branch before any edit. Startup timing **not** measured |
| `checklists/testing.md`    | PASS   | **All 17 harnesses** via the `## Tests` fence, exit 0, no `FAIL` lines. All six phase gates included — `clipboard-test`, `ranking-test`, `calc-test`, `emoji-test`, `snippets-test`, `palette-selection-test` (111,684, unchanged) |
| `checklists/regression.md` | WAIVED | Operator waived interactive verification. **AC5–AC9 are therefore unexercised**, including all three runs the kickoff names by name — the pinned-clip highlight follow, the skin-toned emoji paste, and the consent-before-Accessibility ordering |
| `checklists/review.md`     | WAIVED | Operator waived                                                                                                                                                   |

### Hard gates

| Gate                                                          | Result                                                                    |
| ------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `launch` is still one method and one funnel                   | **yes** — `grep -c "func launch"` = 1, dispatch still reads `app.kind`     |
| `AppEntry.Kind` still the only category source                | **yes** — no entry ID is sniffed for a category anywhere in the diff       |
| `PaletteWindowController` in the diff                         | **absent** — `pasteKeepingWindowOpen` / `pasteStringKeepingWindowOpen` stay on it and the coordinators call them |
| `Paster.swift` in the diff                                    | **absent** — every pasteboard effect and the `internalType` marker stay put |
| `selectClip` + `followToken` moved with the clipboard actions  | **yes** — same file, and `togglePinned` → `selectClip` → `followToken = UUID()` byte-identical |
| `setSnippetsEnabled` ordering                                 | **byte-identical in order** — guard → early-return → `NSApp.activate` → `confirm` → set flag → `Permissions.ensureAccessibility()` |
| `grep -c "DialogController()" Tinycast`                       | **1** — still `AppCore.swift` alone; **no new façade needed**              |
| `AppCore.shared` in the five coordinator files                | empty                                                                     |
| `runWindowCommand`, the dialog façade and `start()` wiring    | **all still on `AppCore`** — no coordinator was created for any of them    |
| Files from **Files that must NOT change** in the diff          | none — `PaletteWindowController`, `Paster`, `AppLauncher`, `CommandRegistry`, `ClipboardStore`, `LauncherRankingStore`, `Core/Calculator/`, `Core/Emoji/`, `PaletteRowIndex`, `PaletteScreen`, `EdgeDissolve`, `ThinScrollbar` and the phase 24/25 coordinators other than `SnippetExpansionCoordinator` are all absent |

### How the moves were verified

`git diff -M` cannot pair these bodies while `AppCore.swift` still exists, so — as in phases 24 and 25 —
the pre-change blocks were extracted from `HEAD` and diffed line-by-line against the five destinations.
**All five are byte-identical with receivers normalized, and the diff was run order-preserving, not
sorted**, because sorting would hide exactly the reordering AC6 and AC9 exist to catch.

Every difference is a receiver rename or an access rewrite:

| Old                                        | New                                              |
| ------------------------------------------ | ------------------------------------------------ |
| `launcherRanking.`                         | `ranking.`                                       |
| bare `hidePalette` / `showPalette`         | `paletteCoordinator.`-prefixed                   |
| bare `showSettings` / `showBackupSettings` / `showAbout` | `paletteCoordinator.`-prefixed      |
| bare `runCustomCommand`                    | `customCommandCoordinator.runCustomCommand`      |
| bare `runSystemAction`                     | `systemActionCoordinator.runSystemAction`        |
| bare `runWindowCommand`                    | `core.runWindowCommand` — stays `AppCore`'s      |
| bare `editQuicklink` / `importQuicklinks` / `exportQuicklinks` | `quicklinkCoordinator.`-prefixed |
| bare `confirm` (snippets consent)          | `core.confirm`                                   |
| `snippetsStore.snippetsDirectory`          | `store.snippetsDirectory`                        |

No condition, no ordering, no string literal and no control-flow shape changed. The two sequences the
phase pins are intact:

- **`setSnippetsEnabled`**: guard on no-op → early-return on disable → `NSApp.activate` → `confirm`
  → `settings.snippetsEnabled = true` → `Permissions.ensureAccessibility()`. Consent still precedes
  the permission, and Accessibility is still requested only from this gesture.
- **`togglePinnedClip`**: `clipboardStore.togglePinned(item)` → `selectClip(item)` →
  `palette.followToken = UUID()`.

### Measurements

| Metric                      | Before  | After   | Δ                                                              |
| --------------------------- | ------- | ------- | -------------------------------------------------------------- |
| `AppCore.swift`             | 746     | **618** | **−128** (expected −195 — see *Deviations*)                    |
| `DialogController()` count  | 1       | 1       | 0 — no new façade                                              |
| Coordinators                | 6       | **10**  | +4                                                             |
| `AppCore` properties        | —       | —       | +4 coordinators, as budgeted                                   |
| Compiler warnings (Debug)   | 0       | 0       | 0                                                              |
| Harness count               | 17      | 17      | 0                                                              |
| `palette-selection-test`    | 111,684 | 111,684 | 0 — this phase adds no rows                                    |
| Diff size                   | —       | —       | 6 files, +350 / −164 (expected 6 files, +290 / −230)           |
| Binary size (Release)       | —       | —       | not measured                                                   |
| Clean install verified?     | —       | n-a     | no persisted state changes shape                               |

New file sizes: `LauncherCoordinator` 145, `ClipboardCoordinator` 62, `EmojiCoordinator` 40,
`CalculatorCoordinator` 32. The sixth file is `Tinycast.xcodeproj/project.pbxproj`, regenerated for the
four new sources, which `build.md` explicitly permits.

---

## Failed tasks

None.

---

## Issues encountered

**Three file-header comments I wrote exceeded the 100-character cap** (104, 106 and 109) and were
shortened before the final build. The four over-length comments that remain in the new files are all
moved verbatim from `HEAD`, which the standing contract requires ("if you move code, move its comment
unchanged") — including the one two-line block inside `launch`, so **no stacked block was added**.

**No new façade was needed, as the phase predicted.** None of the moved methods reaches `dialogs` or
`messageHUD` except the snippets consent gate, which goes through the existing `core.confirm`. This is
the first coordinator phase since 24 that did not force one.

---

## Deviations from the phase document

- **AC2 is unreachable, and the phase document disagrees with itself — the same failure mode as 25.**
  AC2 asks for "under ~560 lines"; the same document's *Expected commit size* budgets "`AppCore` net
  −195", which from 746 lands at 551. But the phase **also** mandates "Keep `AppCore` forwarders. Phase
  32 deletes them", and the 17 new forwarders (~51 lines) plus the 4 property declarations (~12) come
  straight back, so the achievable delta is −128, not −195. The file sits at **618**. What remains:

  | Block                                                                          | Lines | Owner                                |
  | ------------------------------------------------------------------------------ | ----- | ------------------------------------ |
  | `PaletteMode`, `PasteTarget`, `PaletteViewModel` — not `AppCore` at all         | ~99   | **phase 28** extracts them by name   |
  | 48 forwarders kept by this phase's own instruction                              | ~144  | **phase 32** deletes them            |
  | Ownership, `init`, `start()`, `prepareForTermination`, feature-switch tracking  | ~160  | stays — this is the composition root |
  | Dialog façade                                                                  | ~50   | stays                                |
  | `runWindowCommand` + `applyWindowCommandsPresence` — the phase says leave them  | ~25   | stays                                |

  **There is no "no phase owns this" row this time.** That row is what `progress/25` filed and what this
  phase existed to clear. Excluding the two rows another phase already claims by name, `AppCore` is
  ~375 lines of composition root; the class body alone (excluding the three palette types) is 518.

- **`SnippetExpansionCoordinator` now has two paths to `AppCore`.** `setSnippetsEnabled` needs
  `confirm`, whose six arguments make a closure clumsy, so the type gained `private unowned let core`
  — abandoning the "holds no `AppCore` reference at all" shape `progress/24` records as deliberate.
  Phase 24's `showMessage` closure was **left in place** so every phase-24 body stays byte-identical;
  consolidating onto `core.showMessage` would have edited `completeSnippetExpansion`, which this phase
  does not own. Worth resolving in 29 or 32.

- **`LauncherCoordinator` is injected with four sibling coordinators** rather than reaching them through
  `AppCore`'s forwarders. This keeps the wiring honest — those forwarders are phase 32's to delete — and
  matches how 25 injected `paletteCoordinator` into three coordinators. `core` is retained for
  `runWindowCommand` alone, which the phase says is permanently `AppCore`'s.

---

## Follow-up work

| Observation                                                                                                                                                                                                                       | Where                                   | Suggested phase |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- | --------------- |
| **Phase 29's feature table must now name the four new coordinator files** under Launcher, Clipboard, Emoji and Calculator. The asymmetry `phases/25b` describes is closed, so the table is simply out of date                        | `phases/29-*.md`                        | **29**          |
| **Phase 32 can now do its stated job**: every call site has an owning coordinator to be pointed at, and the 48 forwarders on `AppCore` are all genuinely forwarders                                                                  | `AppCore.swift` + call sites            | **32**          |
| `SnippetExpansionCoordinator` reaches `AppCore` two ways (`unowned core` and the `showMessage` closure). Collapse onto one when that file is next in scope                                                                           | `SnippetExpansionCoordinator.swift`     | **29** or **32** |
| The calculator and clipboard forwarders sit under `// MARK: - Uninstall` in `AppCore`. **Pre-existing** — in `HEAD` they were already there, separated only by the private `runCommand` this phase removed. Left alone per the no-opportunistic-fixes rule | `AppCore.swift`                         | **28** or **32** |
| Phase 28 moves `AppCore.swift` wholesale and phase 26 is next; both diffs are now honest moves rather than moves-plus-extractions, which is why 25b ran first                                                                        | `AppCore.swift`                         | **26**, **28**  |
| Startup timing still unmeasured, and four more coordinators now instantiate lazily during `start()`. All four are plain property-storing `init`s, so no real work moved onto the launch path — but the measurement `progress/24` and `progress/25` both deferred is still owed | `AppCore` `init` / `start()`            | **34**          |
| Interactive regression waived — AC5–AC9 unexercised, including the three runs the kickoff names                                                                                                                                      | launcher / clipboard / emoji / snippets | before merge    |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. The four coordinator files disappear, `AppCore` regains the
  five blocks verbatim, and `SnippetExpansionCoordinator` loses its `core` reference and the two folded
  methods. Re-run `xcodegen generate` afterwards. No persisted state changes shape and no stored format
  is involved.
- **Dependent phases that must also be reverted:** none yet. Phases 29 and 32 depend on this one, so a
  revert must happen before either lands.
- **Data risk on revert:** none.

---

## M4 Definition of Done

**Now literally true.** `AppCore` owns no feature orchestration: the palette-UI action methods sit with
their features, and what remains is ownership, `init`/`start()` wiring, `prepareForTermination`,
feature-switch tracking, the dialog façade, `runWindowCommand`, the forwarders phase 32 deletes and the
three palette types phase 28 extracts. M4's line-count target of "~550" is met for the class body (518)
but not the file (618), the difference being those two already-claimed blocks.
