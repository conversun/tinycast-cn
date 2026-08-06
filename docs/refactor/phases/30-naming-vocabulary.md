# Phase 30 — Naming vocabulary

**Milestone:** M6 · **Effort:** S · **Risk:** Low · **Context:** Low

> **Compatibility policy applies.** See [`../POLICY.md`](../POLICY.md). Nothing in this phase needs the
> carve-outs: no persisted key, raw value or column name is touched.

---

## Overview

Write the suffix vocabulary into `AGENTS.md` so it holds, and apply the two renames needed to make that
table true. Two type renames, two file renames, no logic changes.

## Why this phase exists

Roughly twenty competing suffixes are in use — `Manager`, `Service`, `Store`, `Index`, `Session`,
`Controller`, `Registry`, `Catalog`, `Runner`, `Monitor`, `Center`, `Presenter`, `Repository`,
`Scanner`, `Policy`, `Engine`, `Injector`, `Launcher`, `Mover`, `Tap`, `ViewModel`. **Most carry real
meaning and are already used consistently.** The problem is not the count; it is that no rule is
written down, so nothing stops the twenty-first.

The deliverable is therefore the **table**, not a rename campaign. A suffix earns a row by describing
what the type does; the two renames below exist only because those two names describe something the
code does not do.

## Architecture Review reference

**L-3, L-4, L-5, L-10** · §4.1 naming vocabulary

## Objectives

1. Apply two renames.
2. Write the suffix table into `AGENTS.md`, including its exceptions.
3. Change nothing else.

## Renames

| Today                  | Becomes                                       | Why                                                                                                                                                                                         |
| ---------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CommandRegistry`      | `CommandCatalog`                              | It is a static namespace over a built-in list, exactly like `SystemActionCatalog`, `WindowCommandCatalog` and `EmojiCatalog`. "Registry" implies runtime registration, which never happens. |
| `PaletteViewModel`     | `PaletteState`                                | It is shared app state read by the window controller and the panel, not a per-view VM                                                                                                       |
| `Bundle+AppName.swift` | already `AppDisplayName.swift` (phase 27)     | Concept-named, like `CursorScreen.swift`                                                                                                                                                    |
| `RunningApps.swift`    | already `RunningAppsMonitor.swift` (phase 29) | Filename matches the type it declares                                                                                                                                                       |

Between them these retire two suffixes outright: after this phase `git grep` finds **zero** `Registry`
and **zero** `ViewModel`.

## Renames explicitly NOT in this phase

Three renames were proposed and cut. Do not apply them, and do not reintroduce them as "while I'm here":

- **`ClipboardManager` → `ClipboardMonitor`.** It polls, but it also owns the capture _policy_
  (`sensitiveTypes`, `maxTextLength`, `internalType`, the disabled-apps filter) and the paste-side
  handshake (`prepareForTinycastPasteboardMutation` / `synchronizeAfterTinycastPasteboardMutation`).
  The codebase's other Monitors — `RunningAppsMonitor`, `DoubleTapMonitor` — are pure listeners that
  own no policy. `Manager` is the accurate word; it gets a row in the table instead.
- **`HotKeyManager` → `HotKeyBindings`.** A plural noun reads as a collection, but the type is an
  active coordinator (`start`, `setBinding`, `conflictOwner`, `perform`, prune/persist) driving both
  `HotKeyCenter` and `DoubleTapMonitor`. Worse, `HotKeyBinding` (singular) is an existing model type
  spelled throughout the same file — `[HotKeyAction: HotKeyBinding]`, `binding(for:) -> HotKeyBinding?`
  — so the two would differ by one trailing character in shared context.
- **`MiscellaneousSettingsView` → `CalculatorSettingsView`.** `SettingsTab.miscellaneous` keeps its
  case name, its raw value, its `"Miscellaneous"` title and its `ellipsis.circle` icon, so renaming
  only the view makes the file disagree with four things that stay. The pane is also expected to grow
  cards beyond Calculator. The genuine defect here is **placement, not naming** — phase 29 filed it
  under `Features/Calculator/Settings/`, but a pane no single feature owns belongs in
  `Features/Settings/Panes/` beside General and Permissions. That is a file move, which this phase
  forbids; it is tracked separately.

## Expected files to modify

Every file referencing a renamed type — 16 — plus `AGENTS.md`.

- `CommandRegistry` — 3 files (`CommandRegistry.swift`, `AppIndex.swift`, `LauncherCoordinator.swift`)
- `PaletteViewModel` — 14 files
- The two source files are renamed to match their types.

## Files that must NOT change

- No behaviour anywhere. This phase is `git grep` and rename.
- **`ClipboardManager.swift`, `HotKeyManager.swift`, `MiscellaneousSettingsView.swift`** — see the cut
  list above. Dropping these three is what removes every persisted-string risk this phase used to
  carry.
- **Raycast import** — `RaycastFormat`, `RaycastV1Decoder`, `RaycastImportV1`, `RaycastImportV2` and
  their field names. That is another application's format, not Tinycast's legacy (POLICY carve-out 3).
- `Tools/*.swift` — no harness references either renamed type; the diff must not touch `Tools/`.

## Implementation boundaries

- **Renames only.** Do not move a file, change a signature, or "tidy" anything while renaming.
- **No string literal may change.** Neither renamed type owns a persisted key, raw value or column
  name: `CommandID`'s raw values live on `CommandID`, which is **not** renamed, and `PaletteViewModel`
  persists nothing. If the changed-literal grep returns a single line, something is wrong — stop and
  explain it rather than accepting it.
- The renamed file name must match its renamed type.
- Do **not** rename `AppLauncher` or `QuicklinkLauncher`. "Launcher" is clearer than "Runner" for
  opening things; document them as a reserved synonym for `NSWorkspace.open` wrappers.
- Do **not** rename `SnippetRepository`. Its conflict-detecting, revision-checked file semantics earn
  the name; document it as a one-member suffix.
- Do **not** rename `SnippetTextInjector`, `WindowMover`, `HyperKeyTap` — domain terms with no better
  alternative.

## The table to write into `AGENTS.md`

Add a **Naming vocabulary** section under Project Layout. Each row is a suffix, its meaning, and — for
the small ones — its complete membership, so a reader can tell a closed set from an open one. The list
below is what the code contains today; verify each membership with `git grep` before writing it rather
than copying this table on faith.

| Suffix        | Means                                                                                                                                                                                                              | Members                                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| `Store`       | Owns persisted state and publishes it                                                                                                                                                                              | open (10)                                                                       |
| `Coordinator` | A feature's action surface, called by `AppCore` and the palette                                                                                                                                                    | open (10)                                                                       |
| `Controller`  | Owns one AppKit window or surface                                                                                                                                                                                  | open (5)                                                                        |
| `Catalog`     | Pure static namespace over a built-in list                                                                                                                                                                         | `EmojiCatalog`, `SystemActionCatalog`, `WindowCommandCatalog`, `CommandCatalog` |
| `Index`       | A searchable collection, rebuilt as its inputs change                                                                                                                                                              | `AppIndex`, `EmojiIndex`, `PaletteRowIndex`                                     |
| `Runner`      | Performs one effectful operation on request                                                                                                                                                                        | `ShellCommandRunner`, `SystemActionRunner`, `UninstallRunner`                   |
| `Session`     | Transient state for one in-progress interaction                                                                                                                                                                    | `QuicklinkArgumentSession`, `ShortcutCaptureSession`, `UninstallSession`        |
| `Policy`      | A pure decision — no state, no effects                                                                                                                                                                             | the three `Snippet*Policy` types                                                |
| `Engine`      | A pure evaluator: input → output                                                                                                                                                                                   | `CalcEngine`, `SnippetTemplateEngine`                                           |
| `Monitor`     | Watches an external stream and reports changes; owns no policy                                                                                                                                                     | `DoubleTapMonitor`, `RunningAppsMonitor`                                        |
| `Scanner`     | Reads the filesystem to produce candidates                                                                                                                                                                         | `SettingsPaneScanner`, `UninstallScanner`                                       |
| `State`       | Shared observable state that persists nothing itself                                                                                                                                                               | `OnboardingState`, `VolumeState`, `PaletteState`                                |
| `Manager`     | **Closed set of two.** Sole owner of a subsystem's lifecycle _and_ its policy, started from `AppCore.start()`. Do not add a third — if a new type wants this suffix, it wants `Store`, `Monitor` or `Coordinator`. | `ClipboardManager`, `HotKeyManager`                                             |

Then the exceptions, each with its reason:

- `Launcher` (`AppLauncher`, `QuicklinkLauncher`) — reserved synonym for an `NSWorkspace.open` wrapper;
  clearer than `Runner` for opening things.
- `Repository` (`SnippetRepository`) — conflict-detecting, revision-checked file semantics that `Store`
  does not imply.
- `Center` (`HotKeyCenter`) — the Carbon registration layer specifically.
- `Presenter` (`HUDPresenter`) — owns the one-at-a-time / auto-dismiss / fade policy for both HUDs.
- Domain terms with no better alternative: `SnippetTextInjector`, `WindowMover`, `HyperKeyTap`.
- SwiftUI-layer suffixes (`View`, `Screen`, `Card`, `Row`, `Sheet`) are a separate vocabulary and are
  not governed by this table.

State the rule the table exists to enforce: **a new type takes an existing suffix, or the table gains a
row in the same commit.**

## Detailed acceptance criteria

1. Both renames applied consistently; no old name remains
   (`git grep -n "CommandRegistry\|PaletteViewModel"` → empty).
2. Both renamed files' names match their primary types.
3. **The changed-string-literal grep returns nothing.** `git diff -U0 -- '*.swift' | grep '^[-+].*"'`
   is expected to be empty; any line it does return must be explained before the phase is accepted.
4. `AGENTS.md` contains the suffix table, its membership lists, the exceptions with reasons, and the
   "new suffix means a new row" rule.
5. `git grep -n "Registry\|ViewModel"` finds neither suffix in `Tinycast/`.
6. All 17 harnesses pass.
7. Zero behaviour change on a clean install.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — all 17
- [ ] `checklists/regression.md` — Core sweep
- [ ] Open the palette, run a command from each section, switch screens and Escape back out — the
      palette is the only surface either renamed type touches
- [ ] Settings ▸ a pane switch from the palette still works

Clipboard, hotkey and clean-install passes are no longer required: with the three cut renames, this
phase does not touch clipboard capture, hotkey persistence or any persisted record.

## Regression risks

| Risk                                                             | Mitigation                                                       |
| ---------------------------------------------------------------- | ---------------------------------------------------------------- |
| A rename lands inside a string literal rather than an identifier | AC3 — the changed-literal grep must come back **empty**          |
| A file is renamed but `project.yml` / the Xcode project drifts   | `xcodegen generate` then a clean build                           |
| The `AGENTS.md` membership lists are copied rather than verified | Re-derive each closed set with `git grep` before writing the row |

The four traps this phase used to carry — `internalType`, `SettingsKey.showInMenuBar`, `CommandID` raw
values, SQLite column names — are all gone, because none of them lives in a file this phase touches.

## Rollback strategy

`git revert <sha>`. **No data risk** — nothing persisted changes.

## Expected commit size

~16 files of one-line identifier changes, two file renames. `AGENTS.md` +45 lines.

## Suggested commit message

```
Write down the naming vocabulary

The suffix table goes into AGENTS.md with its membership lists, its five
documented exceptions and the rule that a new suffix means a new row.

Two renames make the table true: CommandRegistry -> CommandCatalog, which
is a static namespace over a built-in list like the three Catalogs it now
joins, and PaletteViewModel -> PaletteState, which is shared state read by
the window controller and the panel rather than a per-view VM. Registry and
ViewModel are now absent from the codebase.

Manager stays as a closed set of two. ClipboardManager owns the capture
policy a Monitor would not, and HotKeyManager drives Carbon registration
and double-tap dispatch rather than merely holding bindings. No persisted
key, raw value or column name is touched.
```

## Dependencies

**Phase 29 (hard).**

## Follow-up left open

`MiscellaneousSettingsView` sits in `Features/Calculator/Settings/` but is not a Calculator-owned pane.
It belongs in `Features/Settings/Panes/` beside General and Permissions. That is a file move, out of
scope here.

## Definition of Done

- All acceptance criteria met
- Changed-literal grep empty
- Vocabulary table in `AGENTS.md`, memberships verified against `git grep`
- Merged

## Estimated difficulty

**Low.** IDE-driven. Writing the table honestly is the only part that takes thought.

## Estimated Claude context usage

**Low.**

## Notes for reviewers

- **The diff should contain no string literals at all.** Run
  `git diff -U0 -- '*.swift' | grep '^[-+].*"'` and expect silence. This is a stronger check than the
  phase originally carried, and it is only available because the three risky renames were cut.
- Confirm `ClipboardManager`, `HotKeyManager` and `MiscellaneousSettingsView` are **absent** from the
  diff. Their presence means the cut list was ignored.
- Confirm `RaycastImport*` is absent — that is an external format, not Tinycast's legacy.
- Spot-check two closed-set rows in the `AGENTS.md` table with `git grep`. A membership list that is
  wrong on the day it lands is worse than no list.
- Confirm the table states the exceptions **with reasons**. A vocabulary with undocumented exceptions
  is a vocabulary nobody follows.
