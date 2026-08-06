# Phase 03 kickoff — Named paste-timing constants

Read `docs/refactor/phases/03-named-paste-timing-constants.md` completely before editing.

## Task

`Tinycast/Core/Paster.swift` guards a timing-sensitive synthetic-⌘V handshake with three unnamed
literals: `0.08`, `0.05`, `0.05`. Give them names. Change nothing else.

## Hard gates

- **The values are frozen.** `0.08` stays `0.08`. `0.05` stays `0.05`. This phase renames; it does not
  tune. Transcribing one wrong makes pasting hang, visibly.
- **Do not convert `DispatchQueue.main.asyncAfter` to `Task.sleep`.** The scheduling semantics are not
  identical and the current form is proven on a path that is hard to test.
- Read both `0.05` sites before deciding whether they share one constant. If they mean the same thing
  (a direct `postToPid` with no activation), one constant is right. If not, two.
- **Do not touch `SnippetTextInjector.swift`.** It has its own separate timing model compensating for
  different things. Do not attempt to unify them.
- One comment line per constant, ≤ 100 characters, saying what it compensates for.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

One file should appear in the diff.

## Summarise

Use the system-prompt format. State the two (or three) constant names and their values explicitly so the
reviewer can check them against the originals without opening the file.
