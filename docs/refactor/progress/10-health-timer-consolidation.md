# Phase 10 — Health-timer consolidation

---

## Status

| Field                         | Value                                      |
| ----------------------------- | ------------------------------------------ |
| **Status**                    | Complete                                   |
| **Started**                   | 2026-08-05                                 |
| **Completed**                 | 2026-08-05                                 |
| **Operator**                  | abue-ammar                                 |
| **Branch**                    | `refactor/10-health-timer-consolidation`   |
| **Commit**                    | single commit on the branch                |
| **Claude conversations used** | 1                                          |
| **Actual effort**             | ~1 h vs. estimate of M (2–4 h)             |

---

## Completed tasks

- [x] Objective 1 — `Tinycast/Core/HealthTicker.swift`: a `HealthCheckable` protocol and a 49-line
      `@MainActor final class HealthTicker`, one 1 s `Timer`, weak subscribers, running only while at
      least one is registered
- [x] Objective 2 — `HyperKeyTap`, `DoubleTapMonitor` and `SnippetKeywordListener` subscribe; all
      three private timers and their `start/stopHealthTimer` pairs are deleted
- [x] Objective 3 — `ClipboardManager`'s poll timer carries `tolerance = 0.1`; interval unchanged at
      0.5 s
- [x] Objective 4 — the poll is invalidated on `sessionDidResignActive` and restarted on
      `sessionDidBecomeActive`, via two `NotificationToken` observers

## Acceptance criteria

- [x] AC1 — timers only in `HealthTicker`, `ClipboardManager`, `PaletteWindowController` — verified by:
      `grep -rn "Timer" Tinycast/Core`. The only other hit is AppKit's
      `updateInsertionPointStateAndRestartTimer` in `PalettePanel.swift`, not a `Timer`
- [x] AC2 — nothing bound means the ticker is not scheduled — verified by: a scratch harness compiling
      the shipped `HealthTicker.swift` (no subscribers → zero ticks over 1.3 s), plus the three
      subscribe sites being gated by exactly those conditions — `applyKey` returns early while the key
      stays `.none`, `syncTapPresence` unsubscribes on `bound.isEmpty`, and `snippetListener.start` is
      only reached when `settings.snippetsEnabled`
- [x] AC3 — binding any one schedules it, removing all three stops it — verified by: the same harness
      (subscribe starts ticking at ~1 s; unsubscribing the last subscriber stops it dead; re-subscribing
      the same object does not double the rate), and by the operator interactively
- [x] AC4 — each `healthCheck()` body unchanged — verified by: the diff touches only the
      `private func healthCheck()` → `func healthCheck()` signature line in all three files. No body
      line appears in the diff
- [x] AC5 — clipboard capture still works at the same perceptual latency — verified by: the operator,
      interactively. Interval untouched at 0.5 s; the added `tolerance` is 0.1
- [x] AC6 — fast user switching resumes without a stale clip — verified by: the operator. Resume runs
      `startPolling()`, which re-baselines `lastChangeCount` **before** scheduling — the same two lines
      in the same order as the old `start()`
- [x] AC7 — no retain cycle — verified by: `AppCore` → ticker strong, ticker → subscribers weak
      (`WeakSubscriber` box), subscribers → ticker weak. The harness also releases a subscriber while
      the timer is live: the next tick prunes it, does not crash, and does not block a later subscriber

---

## The three subscribers — old timer → new subscription

| Subscriber               | Started its timer in            | Now subscribes in                | Stopped in                       | Now unsubscribes in              |
| ------------------------ | ------------------------------- | -------------------------------- | -------------------------------- | -------------------------------- |
| `HyperKeyTap`            | `syncTapPresence`, `key != .none` | same call site                   | `syncTapPresence`, `key == .none` | same call site                   |
| `DoubleTapMonitor`       | `syncTapPresence`, bound + active | same call site                   | `syncTapPresence` guard, `deinit` | the guard only — see Deviations  |
| `SnippetKeywordListener` | `start(onMatch:)`               | same call site                   | `stop()`                         | `stop()`                         |

Every subscribe/unsubscribe sits at the exact call site the old `startHealthTimer()` /
`stopHealthTimer()` occupied, so what schedules and what stops the checking is unchanged.

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                                                                                     |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` clean; the `.xcodeproj` churn is the one new file (correct). Debug `BUILD SUCCEEDED`, zero warnings from the changed files — **no pre-phase baseline was captured on this branch**, so "zero *new* warnings" is asserted against the file list, not a baseline. Release build and binary size not measured |
| `checklists/testing.md`    | PASS   | Harnesses run: `snippets-test` (ALL PASSED, incl. the 12 `testKeywordListenerLifecycle` assertions) and `hotkey-test` (34/34) — the two the phase names as gates. The other 15 were not run; no changed file is compiled by any of them. Plus a scratch `HealthTicker` harness (5/5), not committed |
| `checklists/regression.md` | PASS   | Run by the operator, manually — Core sweep, Hotkeys, Clipboard, Snippets. Recorded on the operator's confirmation; Claude ran no interactive verification in this session                                                                                                                                    |
| `checklists/review.md`     | PASS   | Self-check, not a separate review pass. §1 scope: 11 files, one added, `.xcodeproj` regenerated, **none from the must-NOT-change list**; +65/−56 against an expected +90/−70. §2 no condition, comparison or default changed; no user-visible string touched. §3 five timers become two engines; isolation not weakened, no `@unchecked`, no `nonisolated(unsafe)`. §4 nothing newly retained — three `Timer` objects become one, and the subscriber map holds weak boxes. §5 comments +3, zero new stacked blocks, every authored line ≤100 chars. §6 no dead code — all three `startHealthTimer`/`stopHealthTimer` pairs and their `healthTimer` properties are deleted. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                     | Before | After | Δ                                                                        |
| -------------------------- | ------ | ----- | ------------------------------------------------------------------------ |
| Binary size (Release)      | —      | —     | not measured                                                             |
| Clean install verified?    | —      | n-a   | no storage, no persisted format, not in the clean-install list           |
| Cold launch, median of 3   | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`        |
| RSS after 10 palette opens | —      | —     | not measured                                                             |
| Repeating timers, all on   | 5      | 3     | ticker + clipboard + pop-to-root, against three tap timers + those two   |
| Repeating timers, nothing bound | 2 | 1     | the ticker does not exist; only the clipboard poll remains               |

No `powermetrics` numbers were taken. The win is wakeup coalescing: three unaligned 1 s timers become
one, and a user who binds no double-tap, configures no Hyper key and never enables snippets now pays
for no health timer at all rather than up to three.

---

## Failed tasks

none

---

## Issues encountered

- **`SnippetKeywordListener.swift` is harness-compiled.** `Tools/snippets-test.swift` globs
  `Tinycast/Core/Snippets/*.swift`, so the moment the listener names `HealthTicker` the harness stops
  compiling. Resolved by adding `Core/HealthTicker.swift` to the harness command line rather than
  stubbing it — the real ticker is Foundation-only, so it compiles standalone. Three doc lines carry
  that command: `docs/development.md`, `docs/snippets.md` and `checklists/testing.md`'s source map.
  The alternative — injecting the subscription as a closure to keep the listener ignorant of the
  ticker — was rejected as an abstraction the phase document does not name.
- **The three timers did not share a runloop mode.** `HyperKeyTap` and `DoubleTapMonitor` used
  `Timer.scheduledTimer` (default mode); the listener and the clipboard poller already used `.common`.
  One ticker forces one mode. See **Deviations**.

---

## Deviations from the phase document

- **The two tap health checks move from the default runloop mode to `.common`.** Unavoidable once the
  three timers become one, and `.common` is the superset the other two already used. Effect: those
  checks now also run while a menu is tracking instead of stalling. Strictly more robust — a watchdog
  that pauses while a menu is open was a latent bug — but it is a behaviour delta, not a no-op.
- **`DoubleTapMonitor.deinit` no longer stops the checking; it just tears the tap down.** The old line
  was `stopHealthTimer()`. The replacement would have to pass `self` out of an `isolated deinit`,
  which is exactly what weak subscription exists to avoid; the next tick prunes the dead entry and
  stops the timer. The monitor lives for the process lifetime in practice.
- **Three doc files changed that are not in Expected files to modify** — `docs/development.md`,
  `docs/snippets.md`, `docs/refactor/checklists/testing.md`. All three are the same harness command
  line. None is on the must-NOT-change list. Operator approved before implementation.
- **The subscribers hold the ticker in a settable `weak var`, not an init parameter.**
  `DoubleTapMonitor` is constructed and started by `HotKeyManager`, which is not in the phase's file
  list, so an init or `start(healthTicker:)` parameter would have widened the diff. `AppCore.start()`
  assigns all three before `hotKeys.start`, `hyperKeyTap.start` and `startSnippetKeywordListener`.

---

## Follow-up work

| Observation                                                                                          | Where                                     | Suggested phase          |
| ---------------------------------------------------------------------------------------------------- | ----------------------------------------- | ------------------------ |
| `HyperKeyTap.healthCheck()` ends with a stray blank line before its closing brace                     | `Core/HotKey/HyperKeyTap.swift` ~386      | 34 (comment/format pass) |
| `AppCore.swift` carries 27 pre-existing stacked comment blocks; this phase adds none                  | `Core/AppCore.swift`                      | 34 (comment pass)        |
| The idle back-off (poll 1.5 s after 60 s idle) is still unmeasured and unimplemented — out of scope here | `Core/ClipboardManager.swift`           | needs `powermetrics` first |
| Phase-01 Instruments baselines were never captured, so no before-numbers exist for any M1 phase       | `progress/01`                             | 34 (final measurement)   |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. Purely in-memory — no persistence, no migration, no format.
  The three timers come back independently, with no state to reconcile.
- **Dependent phases that must also be reverted:** none. No phase lists 10 as a dependency. Phase 15
  (`HotKeyManager` → `@Observable`) touches the same subsystem but does not build on this.
- **Data risk on revert:** none.

---

## Sign-off

- [x] All acceptance criteria met
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
