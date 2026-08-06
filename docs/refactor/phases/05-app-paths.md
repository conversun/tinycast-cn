# Phase 05 — `AppPaths`, one channel-directory helper

**Milestone:** M1 · **Effort:** S · **Risk:** Low · **Context:** Low

> **Compatibility policy applies.** See [`../POLICY.md`](../POLICY.md). Paths may change; existing local
> data may be discarded. Verification is a **clean install**, not a data-preservation check.

---

## Overview

Eight types independently compute their own per-channel storage directory with the same five lines and
the same `?? "com.tinycast.app"` fallback. Replace them with one helper.

## Why this phase exists

Channel isolation is a named invariant: _"Anything newly persisted must stay keyed by
`Bundle.main.bundleIdentifier`"_ — so a Dev build never shares prefs, caches or TCC grants with an
installed stable. Eight copies means eight chances for the ninth store to forget, and no single place to
audit.

## Architecture Review reference

**M-5**

## Objectives

1. Add `Tinycast/Core/AppPaths.swift`: `caches(bundleID:)` and `applicationSupport(bundleID:)`, both
   defaulting to `Bundle.main.bundleIdentifier ?? "com.tinycast.app"`.
2. Adopt it in the **four** non-harness-compiled call sites (see Implementation boundaries — the other
   four are excluded and that exclusion is the whole difficulty of this phase).
3. Keep channel isolation: every path stays keyed by the bundle identifier.

## Expected files to modify

| File                                             | Current directory   |
| ------------------------------------------------ | ------------------- |
| `Tinycast/Core/AppPaths.swift`                   | **New.** ~25 lines. |
| `Tinycast/Core/ClipboardStore.swift`             | Caches              |
| `Tinycast/Core/LauncherRankingStore.swift`       | Caches              |
| `Tinycast/Core/CalculatorHistoryStore.swift`     | Caches              |
| `Tinycast/Core/Emoji/FrequentEmojiStore.swift`   | Caches              |
| `Tinycast/Core/CurrencyRateStore.swift`          | Caches              |
| `Tinycast/Core/Quicklinks/QuicklinkStore.swift`  | Application Support |
| `Tinycast/Core/OnboardingState.swift`            | Application Support |
| `Tinycast/Core/Snippets/SnippetRepository.swift` | Application Support |

## Files that must NOT change

- `Tools/*.swift` — no harness may need editing. If one does, **stop**: see the boundary below.
- `docs/development.md`, `AGENTS.md` harness command lines
- Any view file

## Implementation boundaries

**The harness constraint is the whole difficulty of this phase.**

`ClipboardStore`, `QuicklinkStore`, `LauncherRankingStore` and everything in `Core/Snippets/` are
compiled standalone by `Tools/` harnesses. `AGENTS.md` says each must depend on **no other app source**.

Therefore:

- **`AppPaths` supplies the default argument only.** Each store keeps its existing injectable parameter
  (`directory:`, `fileURL:`, `applicationSupportRoot:`) and keeps its own inline fallback computation.
  Adopt `AppPaths` **only** in the non-harness-compiled types.
- Concretely: adopt in `CalculatorHistoryStore`, `FrequentEmojiStore`, `CurrencyRateStore`,
  `OnboardingState`. **Leave `ClipboardStore`, `QuicklinkStore`, `LauncherRankingStore` and
  `SnippetRepository` alone** — their injection point already serves the same purpose and touching them
  breaks four harnesses.
- If Claude proposes adding `AppPaths.swift` to a harness command line, **reject it**. That is a separate
  decision requiring an `AGENTS.md` invariant change, and it is not this phase.
- `AppPaths` creates the directory (`createDirectory(withIntermediateDirectories: true)`) exactly as the
  current call sites do — do not move that responsibility.
- **Path strings may change** (per [`POLICY.md`](../POLICY.md)) — but there is no reason for them to in
  this phase, and a gratuitous change makes the diff harder to read. Keep them unless a change makes
  `AppPaths` genuinely cleaner. **Channel isolation is not negotiable**: every path must still be keyed
  by `Bundle.main.bundleIdentifier`, so a Dev build never shares a directory with a stable one.

## Detailed acceptance criteria

1. `AppPaths.swift` exists, is Foundation-only, and has no dependency on any other app type.
2. Adopted in exactly the four non-harness types listed above.
3. The four harness-compiled types are **untouched**.
4. Every path is keyed by `Bundle.main.bundleIdentifier` — Dev and stable never share a directory.
5. All 17 harnesses pass with **no command-line change**.
6. `AGENTS.md` and `docs/development.md` unchanged.
7. A **clean install** works: with every Dev directory deleted, the app launches, all four stores
   initialise, and nothing crashes on an absent file.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — **all 17 harnesses**, no command-line edits
- [ ] `checklists/regression.md` — Core sweep + **Clean install** section in full
- [ ] Wipe the Dev channel (commands in `POLICY.md`), launch, and confirm: onboarding runs, the palette
      opens, no crash on any absent store file
- [ ] Copy something → clipboard history records it
- [ ] Do a calculation and press ↵ → it appears in Calculator History
- [ ] Use an emoji → it appears in Frequently Used
- [ ] Quit and relaunch → all three persisted and reloaded
- [ ] `ls ~/Library/Caches/com.tinycast.app.dev/` and
      `~/Library/Application Support/com.tinycast.app.dev/` → files are where `AppPaths` says
- [ ] Nothing was written outside `com.tinycast.app.dev/` (channel isolation intact)

## Regression risks

| Risk                                                                                | Mitigation                                                                                      |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Channel isolation breaks** and a Dev build writes into the stable app's directory | AC4 + the last verification step. This is the one storage invariant the policy does _not_ relax |
| A harness breaks because a pure file gained a dependency                            | AC3 + AC5; the boundary forbids touching those four                                             |
| `createDirectory` moves and a first-run store fails to write                        | AC1 keeps creation inside `AppPaths`; AC7's clean install is the test                           |
| A store crashes rather than starting empty when its file is absent                  | AC7                                                                                             |

## Rollback strategy

`git revert <sha>`. **No data risk** — under [`POLICY.md`](../POLICY.md) local data is disposable, so a
revert that orphans a file is not a problem. Wipe the Dev channel and relaunch.

## Expected commit size

5 files, +35 / −25 lines.

## Suggested commit message

```
Add AppPaths for the per-channel storage directories

Four stores computed the same caches/app-support path with the same
bundle-id fallback. One helper, one place to audit the channel-isolation
invariant. The harness-compiled stores keep their injected directory
parameter and are untouched.
```

## Dependencies

Phase 01.

## Definition of Done

- All acceptance criteria met
- Clean-install run verified and recorded in the progress file
- All 17 harnesses green with unmodified command lines
- Merged

## Estimated difficulty

**Low.** The code is trivial; knowing which four types _not_ to touch is the phase.

## Estimated Claude context usage

**Low.**

## Notes for reviewers

- **First thing to check:** did the diff touch `ClipboardStore`, `QuicklinkStore`,
  `LauncherRankingStore` or `SnippetRepository`? If yes, revert immediately — four harnesses are at
  stake and the phase explicitly excluded them.
- **Second:** did any harness command line change in `docs/development.md` or `AGENTS.md`? If yes,
  revert. That is a different, larger decision.
- Confirm every path still contains `Bundle.main.bundleIdentifier`. Channel isolation is the one storage
  guarantee [`POLICY.md`](../POLICY.md) does not relax, and losing it means a Dev build corrupts the
  installed app's state.
- Do the clean-install run. A store that crashes on an absent file instead of starting empty is now the
  realistic failure mode, and only a wiped directory surfaces it.
