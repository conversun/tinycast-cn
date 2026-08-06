# Phase 29 — Feature folders and the Settings shell

**Milestone:** M5 · **Effort:** L · **Risk:** Low · **Context:** High

---

## Overview

The last and largest set of moves: co-locate each feature's pure layer, effect layer, UI and Settings
pane under `Features/<Name>/`, leaving `Settings/` as a shell. Thirteen features, ~15 harness command
lines to update.

## Why this phase exists

This is the phase that actually fixes H-5. Today "Quicklinks" is 6 files in `Core/Quicklinks/`, 2 in
`Features/Quicklinks/`, 2 in `Features/Settings/`, plus slices in eight shared files. Phases 23–26
removed the shared-file slices; this one co-locates what remains.

## Architecture Review reference

**M-1**, **M-8**, **H-5** · §4.2

## Objectives

1. Create `Features/<Name>/{Model,Service,UI,Settings}/` for the thirteen features.
2. Move each feature's files in.
3. Reduce `Settings/` to the shell — `SettingsRootView.swift`, `SettingsTab.swift`, `AppSettings.swift`
   — plus `Panes/` for the two panes that belong to no feature.
4. Update every affected harness command line.
5. Leave `Tinycast/Core/` deleted, not thinned.

## Target layout

| Feature              | Model (pure)                                                                             | Service (effects)                                                                                                             | UI                                                                                           | Settings                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Launcher**         | `AppEntry`, `SearchRelevance`, `SearchScopes`, `LauncherRankingStore`, `CommandRegistry` | `AppIndex`, `AppLauncher`, `SpotlightNames`, `SettingsPaneScanner`, `FavoritesStore`, `VisibilityStore`, `RunningAppsMonitor` | `LauncherCoordinator`, `LauncherScreen`, `LauncherList`, `SectionHeader`, `AppRow`, `AppIconView`, `AppActionsMenu` | `ApplicationsSettingsView`, `SystemSettingsSettingsView`, `LauncherItemsCard`, `SearchScopesCard` |
| **Clipboard**        | `ClipboardStore`                                                                         | `ClipboardManager`, `Paster`                                                                                                  | `ClipboardCoordinator`, `ClipboardScreen`, `ClipboardList`, `ClipboardPreview`, `ClipboardActionsMenu`               | `ClipboardSettingsView`, `AppPickerPopover`                                                       |
| **Calculator**       | `Calculator/*`, `CurrencyData.generated`                                                 | `CurrencyRateStore`, `CalculatorHistoryStore`                                                                                 | `CalculatorCoordinator`, `CalculatorHistoryScreen`, `CalculatorCardView`                                              | `MiscellaneousSettingsView` — see below                                                           |
| **Emoji**            | `EmojiCatalog`, `EmojiGridGeometry`, `EmojiData.generated`                               | `EmojiIndex`, `FrequentEmojiStore`                                                                                            | `EmojiCoordinator`, `EmojiScreen`                                                                                | `EmojiSettingsView`                                                                               |
| **Quicklinks**       | `Quicklink`, `QuicklinkDestination`, `QuicklinkStore`, `QuicklinkArchive`                | `QuicklinkLauncher`, `QuicklinkArgumentSession`                                                                               | screens + `QuicklinkCoordinator`                                                             | `QuicklinksSettingsView`, `QuicklinkEditorSheet`                                                  |
| **Snippets**         | `Snippets/*` pure                                                                        | `SnippetTextInjector`, `SnippetKeywordListener`                                                                               | `SnippetArgumentsPrompt` + coordinator                                                       | `SnippetsSettingsView`                                                                            |
| **WindowManagement** | `WindowCommand`, `WindowLayout`, `WindowActionMemory`                                    | `WindowMover`                                                                                                                 | —                                                                                            | `WindowManagementSettingsView`                                                                    |
| **Uninstall**        | 5 pure files                                                                             | `UninstallScanner`, `UninstallRunner`, `UninstallSession`                                                                     | `UninstallScreen` + coordinator                                                              | —                                                                                                 |
| **SystemActions**    | `SystemAction`, `VolumeLevel`                                                            | `SystemActionRunner`, `VolumeState`                                                                                           | coordinator                                                                                  | `SystemActionsSettingsView`                                                                       |
| **CustomCommands**   | `CustomCommand`                                                                          | `ShellCommandRunner`                                                                                                          | coordinator                                                                                  | `CommandsSettingsView`, `CustomCommandEditorSheet`                                                |
| **HotKeys**          | `KeyShortcut`, `HotKeyBinding`, `HyperKey`, `DoubleTapModifier`, `DoubleTapDetector`     | `HotKeyCenter`, `HotKeyManager`, `DoubleTapMonitor`, `HyperKeyTap`, `ShortcutCaptureSession`                                  | `ShortcutRecorder`, `ShortcutRecorderPopover`, `CalloutShape`, `CalloutPlacement`            | —                                                                                                 |
| **Backup**           | `SettingsBackup`, `Raycast*`                                                             | `BackupActions`, `Scrypt`, `Gunzip`                                                                                           | —                                                                                            | `BackupSettingsView`, `RaycastImportSelection`                                                    |
| **Onboarding**       | `OnboardingState`                                                                        | —                                                                                                                             | `OnboardingView`                                                                             | —                                                                                                 |

Also: `Core/HealthTicker.swift` and `Core/Memo.swift` → `Platform/`. (`Core/Signposts.swift` and
`Core/AppPaths.swift` already went to `Platform/` in phase 27.)

The five mode views that phases 20–23 wrapped in a `…Screen` still exist and go to their feature's
`UI/` alongside it, keeping their names — `CalculatorHistoryView`, `EmojiGridView`,
`QuicklinkArgumentsView`, `QuicklinkListView`, `UninstallView`. A screen is the `PaletteScreen`
conformance; the view is what it renders. Two types, two files, both in `UI/`.

### The files with no feature owner

Three Settings panes belong to no feature in the table above, and §4.2 did not place them. They are
placed here, and this rule is what makes the placement decidable:

> **A pane lives with its feature. A pane that has no feature lives in `Settings/Panes/`.**

| Pane                        | Home                            | Why                                                                       |
| --------------------------- | ------------------------------- | ------------------------------------------------------------------------- |
| `GeneralSettingsView`       | `Settings/Panes/`               | Global shortcuts, search, Hyper key, appearance — five features, no owner |
| `PermissionsSettingsView`   | `Settings/Panes/`               | App-level permission state, not one feature's                             |
| `MiscellaneousSettingsView` | `Features/Calculator/Settings/` | Contains **only** the Calculator card and the currency-consent sheet      |

`MiscellaneousSettingsView` moves under its real owner here and is **renamed** `CalculatorSettingsView`
in phase 30 — this phase renames no type. Its `SettingsTab` case stays `.miscellaneous`; that raw value
is a persisted `CommandID`, and there is no reason to orphan those records for a filename.

### Permitted verbatim splits

Phase 29 is otherwise 100 % moves, but three files each declare several top-level views and so have no
single correct destination filename. Splitting them is **cut-and-paste with zero content change** —
every declaration lands byte-identical in a file named for it, in declaration order:

| File                                       | Splits into                                                                                                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Features/Launcher/LauncherView.swift`     | `LauncherList.swift` · `SectionHeader.swift` · `AppRow.swift` · `AppIconView.swift` · `AppActionsMenu.swift`                                                  |
| `Features/Clipboard/ClipboardView.swift`   | `ClipboardList.swift` (+ `DateBucket`, `ClipboardRow`, `AsyncThumbnail`) · `ClipboardActionsMenu.swift` · `ClipboardPreview.swift` (+ `ClipboardInfoSection`) |
| `Features/Settings/SettingsRootView.swift` | `SettingsRootView.swift` (keeps `SidebarRow` and the `Notification.Name` extension) · `SettingsTab.swift`                                                     |

A `private` type moves into the file of the one type that uses it and stays `private`. If the compiler
demands a wider access level anywhere, the split is wrong — put it back and say so, do not widen.

**The rule this encodes, for every future file:** one top-level `View` or namespace enum per file, named
for it. That is what keeps `Features/` navigable at fifty features instead of thirteen.

## Files that must NOT change (contents)

- **Every moved file.** This phase is moves, plus three cut-and-paste splits that change no byte of any
  declaration.
- `EdgeDissolve.swift`, `ThinScrollbar.swift` — already in `DesignSystem/Scrolling/`, untouched again

## Implementation boundaries

- **One feature per commit, on one branch.** Thirteen small commits are far easier to bisect than one
  giant move, and `git` follows renames either way.
- **~15 harness command lines change.** Every harness in `checklists/testing.md` except
  `palette-selection-test` names at least one moving file. Update `docs/development.md` **and**
  `AGENTS.md` **and** `checklists/testing.md` in the same commit as each feature's move.
- **`AGENTS.md`'s Critical Invariants section names file paths throughout.** Every one of those paths
  must be updated in this phase. Read the whole section and fix every reference — a stale invariant is
  worse than none.
- Do not rename any type. Phase 30.
- Do not merge or edit any file. **The only splits permitted are the three enumerated above** — and each
  is cut-and-paste: no reordering, no reformatting, no "while I'm here".
- **File renames that make a filename match the type it declares are in scope**, since the file is moving
  anyway and the rename is free: `RunningApps.swift` → `RunningAppsMonitor.swift`. That is a _file_
  rename; the type is untouched.
- Do not create `Features/<Name>/` subfolders for a feature that has only one or two files — Onboarding
  and WindowManagement do not need four empty directories. Use judgement; the layer split is for
  features large enough to benefit.
- Run `xcodegen generate` after each feature and commit the project file with it.

## Detailed acceptance criteria

1. Every file is at its target path.
2. `git diff -M --stat` shows 100 % similarity for every move. The three split files are the only
   exception, and for those the **concatenation** of the new files must equal the old file's
   declarations exactly — verify with `git show HEAD~1:<old path>` and a diff of the sorted bodies.
3. All 17 harness command lines updated in all three places (`docs/development.md`, `AGENTS.md`,
   `checklists/testing.md`) and all 17 pass.
4. Every file path referenced in `AGENTS.md`'s Critical Invariants section is correct.
5. `Settings/` contains exactly `SettingsRootView.swift`, `SettingsTab.swift`, `AppSettings.swift` and
   `Panes/` — and `Panes/` contains exactly `GeneralSettingsView.swift` and
   `PermissionsSettingsView.swift`.
6. **`Tinycast/Core/` no longer exists.** Every file has a home in this phase or an earlier one; if a
   file appears to have none, that is a gap in this document — say so rather than inventing a
   `Core/` remainder.
7. No file declares more than one top-level `View` or namespace enum, except where it already did before
   this phase and is not in the split list.
8. Debug and Release builds succeed; UI pixel-identical.

## Manual verification checklist

- [ ] `checklists/build.md` including the **Release build**
- [ ] `checklists/testing.md` — **all 17**, using the updated command lines, copy-pasted fresh from
      `docs/development.md` to prove that file is correct
- [ ] `checklists/regression.md` — **the full document**
- [ ] Read `AGENTS.md`'s Critical Invariants section end to end; every path resolves
- [ ] `grep -rn "Tinycast/Core/" docs/ AGENTS.md` → only intentional historical references remain
- [ ] `ls Tinycast/Core` → no such directory
- [ ] Walk **all 14 Settings panes** — the sidebar order, each pane's cards and the palette's
      `Settings ▸ <pane>` entries are all unchanged (this is the phase that moves every pane file)
- [ ] Screenshot the palette and two Settings panes before/after → pixel-identical
- [ ] `xcodegen generate` twice → stable

## Regression risks

| Risk                                                                                       | Mitigation                                                             |
| ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| **A harness command line is missed** → red suite, possibly not noticed until a later phase | AC3; copy-paste the block fresh from `docs/development.md`             |
| `AGENTS.md` invariants point at dead paths → the contract silently rots                    | AC4; read the whole section                                            |
| A single giant commit makes a partial revert impossible                                    | Boundary: one feature per commit                                       |
| Access-control breakage after a move                                                       | Compiler catches it; do not widen beyond `internal`                    |
| A file lands in the wrong layer (an effect file under `Model/`)                            | Reviewer checks imports: a `Model/` file importing AppKit is misplaced |

## Rollback strategy

`git revert` the specific feature's commit. That is why this is thirteen commits rather than one.

## Expected commit size

~110 files moved across ~13 commits, plus one commit for the Settings shell and its two orphan panes.
Content delta zero — the three splits redistribute bytes without changing any.

## Suggested commit message

Per feature, e.g.:

```
Move the Quicklinks feature into Features/Quicklinks/

Model (pure, harness-compiled), Service (effects), UI and Settings under
one folder. Harness command lines updated in docs/development.md and
AGENTS.md. Contents unchanged.
```

## Dependencies

**Phase 28 (hard).** Blocks 30, 31, 32.

## Definition of Done

- All acceptance criteria met
- All 17 harnesses green from freshly copy-pasted command lines
- `AGENTS.md` invariant paths all correct
- Merged

## Estimated difficulty

**Medium** per feature, **High** in aggregate. Tedious rather than hard.

## Estimated Claude context usage

**High.** Do it in thirteen conversations if needed — one per feature — rather than one long one.

## Notes for reviewers

- **The `AGENTS.md` path audit is the part that gets skipped and the part that matters most.** That file
  is the project contract; every stale path in it makes the contract less trustworthy for the next
  contributor and the next agent.
- Copy the harness block out of `docs/development.md` and run it verbatim. If it works, that file is
  correct — which is the only way to be sure.
- Check the layer placement by imports: anything in a `Model/` folder importing AppKit or SwiftUI is in
  the wrong layer, and the `Tools/` harness for that feature will tell you.
- Similarity must be 100 % everywhere except the three enumerated splits. For those, read the diff as a
  redistribution: every `+` line must have a matching `-` line in the same commit.
- **`Core/` must be gone, not small.** A leftover `Core/` with two files in it is how a flat namespace
  grows back — the next contributor with a homeless file puts it there, and in a year it is forty again.
