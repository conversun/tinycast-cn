# Phase 04 kickoff — Retire the last `NSAlert`

Read `docs/refactor/phases/04-retire-the-last-nsalert.md` completely before editing.

## Task

`AppCore.setSnippetsEnabled` presents its consent prompt with `NSAlert().runModal()`. `AGENTS.md`
forbids `NSAlert` outright. Route it through `DialogController` via `AppCore.confirm(…)`.

## Hard gates

**This is a privacy-sensitive flow. The ordering is the specification:**

1. user confirms
2. `settings.snippetsEnabled = true`
3. `Permissions.ensureAccessibility()`

- **Cancelling must leave the feature off and request no permission at all.** This is the single most
  important behaviour in the phase.
- The Accessibility prompt must still originate **only** from this explicit gesture — never from
  startup, a callback, a watcher, or the health check. That is a documented invariant.
- Text is character-identical, including "Keyword expansion requires the Accessibility permission.
  Keystrokes stay on this Mac." That sentence is a privacy promise, not copy.
- Buttons: "Continue" (primary, ↵) and "Cancel" (leading, Escape).
- `tone: .neutral`, `confirmRole: .standard` — this is consent, not a destructive warning.
- **Do not build a reusable consent-dialog helper.** One call site.
- Turning snippets **off** keeps its early-return path with no dialog.
- Do not modify anything under `Core/Dialog/` or `Core/Snippets/`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "NSAlert" Tinycast          # must be empty
```

Run the snippets harness (command in `docs/development.md`).

## Summarise

Use the system-prompt format. Quote the final dialog title, message and button titles verbatim in your
summary so the reviewer can diff them against the originals without running the app.
