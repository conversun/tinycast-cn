# Phase 27 kickoff — Extract `DesignSystem/` and `Platform/`

Read `docs/refactor/phases/27-extract-designsystem-and-platform.md` completely. The move table in it is
the specification.

## Task

Pure file moves out of the 46-file flat `Core/` namespace, plus two extractions: `IconCache` out of
`AppIndex.swift`, and `KeyCapChip` out of `Theme.swift`.

## Hard gates

- **Moves only.** No renames except `Bundle+AppName.swift` → `AppDisplayName.swift`, which is a
  _filename_ change only — the `extension Bundle { var appDisplayName }` inside is untouched. Type
  renames are phase 30.
- **`EdgeDissolve.swift` and `ThinScrollbar.swift` are moved but never opened.** `AGENTS.md` puts their
  contents off-limits. Not even an unused-import cleanup. `git diff -M` must show them at **100 %
  similarity**.
- Every other moved file: contents unchanged apart from removing an import the move made redundant.
- `IconCache` is **cut and pasted** out of `AppIndex.swift`, not rewritten. `AppEntry` and `AppIndex`
  stay put.
- `KeyCapChip` is **cut and pasted** out of `Theme.swift` into `DesignSystem/KeyCapChip.swift`. A `View`
  does not belong in the design-token source. The `extension View` at the bottom of `Theme.swift` stays
  — that is token application, not a view. `callout-test` compiles `Theme.swift` for `Theme.Size` only,
  so its command line does **not** change; confirm that by running it.
- **Two harness command lines must be updated in the same commit**, in **both** `docs/development.md`
  **and** `AGENTS.md`:
  - `callout-test` → `Core/Theme.swift` becomes `DesignSystem/Theme.swift`
  - `snippets-test` → `Core/NotificationToken.swift` becomes `Platform/NotificationToken.swift`
- Run `xcodegen generate` and commit the regenerated `.xcodeproj`.
- No umbrella header, no module map, no `@_exported import`.
- Do not reorganise `Features/` — that is phase 29.
- If a `fileprivate` becomes inaccessible after a move, fix it with the **narrowest** access change
  needed; do not widen to `public`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release CODE_SIGNING_ALLOWED=NO
git diff -M --stat      # every move should read 100%, except AppIndex.swift and the new IconCache.swift
xcodegen generate       # run twice; the second must produce no further diff
```

Run **all 17** harnesses using the **updated** command lines, copy-pasted fresh from
`docs/development.md`.

## Summarise

Use the system-prompt format. Paste the `git diff -M --stat` similarity column, and confirm
`EdgeDissolve.swift` and `ThinScrollbar.swift` are both 100 %.
