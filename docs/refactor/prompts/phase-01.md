# Phase 01 kickoff — Instrumentation and baselines

Read `docs/refactor/phases/01-instrumentation-and-baselines.md` completely before editing anything. It is
the specification; this prompt only restates the gates.

## Task

Add `os_signpost` intervals around five operations, and nothing else.

## Hard gates

- **Exactly five intervals**, no more: `AppIndex.scan`, `AppIndex.rank`,
  `PaletteWindowController.show`, `UninstallScanner.scan`, `AppCore.start`.
- **Do not add `import os` to any file compiled by a `Tools/` harness.** Check the harness table in
  `docs/refactor/checklists/testing.md` before touching any file. This is the one way this phase breaks
  the build for someone else.
- Every interval must survive early returns and throws — use `withIntervalSignpost` or `defer`, never a
  manual end a `return` can skip. `AppIndex.scan` has a `continue` inside a `repeat`;
  `UninstallScanner.scan` has several `throw` paths.
- **Zero behaviour change.** No statement reordered, no condition altered.
- No `os_log` statements. Signposts only.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release CODE_SIGNING_ALLOWED=NO
```

Then run **all** harnesses from `docs/development.md` — the whole block. A harness that fails to
_compile_ means a signpost landed in a pure file.

## Summarise

Use the format in the system prompt. In **Behaviour changes**, `NONE` is the only acceptable answer.
