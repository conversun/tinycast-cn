# Phase 10 kickoff — Health-timer consolidation

Read `docs/refactor/phases/10-health-timer-consolidation.md` completely before editing.

## Task

Three separate 1-second `Timer`s run the same three-step health check. Consolidate them behind one
`HealthTicker` owned by `AppCore`, and give the clipboard poll a tolerance plus a session suspend.

## Hard gates

- **Each subscriber keeps its own `healthCheck()` body verbatim.** The ticker decides _when_ to call,
  never _what_ to check. The three bodies look similar and are not the same — do not merge them.
- The ticker's timer must **not** run when the subscriber list is empty. A user who binds no double-tap,
  configures no Hyper key and never enables snippets must pay nothing.
- Subscription must be **weak**, or use an explicit unsubscribe token. A strong list leaks a torn-down
  listener and keeps ticking it.
- `SnippetKeywordListener.stop()` must unsubscribe (it currently calls `stopHealthTimer()`).
- Interval stays **1 second**. Clipboard poll interval stays **0.5 seconds** — add `tolerance` only.
- **The idle back-off idea is out of scope.** It needs a `powermetrics` measurement first.
- Session suspend must actually pause or invalidate the poll timer, not early-return inside `poll()` —
  the point is fewer wakeups.
- On resume, re-baseline `lastChangeCount` **before** polling, matching `start()`, or a clip made in
  another user session gets captured as new.
- Use `NotificationToken` for the workspace observers, as the rest of the codebase does.
- Do not touch `SnippetKeywordPolicy.swift`, `DoubleTapDetector.swift`, `DoubleTapModifier.swift` or
  `ClipboardStore.swift` — all harness-compiled.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "Timer" Tinycast/Core   # expect HealthTicker, ClipboardManager, PaletteWindowController only
```

Run `hotkey-test` and `snippets-test`.

## Summarise

Use the system-prompt format. State the subscription mechanism (weak vs token) and confirm no retain
cycle. Confirm the three `healthCheck()` bodies are unchanged.
