# Phase 30 kickoff — Naming vocabulary

Read `docs/refactor/phases/30-naming-vocabulary.md` completely.

## Task

Two renames, plus write the suffix vocabulary table into `AGENTS.md`.

| Today              | Becomes          |
| ------------------ | ---------------- |
| `CommandRegistry`  | `CommandCatalog` |
| `PaletteViewModel` | `PaletteState`   |

Rename each file to match its type. **The table is the deliverable** — the two renames exist only
because those names describe something the code does not do.

## Do NOT apply these three

They were proposed and cut. Do not apply them, and do not reintroduce them as "while I'm here":

- `ClipboardManager` → `ClipboardMonitor` — it owns capture policy and the paste handshake, which the
  real Monitors (`RunningAppsMonitor`, `DoubleTapMonitor`) do not
- `HotKeyManager` → `HotKeyBindings` — a plural noun for an active coordinator, one character from the
  existing `HotKeyBinding` model type spelled throughout the same file
- `MiscellaneousSettingsView` → `CalculatorSettingsView` — the tab case, raw value, title and icon all
  stay `Miscellaneous`, and the pane is expected to grow past Calculator

`ClipboardManager.swift`, `HotKeyManager.swift` and `MiscellaneousSettingsView.swift` must be **absent
from the diff**.

## Hard gates

- **No string literal may change.** Neither renamed type owns a persisted key, raw value or column
  name — `CommandID`'s raw values live on `CommandID`, which is not renamed, and `PaletteViewModel`
  persists nothing. `git diff -U0 -- '*.swift' | grep '^[-+].*"'` must come back **empty**. If it
  returns anything, stop and explain it rather than accepting it.
- **Renames only.** Do not move a file, change a signature, or tidy anything while renaming.
- **Do not touch Raycast import** (`RaycastFormat`, `RaycastV1Decoder`, `RaycastImportV1/V2`) — another
  application's format, not Tinycast's legacy.
- **Do not rename** `AppLauncher`, `QuicklinkLauncher` (Launcher is clearer for opening things),
  `SnippetRepository` (its conflict-detecting file semantics earn the name), `SnippetTextInjector`,
  `WindowMover` or `HyperKeyTap` (domain terms). Document all of these as exceptions in `AGENTS.md`.

## The `AGENTS.md` table

The phase document specifies the rows. Two rules while writing it:

- **Verify every closed-set membership with `git grep` before writing it.** Do not copy the phase
  document's lists on faith — a membership list that is wrong on the day it lands is worse than none.
- `Manager` gets a row as a **closed set of two** (`ClipboardManager`, `HotKeyManager`), with the note
  that a third candidate wants `Store`, `Monitor` or `Coordinator` instead.

End the section with the rule it exists to enforce: a new type takes an existing suffix, or the table
gains a row in the same commit.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git grep -n "CommandRegistry\|PaletteViewModel"        # must be empty
git grep -n "Registry\|ViewModel" -- Tinycast          # must be empty — both suffixes retired
git diff -U0 -- '*.swift' | grep '^[-+].*"'            # must be empty
git diff --stat                                        # ClipboardManager/HotKeyManager/Miscellaneous* absent
```

Run all 17 harnesses. Then launch, open the palette, run a command from each section, switch screens
and Escape back out, and open Settings from the palette. Clipboard and hotkey passes are not required —
this phase touches neither.

## Summarise

Use the system-prompt format. Confirm the changed-string-literal grep was **empty**, that all three cut
renames are absent from the diff, that `RaycastImport*` is absent, and name the two closed-set rows you
re-derived with `git grep` when writing the `AGENTS.md` table.
