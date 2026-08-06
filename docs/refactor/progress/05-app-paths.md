# Phase 05 — `AppPaths`, one channel-directory helper

---

## Status

| Field                         | Value                       |
| ----------------------------- | --------------------------- |
| **Status**                    | Complete                    |
| **Started**                   | 2026-08-05                  |
| **Completed**                 | 2026-08-05                  |
| **Operator**                  | abue-ammar                  |
| **Branch**                    | `refactor/05-app-paths`     |
| **Commit**                    | single commit on the branch |
| **Claude conversations used** | 1                           |
| **Actual effort**             | ~0.5h vs. estimate of S     |

---

## Completed tasks

- [x] Objective 1 — `Tinycast/Core/AppPaths.swift` added with `caches(bundleID:)` and
      `applicationSupport(bundleID:)`, both defaulting to `Bundle.main.bundleIdentifier ?? "com.tinycast.app"`
- [x] Objective 2 — adopted in exactly the four non-harness-compiled call sites
- [x] Objective 3 — channel isolation kept; every resolved path is still keyed by the bundle identifier

## Acceptance criteria

- [x] AC1 — `AppPaths.swift` exists, is Foundation-only, no dependency on any other app type — verified by:
      it imports only `Foundation`, and it compiles **standalone** under
      `swiftc -swift-version 6 Tinycast/Core/AppPaths.swift <driver>` with no other app source on the
      command line. Directory creation stayed inside the helper, as the phase requires
- [x] AC2 — adopted in exactly the four non-harness types — verified by: `git diff --name-only` lists
      `CalculatorHistoryStore`, `CurrencyRateStore`, `Emoji/FrequentEmojiStore`, `OnboardingState` and
      nothing else under `Tinycast/`
- [x] AC3 — the four harness-compiled types are untouched — verified by:
      `git diff --name-only HEAD | grep -E "ClipboardStore|QuicklinkStore|LauncherRankingStore|SnippetRepository"`
      returns nothing. Each keeps its own inline fallback and its injectable parameter
- [x] AC4 — every path keyed by `Bundle.main.bundleIdentifier` — verified two ways: the default argument is
      literally `Bundle.main.bundleIdentifier ?? "com.tinycast.app"` at both entry points, and a standalone
      driver confirmed `caches(bundleID:)` / `applicationSupport(bundleID:)` append the id as the last path
      component, create the directory, and are idempotent. Resolved paths are byte-identical to the
      pre-phase ones (table below)
- [x] AC5 — all harnesses pass with **no command-line change** — verified by: every `swiftc` line copied
      verbatim from `docs/development.md`; all 16 built and reported `ALL PASSED`
- [x] AC6 — `AGENTS.md` and `docs/development.md` unchanged — verified by: neither appears in
      `git diff --name-only`; no harness command line was edited or added to
- [x] AC7 — clean install works — **verified at runtime by the operator.** All four stores initialise from
      nothing, nothing crashes on an absent file

### Resolved paths (AC4 evidence)

| Type                     | Resolved path                                          | Changed? |
| ------------------------ | ------------------------------------------------------ | -------- |
| `CalculatorHistoryStore` | `~/Library/Caches/<bundle-id>/calculator-history.json` | no       |
| `FrequentEmojiStore`     | `~/Library/Caches/<bundle-id>/emoji-frequency.json`    | no       |
| `CurrencyRateStore`      | `~/Library/Caches/<bundle-id>/currency-rates.json`     | no       |
| `OnboardingState`        | `~/Library/Application Support/<bundle-id>/onboarded`  | no       |

`<bundle-id>` is `Bundle.main.bundleIdentifier`, i.e. `com.tinycast.app.dev` for a Debug build and
`com.tinycast.app` for a release one. No path string changed, which `POLICY.md` would have permitted but
the phase discourages as diff noise.

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | Debug `BUILD SUCCEEDED`, zero Swift warnings and zero errors. **No pre-phase baseline was captured** (operator elected to skip it), so "zero _new_ warnings" is asserted from an absolute zero rather than a diff against a baseline                                                                                                                                                                                                         |
| `checklists/testing.md`    | PASS   | All 16 harnesses in `docs/development.md` run with unmodified command lines: `fuzz`, `ranking`, `calc`, `clipboard`, `scopes`, `raycast`, `emoji`, `custom-command`, `snippets`, `hotkey`, `callout`, `system-action`, `volume`, `window-command`, `uninstall`, `quicklink` — all `ALL PASSED`. The four harness-compiled stores were deliberately not touched, which is what keeps `clipboard`, `quicklink`, `ranking` and `snippets` green |
| `checklists/regression.md` | PASS   | Core sweep + **Clean install**, run by the operator, who confirmed the app works                                                                                                                                                                                                                                                                                                                                                             |
| `checklists/review.md`     | PASS   | 5 files, +25/−27 against an expected 5 files, +35/−25. Under on additions because the helper is shared rather than restated                                                                                                                                                                                                                                                                                                                  |

### Measurements

| Metric                     | Before | After | Δ                                     |
| -------------------------- | ------ | ----- | ------------------------------------- |
| Binary size (Release)      | —      | —     | not measured; no Release build run    |
| Clean install verified?    | —      | yes   | operator-verified                     |
| Cold launch, median of 3   | —      | —     | n-a, no startup work added or removed |
| RSS after 10 palette opens | —      | —     | n-a, no allocation change             |
| Phase-specific signpost    | —      | —     | no signpost covers this               |

This phase claims no performance effect: the same `FileManager` calls run the same number of times, just
from one place instead of four.

---

## Failed tasks

None.

---

## Issues encountered

- **`OnboardingState` was the only adopter whose directory creation moved.** It alone created its directory
  in `markShown()` rather than when computing the URL, so adopting `AppPaths` — which creates on demand —
  made those two lines redundant and they were deleted. Observably a no-op: `QuicklinkStore.init` already
  creates that exact Application Support directory unconditionally at launch, before either
  `OnboardingState.hasOnboarded` or `markShown()` is reached.
- **`kill` is blocked in this environment**, so the already-running Dev instance could not be quit from the
  agent side. The clean-install run was done by the operator instead. The Dev channel's Caches and
  Application Support directories were snapshotted to the session scratchpad before any wipe was
  attempted; nothing was deleted.
- **`docs/development.md` lists 16 harnesses, not 17.** The phase document, `ROADMAP.md` and
  `checklists/testing.md` all say "all 17 harnesses". Counting the `swiftc` invocations in
  `docs/development.md` gives 16. All 16 were run; the 17th does not exist. Recorded as a doc fix below.

---

## Deviations from the phase document

- **`Tinycast.xcodeproj/project.pbxproj` also changed.** It is a committed generated file and `xcodegen
generate` registers the new source. Not listed in the phase's file table, but unavoidable and mechanical.
- **Diff is +25/−27 rather than the expected +35/−25**, i.e. net negative. Four five-line blocks collapsed
  to four one-line calls, and the helper is 26 lines including its signature wrapping.
- **No pre-phase warning baseline.** `checklists/build.md` scores new warnings against a baseline; the
  operator skipped capturing one. Mitigated by the build reporting zero Swift warnings outright.

---

## Follow-up work

| Observation                                                                                                                                                                                                                                                                                     | Where                                                     | Suggested phase    |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------------------ |
| The refactor docs say "all 17 harnesses" but `docs/development.md` defines 16. Every phase that gates on the count inherits the error                                                                                                                                                           | `ROADMAP.md`, `checklists/testing.md`, several phase docs | doc fix, no phase  |
| `ClipboardStore`, `QuicklinkStore`, `LauncherRankingStore` and `SnippetRepository` still each carry their own copy of the bundle-id fallback. Consolidating them needs an `AGENTS.md` invariant change to let `AppPaths.swift` join four harness command lines — deliberately out of scope here | those four files                                          | new phase, if ever |
| `QuicklinkStore` and `SnippetRepository` both compute the Application Support root independently, and `QuicklinkStore.defaultDirectory` documents the shared root in a comment rather than in code                                                                                              | `Core/Quicklinks/QuicklinkStore.swift:52`                 | same as above      |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes — five files, no persistence shape change, no path string change.
- **Dependent phases that must also be reverted:** none. No later phase depends on 05.
- **Data risk on revert:** none. The reverted code resolves the same paths the new code does, so a store
  written before the revert is read after it.

---

## Sign-off

- [x] All acceptance criteria met
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
