# Phase 29 kickoff — Feature folders and the Settings shell

Read `docs/refactor/phases/29-feature-folders.md` completely. The target-layout table in it is the
specification.

**Work one feature at a time, one commit each.** Thirteen small commits are far easier to bisect than
one giant move. If asked to do all thirteen in one conversation and context runs short, complete whole
features and stop cleanly — a half-moved feature is the worst outcome.

## Task

Co-locate each feature's Model (pure) / Service (effects) / UI / Settings under `Features/<Name>/`,
reduce `Settings/` to the shell plus `Panes/`, and **delete `Tinycast/Core/` entirely** — every file in
it has a home in this phase or an earlier one.

## Hard gates

- **100 % moves.** Zero content changes. `git diff -M --stat` must show 100 % similarity for every file,
  except the three enumerated splits in the phase doc — and those are cut-and-paste, so every `+` line
  has a matching `-` line in the same commit.
- **~15 harness command lines change.** Every harness except `palette-selection-test` names at least one
  moving file. Update **all three** places in the same commit as each feature's move:
  `docs/development.md`, `AGENTS.md`, `docs/refactor/checklists/testing.md`.
- **`AGENTS.md`'s Critical Invariants section names file paths throughout.** Read the whole section and
  update every path. A stale invariant is worse than none — it is the project contract, and the next
  agent will trust it.
- **Do not rename any type.** Phase 30.
- Do not merge or edit any file. **Only the three splits enumerated in the phase doc are permitted**
  (`LauncherView`, `ClipboardView`, `SettingsRootView`), and file renames that make a filename match its
  type (`RunningApps.swift` → `RunningAppsMonitor.swift`).
- **If a file appears to have no home, that is a gap in the phase document — say so.** Do not park it in
  a leftover `Core/`; a surviving flat namespace is how this grows back.
- Do not create four empty layer subfolders for a feature with two files. Onboarding and
  WindowManagement do not need them — use judgement.
- Layer placement is checkable: **a file under `Model/` must not import AppKit or SwiftUI.** If it does,
  it belongs in `Service/` or `UI/`.
- Run `xcodegen generate` after each feature and commit the project file with it.

## Verify before you summarise

Per feature:

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff -M --stat
```

At the end, **copy the harness block out of `docs/development.md` and run it verbatim.** If it works,
that file is correct — which is the only way to be sure.

```
grep -rn "Tinycast/Core/" docs/ AGENTS.md    # should return only intentional historical references
ls Tinycast/Core                             # should fail: no such directory
```

## Summarise

Use the system-prompt format, **per feature**. List which harness command lines you updated and in which
files. Explicitly confirm you audited `AGENTS.md`'s Critical Invariants section for stale paths, and
confirm `Tinycast/Core/` is gone.
