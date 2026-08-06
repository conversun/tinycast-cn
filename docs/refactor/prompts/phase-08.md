# Phase 08 kickoff — Parallel uninstall scan

Read `docs/refactor/phases/08-parallel-uninstall-scan.md` completely before editing.

## Task

`UninstallScanner.scan()` is serial end to end. Parallelise **both** phases — root enumeration and
directory sizing — with `TaskGroup`s.

## Hard gates

- **Uncapped by design.** No `activeProcessorCount` limit, no semaphore, no chunking. This is a short
  user-initiated burst where the user is blocked on a placeholder; spend the machine.
- **Display order must not change, and must be preserved structurally rather than incidentally:**
  - Phase 1 writes each root's results into a **pre-sized array at that root's own index**, so
    `UninstallSearchRoot.all` order survives.
  - Phase 2 mutates only the `size` field of a row already in place.
  - Nothing sorts by completion.
  - The final ordering statement — bundle first, leftovers `.sorted { $0.path < $1.path }` — stays
    exactly as written.
- **Dedup must not race.** The `seen` `Set` currently mutates inside the serial loop. Move it to a
  single pass over the flattened, index-ordered array. Never share a `Set` across tasks.
- `try? Task.checkCancellation()` inside each child task so `UninstallSession.cancel()` still releases
  the whole scan.
- `SizeBudget.maxEntries` stays 250,000.
- **Do not touch the five pure files** — `UninstallTarget`, `UninstallSearchRoot`, `UninstallRules`,
  `UninstallProtection`, `UninstallPlan`. They are harness-compiled.
- Do not touch `UninstallRunner.swift` or `UninstallView.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run `uninstall-test` — mandatory. Then search your own diff:

```
git diff | grep -n "\.sorted"        # only the existing path sort on leftovers
git diff | grep -n "seen.insert"     # exactly one place, outside any task group
```

## Summarise

Use the system-prompt format. Explain **in one paragraph** how index-ordered writeback guarantees the
displayed order, and state where dedup runs relative to the gather.
