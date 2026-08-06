# Phase 10 — Health-timer consolidation

**Milestone:** M1 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

Three separate 1-second `Timer`s run the same three-step health check for three event taps. Consolidate
them behind one shared ticker, and give the 0.5 s clipboard poll a tolerance and a session suspend.

## Why this phase exists

Up to five repeating timers can be live at once, and three of them — `HyperKeyTap.healthCheck`,
`DoubleTapMonitor.healthCheck`, `SnippetKeywordListener.healthCheck` — do exactly the same work: retry
tap installation, notice Accessibility revocation, re-enable a system-disabled tap. Independent,
unaligned timers wake the CPU separately.

The clipboard poller is also the only monitor in the app that does **not** suspend on
`sessionDidResignActive`; the two tap monitors already do.

## Architecture Review reference

**M-2** · §6 P-7

## Objectives

1. Add a `@MainActor final class HealthTicker` on `AppCore`: one 1 s `Timer`, a subscriber list,
   running only while at least one subscriber is registered.
2. Subscribe `HyperKeyTap`, `DoubleTapMonitor` and `SnippetKeywordListener`; delete their own timers.
3. Give `ClipboardManager`'s poll timer a `tolerance` so the kernel can coalesce it.
4. Suspend the clipboard poll on `sessionDidResignActive` and resume on `sessionDidBecomeActive`.

## Expected files to modify

| File                                                  | Change                                                   |
| ----------------------------------------------------- | -------------------------------------------------------- |
| `Tinycast/Core/HealthTicker.swift`                    | **New.** ~45 lines.                                      |
| `Tinycast/Core/AppCore.swift`                         | Own the ticker; wire the three subscribers in `start()`. |
| `Tinycast/Core/HotKey/HyperKeyTap.swift`              | Remove its timer; expose `healthCheck()` to the ticker.  |
| `Tinycast/Core/HotKey/DoubleTapMonitor.swift`         | Same.                                                    |
| `Tinycast/Core/Snippets/SnippetKeywordListener.swift` | Same.                                                    |
| `Tinycast/Core/ClipboardManager.swift`                | Tolerance + session suspend/resume.                      |

## Files that must NOT change

- `Tinycast/Core/Snippets/SnippetKeywordPolicy.swift` — harness-compiled; the lifecycle **policy** is
  pure and stays untouched. Only the listener's _timer_ moves.
- `Tinycast/Core/HotKey/DoubleTapDetector.swift`, `DoubleTapModifier.swift` — harness-compiled
- `Tinycast/Core/ClipboardStore.swift` — harness-compiled
- `Tinycast/Core/Paster.swift`

## Implementation boundaries

- **Each subscriber keeps its own `healthCheck()` logic verbatim.** The ticker only decides _when_ to
  call; it never decides _what_ to check. Do not unify the three bodies — they check different taps with
  different failure modes.
- The ticker's timer must **not** run when the subscriber list is empty. The whole point is that a user
  who binds no double-tap, configures no Hyper key and never enables snippets pays nothing.
- Subscription must be by weak reference or by an explicit unsubscribe token. A subscriber that
  deallocates must not keep the ticker alive or crash it.
- Interval stays **1 second**. Do not tune it in this phase.
- `ClipboardManager`'s poll interval stays **0.5 seconds**. Add `tolerance` only — the review's optional
  back-off idea (interval 1.5 s after 60 s idle) is explicitly **out of scope** here; it needs a
  `powermetrics` measurement first.
- Session suspend for the clipboard poller must invalidate or pause the timer, not merely early-return
  in `poll()` — the point is fewer wakeups.
- On resume, the poller must re-baseline `lastChangeCount` **before** polling, or it will capture a clip
  made in another user session as if it were new. Match the existing `start()` behaviour.
- Use `NotificationToken` for the two workspace observers, as the rest of the codebase does.

## Detailed acceptance criteria

1. `grep -rn "Timer" Tinycast/Core` shows timers only in `HealthTicker`, `ClipboardManager`, and
   `PaletteWindowController` (pop-to-root) — the three tap monitors have none.
2. With no Hyper key, no double-tap binding and snippets off, the health timer is **not scheduled**.
3. Binding any one of the three schedules it; removing all three stops it.
4. Each subscriber's `healthCheck()` body is unchanged.
5. Clipboard capture still works, with the same ~0.5 s latency perceptually.
6. On fast user switching out and back, the clipboard poller resumes without capturing a stale clip.
7. No retain cycle: the ticker does not strongly hold its subscribers, and none holds the ticker.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `hotkey-test`, `snippets-test`
- [ ] `checklists/regression.md` — Core sweep + **Hotkeys** + **Clipboard** + **Snippets**
- [ ] Fresh Dev profile, nothing bound: confirm via a breakpoint or a temporary log that the ticker is
      not running
- [ ] Set a Hyper key → ticker starts; status dot goes green
- [ ] Revoke Accessibility in System Settings → within ~1 s the dot goes orange
- [ ] Re-grant → within ~1 s it goes green again (this is the health check working)
- [ ] Bind a double-tap → it fires; revoke Accessibility → recorder shows the needs-permission state
- [ ] Enable snippets → keyword expansion works; the tap survives a `tapDisabledByTimeout`
- [ ] Clear the Hyper key, unbind the double-tap, disable snippets → ticker stops
- [ ] Copy text repeatedly for 60 s → every copy is captured
- [ ] Fast-user-switch away and back → copy something → it is captured, and nothing stale appeared

## Regression risks

| Risk                                                                                                              | Mitigation                                                                                                   |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| **A tap stops self-healing.** The health checks are what make permission-granting take effect without a relaunch. | The revoke/re-grant test for all three taps                                                                  |
| Ticker keeps running forever, defeating the purpose                                                               | AC2/AC3                                                                                                      |
| Retain cycle keeps a torn-down monitor alive                                                                      | AC7; check the subscription mechanism in review                                                              |
| Clipboard poller misses a copy after resume                                                                       | AC6 and the fast-user-switch test                                                                            |
| Suspending the poller loses a copy made while suspended                                                           | Accept — that is what the two tap monitors already do, and another session's clipboard is not ours to record |

## Rollback strategy

`git revert <sha>`. In-memory only. If reverted, the three timers come back independently — no state to
reconcile.

## Expected commit size

6 files, +90 / −70 lines.

## Suggested commit message

```
Consolidate the three tap health checks onto one ticker

HyperKeyTap, DoubleTapMonitor and SnippetKeywordListener each ran their
own 1s timer doing the same three checks. One shared ticker, running only
while something is subscribed. The clipboard poll gains a tolerance and
now suspends on session resign like the two tap monitors already did.
Check bodies and intervals unchanged.
```

## Dependencies

Phase 01.

## Definition of Done

- All acceptance criteria met
- Revoke/re-grant verified for all three taps
- Fast-user-switch verified
- Merged

## Estimated difficulty

**Medium.** Six files, three lifecycles, and a permission-recovery behaviour that is easy to break and
easy to not notice.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **The revoke/re-grant test is the real acceptance test.** Everything else can look right while the
  self-healing is quietly dead, and a user would only discover it by relaunching the app.
- Confirm subscription is weak. A strong list means `SnippetKeywordListener` never deallocates after
  `stop()`, which is a leak _and_ leaves a torn-down listener being ticked.
- Check that `SnippetKeywordListener.stop()` unsubscribes. It currently calls `stopHealthTimer()`; the
  replacement must do the equivalent.
- Reject any attempt to merge the three `healthCheck()` bodies into a shared implementation. They look
  similar and are not the same.
