# Phase 27 — Extract `DesignSystem/` and `Platform/`

**Milestone:** M5 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

Pure file moves. Pull the shared visual primitives and the thin system shims out of the 46-file flat
`Core/` namespace. **No file contents change** except imports that the move makes redundant.

## Why this phase exists

`Core/` currently mixes design tokens, eleven SwiftUI view modifiers, AppKit window plumbing, ten stores,
four pure algorithms and three platform shims. "Core" means nothing, and a new contributor cannot answer
"where does this file go?" from the tree.

XcodeGen derives sources from `sources: - path: Tinycast`, so moves are free at the project level.

## Architecture Review reference

**M-1** · §4.2 target folder structure

## Objectives

1. Create `Tinycast/DesignSystem/` and move the shared visual primitives into it.
2. Create `Tinycast/Platform/` and move the system shims into it.
3. Update the two harness command lines that reference a moved file.

## Expected moves

**→ `Tinycast/DesignSystem/`**

| From                                             | To                                               |
| ------------------------------------------------ | ------------------------------------------------ |
| `Core/Theme.swift`                               | `DesignSystem/Theme.swift`                       |
| `KeyCapChip` (extracted from `Core/Theme.swift`) | `DesignSystem/KeyCapChip.swift`                  |
| `Core/Tooltip.swift`                             | `DesignSystem/Tooltip.swift`                     |
| `Core/SymbolImage.swift`                         | `DesignSystem/SymbolImage.swift`                 |
| `Core/VisualEffectView.swift`                    | `DesignSystem/VisualEffectView.swift`            |
| `Features/PopoverMenu.swift`                     | `DesignSystem/PopoverMenu.swift`                 |
| `Features/Settings/SettingsComponents.swift`     | `DesignSystem/SettingsComponents.swift`          |
| `Core/EdgeDissolve.swift`                        | `DesignSystem/Scrolling/EdgeDissolve.swift`      |
| `Core/ThinScrollbar.swift`                       | `DesignSystem/Scrolling/ThinScrollbar.swift`     |
| `Core/ScrollIntent.swift`                        | `DesignSystem/Scrolling/ScrollIntent.swift`      |
| `Core/OverlayScroller.swift`                     | `DesignSystem/Scrolling/OverlayScroller.swift`   |
| `Core/RightClick.swift`                          | `DesignSystem/Interaction/RightClick.swift`      |
| `Core/PanelTransition.swift`                     | `DesignSystem/Interaction/PanelTransition.swift` |

**→ `Tinycast/Platform/`**

| From                                               | To                                                          |
| -------------------------------------------------- | ----------------------------------------------------------- |
| `Core/Permissions.swift`                           | `Platform/Permissions.swift`                                |
| `Core/LaunchAtLogin.swift`                         | `Platform/LaunchAtLogin.swift`                              |
| `Core/CursorScreen.swift`                          | `Platform/CursorScreen.swift`                               |
| `Core/Bundle+AppName.swift`                        | `Platform/AppDisplayName.swift` _(rename — see boundaries)_ |
| `Core/NotificationToken.swift`                     | `Platform/NotificationToken.swift`                          |
| `Core/AppPaths.swift`                              | `Platform/AppPaths.swift`                                   |
| `Core/Signposts.swift`                             | `Platform/Signposts.swift`                                  |
| `Core/ImageThumbnail.swift`                        | `Platform/Images/ImageThumbnail.swift`                      |
| `IconCache` (extracted from `Core/AppIndex.swift`) | `Platform/Images/IconCache.swift`                           |

## Files that must NOT change (contents)

- **`EdgeDissolve.swift` and `ThinScrollbar.swift`: moved, never opened.** `AGENTS.md` puts their
  contents off-limits. A path change is not an edit; nothing inside them may change, not even an import.
- Every other moved file: contents unchanged apart from removing an import the move made redundant.
- `Core/AppIndex.swift`: **only** the `IconCache` extraction. `AppEntry` and `AppIndex` stay put.
- `Core/Theme.swift`: **only** the `KeyCapChip` extraction. Not one token value changes — it is the
  single design-token source and `AGENTS.md` points every restyle at it.

## Implementation boundaries

- **Moves only.** No renames except `Bundle+AppName.swift` → `AppDisplayName.swift`, which is a filename
  change only — the `extension Bundle { var appDisplayName }` inside is untouched. (Type renames are
  phase 30.)
- `IconCache` is _extracted_ from `AppIndex.swift`, not rewritten. Cut the enum, paste it, add whatever
  imports it needs. `AppEntry.icon` was already deleted in phase 02, so the only remaining coupling is
  `AppIconView` and `PopoverMenuIcon.file`.
- **`KeyCapChip` is extracted from `Theme.swift` the same way** — cut the `struct`, paste it, nothing
  else. `Theme.swift` is the design-token source and a `View` does not belong in it; §4.2 has always
  drawn `KeyCapChip.swift` as its own file. The `extension View` at the bottom of `Theme.swift` stays
  where it is: it is token application, not a view.
- Two harness command lines reference moved files and must be updated in the **same commit**:
  - `callout-test` → `Core/Theme.swift` becomes `DesignSystem/Theme.swift`
  - any harness referencing `NotificationToken.swift` (`snippets-test`) → `Platform/NotificationToken.swift`

  Update them in `docs/development.md` **and** `AGENTS.md`.

- **`AppPaths.swift` goes to `Platform/`, not `App/`.** §4.2 originally drew it under `App/`; that was
  wrong. It is a dependency-free path shim with no wiring role, and `App/` is the composition root —
  three files, and it stays three.
- Run `xcodegen generate` and commit the regenerated `.xcodeproj`.
- Do not create an umbrella header, a module map, or any `@_exported import`.
- Do not reorganise `Features/` in this phase — that is 29.

## Detailed acceptance criteria

1. Every listed file is at its new path; none is at its old path.
2. `git diff -M --stat` shows every move as a rename with **100 % similarity**, except the two
   extractions: `AppIndex.swift` / `IconCache.swift` and `Theme.swift` / `KeyCapChip.swift`.
3. `EdgeDissolve.swift` and `ThinScrollbar.swift` show 100 % similarity — zero content change.
4. `callout-test` and `snippets-test` command lines updated in `docs/development.md` and `AGENTS.md`.
5. All 17 harnesses pass.
6. Debug **and** Release builds succeed.
7. Zero behaviour change; UI pixel-identical.

## Manual verification checklist

- [ ] `checklists/build.md` including the **Release build**
- [ ] `checklists/testing.md` — **all 17 harnesses**, with the updated command lines
- [ ] `checklists/regression.md` — Core sweep + **Clean install**
- [ ] `git diff -M --stat` reviewed for similarity percentages
- [ ] Screenshot the palette (expanded, with results) before and after → pixel-identical
- [ ] Screenshot a Settings pane before and after → pixel-identical
- [ ] Scroll the launcher and a Settings pane → the edge dissolve and thin scrollbar look unchanged
- [ ] Open a dialog and a HUD → entrance animation unchanged
- [ ] `xcodegen generate` produces no further diff when run a second time

## Regression risks

| Risk                                                            | Mitigation                                                                 |
| --------------------------------------------------------------- | -------------------------------------------------------------------------- |
| A harness command line is missed → red suite                    | AC4/AC5, run all 17                                                        |
| `EdgeDissolve` / `ThinScrollbar` get an "unused import" cleanup | AC3 — 100 % similarity required                                            |
| `IconCache` extraction changes cache behaviour                  | `git diff` the extracted enum against the original hunk                    |
| The `.xcodeproj` is not regenerated and CI/local builds diverge | AC6 + running `xcodegen` twice                                             |
| A `fileprivate` becomes inaccessible after the move             | Compiler catches it; do not "fix" by widening access beyond what is needed |

## Rollback strategy

`git revert <sha>`. Pure moves — a revert restores the old paths and the old harness command lines
together.

## Expected commit size

~23 files moved, 2 docs updated, 2 files extracted. Content delta near zero.

## Suggested commit message

```
Move the design-system primitives and platform shims out of Core/

Pure file moves. Core/ mixed design tokens, eleven view modifiers, window
plumbing, stores and pure algorithms in one 46-file namespace. Contents
unchanged; EdgeDissolve and ThinScrollbar are moved but not opened, per
AGENTS.md. The two harness command lines that name a moved file are
updated in the same commit.
```

## Dependencies

**Phase 26 (hard)** — move the right files, after they are the right files. Blocks 28.

## Definition of Done

- All acceptance criteria met
- Similarity percentages verified
- All 17 harnesses green with updated paths
- Merged

## Estimated difficulty

**Low–Medium.** Mechanical, but the harness paths are easy to forget.

## Estimated Claude context usage

**Medium** — many files, almost no reading required.

## Notes for reviewers

- **`git diff -M --stat` is the whole review.** Anything under 100 % similarity that is not one of the
  four extraction files (`AppIndex.swift`, `IconCache.swift`, `Theme.swift`, `KeyCapChip.swift`) needs
  an explanation.
- Specifically confirm `EdgeDissolve.swift` and `ThinScrollbar.swift` are 100 %. An "unused import
  removed" on either is a violation of an explicit `AGENTS.md` rule.
- Check `docs/development.md` **and** `AGENTS.md` both updated. They duplicate the command lines and it
  is easy to fix one.
- Run `xcodegen generate` yourself after pulling; if it produces a diff, the committed project file is
  stale.
