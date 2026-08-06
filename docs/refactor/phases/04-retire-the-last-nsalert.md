# Phase 04 — Retire the last `NSAlert`

**Milestone:** M1 · **Effort:** S · **Risk:** Med · **Context:** Low

---

## Overview

`AppCore.setSnippetsEnabled` presents its consent prompt with `NSAlert().runModal()`. `AGENTS.md`
forbids `NSAlert` outright. Route it through `DialogController` like every other confirmation in the app.

## Why this phase exists

The invariant is explicit: _"Tinycast presents its own dialogs, never `NSAlert` / `NSSlider` / system
popovers"_, and it gives the reason — `runModal`'s nested run loop lets a held Carbon hotkey stack
dialogs, and an Aqua alert clashes with the forced-`.darkAqua` surface.

This particular call site cannot currently stack, because it is only reachable from a Settings click.
But it is the exact pattern the invariant exists to prevent, and it renders a light-mode alert on a
dark-only app.

## Architecture Review reference

**K-6** · §6.2 concurrency table

## Objectives

1. Replace the `NSAlert` in `setSnippetsEnabled` with `AppCore.confirm(…)`.
2. Preserve the **exact** text, button titles, and — critically — the exact ordering of consent →
   persist → permission request.
3. Confirm `grep -rn "NSAlert" Tinycast` returns nothing.

## Expected files to modify

| File                                                    | Change                                                                                               |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Tinycast/Core/AppCore.swift`                           | `setSnippetsEnabled` becomes `async`, or dispatches into a `Task`; the alert becomes a `confirm(…)`. |
| `Tinycast/Features/Settings/SnippetsSettingsView.swift` | Only if the call site must wrap the now-async call in a `Task`.                                      |

## Files that must NOT change

- `Tinycast/Core/Dialog/*` — `DialogController` is consumed, not modified
- `Tinycast/Core/Snippets/*` — the store, listener and injector are untouched
- `Tinycast/Core/AppSettings.swift`
- Any other consent flow

## Implementation boundaries

- **The ordering is load-bearing and must not change:**
  1. user confirms
  2. `settings.snippetsEnabled = true`
  3. `Permissions.ensureAccessibility()`

  The permission prompt must still originate from **this explicit gesture and nowhere else** — never
  from startup, a callback, a watcher or the health check. That is a documented invariant.

- The `NSApp.activate(ignoringOtherApps: true)` that precedes the current alert exists so the alert is
  not buried. `DialogPanel` is a non-activating `.modalPanel` and takes key focus on its own — remove
  the `activate` call **only if** manual verification confirms the dialog appears in front. If in doubt,
  keep it.
- Do not change the dialog's tone or role beyond what the text implies: this is a neutral consent
  prompt, not a destructive warning. Use `tone: .neutral` and `confirmRole: .standard`.
- Do not generalise this into a reusable "consent dialog" helper. One call site.
- Cancelling must leave `settings.snippetsEnabled` **false** and prompt for nothing.

## Detailed acceptance criteria

1. `grep -rn "NSAlert" Tinycast` returns zero results.
2. Dialog title and message text are character-identical to the current alert, including the wording
   "Keystrokes stay on this Mac."
3. Buttons are "Continue" (primary, ↵) and "Cancel" (leading, Escape).
4. Confirming enables snippets **then** requests Accessibility — in that order.
5. Cancelling changes nothing and requests nothing.
6. The dialog uses the app's own dark surface, not an Aqua alert.
7. Turning snippets **off** still takes the early-return path with no dialog.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `snippets-test`
- [ ] `checklists/regression.md` — Core sweep + **Snippets**
- [ ] **Reset TCC for the Dev channel first**: `tccutil reset Accessibility com.tinycast.app.dev`
- [ ] Settings ▸ Snippets ▸ enable → dialog appears **in front**, dark-styled
- [ ] Press Escape → feature stays off, **no permission prompt appears**
- [ ] Enable again → press ↵ → feature turns on, **then** the system Accessibility prompt appears
- [ ] Grant it; a keyword expands in TextEdit
- [ ] Disable → no dialog, feature tears down, launcher entries disappear
- [ ] Hold the snippets toggle's keyboard focus and mash Return — no dialog stacking

## Regression risks

| Risk                                                             | Mitigation                                                                          |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Permission requested on cancel** — a real privacy regression   | AC5; verification runs it after a `tccutil reset`                                   |
| Permission requested before consent persists                     | AC4; ordering is spelled out in the boundaries                                      |
| Dialog appears behind the Settings window                        | Manual check; keep `NSApp.activate` if needed                                       |
| `setSnippetsEnabled` becoming `async` breaks the SwiftUI binding | The pane's toggle already routes through `AppCore`; wrap in `Task` at the call site |
| The toggle springs back visually before the dialog resolves      | Compare against current behaviour — it already does this and must continue to       |

## Rollback strategy

`git revert <sha>`. No persisted state changes shape. If the revert happens **after** a user has enabled
snippets, nothing needs undoing — `snippetsEnabled` is a plain `Bool` either way.

## Expected commit size

1–2 files, +20 / −18 lines.

## Suggested commit message

```
Route the snippets consent prompt through DialogController

The last NSAlert in the app. AGENTS.md forbids it: runModal's nested run
loop lets a held hotkey stack dialogs, and an Aqua alert clashes with the
forced-dark surface. Consent → persist → permission ordering unchanged.
```

## Dependencies

Phase 01.

## Definition of Done

- All acceptance criteria met
- Verified from a **reset TCC state**, both accept and cancel paths
- Merged

## Estimated difficulty

**Low–Medium.** The code change is small; the verification is what matters.

## Estimated Claude context usage

**Low.**

## Notes for reviewers

- **The only thing that really matters here is that cancelling requests no permission.** Verify it
  yourself against a reset TCC state; do not take it on the summary's word.
- Check the ordering literally in the diff: the `settings.snippetsEnabled = true` line must precede
  `Permissions.ensureAccessibility()`.
- If Claude added a general-purpose consent helper, revert. One call site does not justify an abstraction.
- Confirm the message text still reads exactly "Keyword expansion requires the Accessibility permission.
  Keystrokes stay on this Mac." — that sentence is a privacy promise, not copy.
