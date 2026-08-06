# Phase 07 — Settings-pane scan cache

---

## Status

| Field                         | Value                                   |
| ----------------------------- | --------------------------------------- |
| **Status**                    | Complete                                |
| **Started**                   | 2026-08-05                              |
| **Completed**                 | 2026-08-05                              |
| **Operator**                  | abue-ammar                              |
| **Branch**                    | `refactor/07-settings-pane-scan-cache`  |
| **Commit**                    | single commit on the branch             |
| **Claude conversations used** | 1                                       |
| **Actual effort**             | ~0.5h vs. estimate of M                 |

---

## Completed tasks

- [x] Objective 1 — pane entries cached, invalidated by the mtime of `/System/Library/ExtensionKit/Extensions`
- [x] Objective 2 — threaded through `AppIndex` as a **value**, exactly as `alternateNameCache` is
- [x] Objective 3 — pane list, ordering and display names preserved exactly

### Where the moving parts live

| Part            | Location                          | Detail                                                                        |
| --------------- | --------------------------------- | ----------------------------------------------------------------------------- |
| Cache type      | `SettingsPaneScanner.swift:18–21` | `struct Cache: Sendable` — a `Date` and the scanned `[AppEntry]`, both `fileprivate` |
| Validity gate   | `SettingsPaneScanner.swift:25–28` | Directory date re-stat'd every call; `cache.modified == modified` is the only gate |
| Held            | `AppIndex.swift:335`              | `private var paneCache: SettingsPaneScanner.Cache?`, beside `alternateNameCache` |
| Threaded        | `AppIndex.swift:440–447`          | Read into a local → detached scan → stored back, mirroring the Spotlight cache |

**Why `Cache?` and not `Cache`.** The optional *is* the failure signal. A failed `contentsOfDirectory`
returns `([], nil)` and an unreadable directory date returns a `nil` cache alongside good entries, so
neither can be pinned for the life of the process — the next refresh retries. The phase document called
this out explicitly and it is the one place the design could have gone quietly wrong.

**Why `init(reusing:)` was not copied.** `SpotlightNames.Cache` prunes so uninstalled apps fall out of a
per-URL dictionary that would otherwise accumulate. The pane cache is a single directory listing
replaced wholesale — there is no per-key accumulation, so the pruning ceremony would be dead weight.
Considered, not overlooked.

## Acceptance criteria

- [x] AC1 — a second `refresh()` with an unchanged directory performs **zero** plist reads — verified by
      a scratch harness compiling the real `SettingsPaneScanner.swift`: the warm pass measured
      **0.014 ms** against a 16.5 ms cold pass. 52 panes × 2 plist deserialisations cannot occur in
      14 µs. Not verified via the phase-01 signpost or `fs_usage` — no baseline exists (see `progress/01`)
- [x] AC2 — published `.systemSettings` list identical — verified **empirically**: the pre-phase scanner
      (from `HEAD`) was compiled alongside the new one against a stubbed `AppEntry`. **52 panes both
      ways**, with `id`, `name` and `bundleID` sequences equal element-for-element **in order**. Five
      repeat warm passes stayed identical. Operator additionally confirmed the section visually
- [x] AC3 — invalidated when the directory mtime changes — verified **by inference, not by trigger**.
      `/System`'s mtime cannot be altered to force it. What is verified: the date is re-stat'd on every
      call (it sits inside the 0.014 ms warm path) and the equality check is the sole gate, so a moved
      date necessarily falls through to the full rescan
- [x] AC4 — no static mutable state — verified by: value-threaded, as the phase preferred. `AppEntry` is
      already `Sendable`, so **no `Sendable` constraint forced a static and no lock was needed**. The
      escape hatch in the phase document went unused
- [x] AC5 — `AppIndex.scan` remains `nonisolated` and still called from `Task.detached` — verified by:
      both unchanged in the diff; only the signature grew a parameter and a tuple element
- [x] AC6 — first-open cost unchanged — verified by: the cold path is the same body, plus one `stat`

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                             |
| -------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` clean, no `.xcodeproj` churn (correct — no files added). Debug `BUILD SUCCEEDED`; both changed files force-recompiled with zero errors and zero warnings. **No pre-phase warning baseline was captured** — the operator elected to skip it, so "zero new" rests on "zero total from these two files" |
| `checklists/testing.md`    | PASS   | `fuzz-test` (80 checks), `ranking-test` (29), `scopes-test` (19) — all exit 0. These are the three the phase names as gates. Purity invariant intact: no import added anywhere in the diff, and no harness-compiled file was touched |
| `checklists/regression.md` | PASS   | Core sweep + **Launcher & icons**, run manually by the operator, who reported everything passing                                                                                                                                    |
| `checklists/review.md`     | PASS   | 2 files, +24/−8 against an expected +45/−15 — under, not over. Both files are on the phase's **Expected files to modify** list; no file from the must-NOT-change list appears in `git diff --name-only`                             |

### Measurements

| Metric                     | Before  | After    | Δ                                              |
| -------------------------- | ------- | -------- | ---------------------------------------------- |
| Binary size (Release)      | —       | —        | not measured this phase                        |
| Clean install verified?    | —       | n-a      | in-memory only; phase 07 is not in the clean-install list |
| Cold launch, median of 3   | —       | —        | no phase-01 baseline exists                    |
| RSS after 10 palette opens | —       | —        | not measured; see below                        |
| `SettingsPaneScanner.scan` | 16.5 ms | 0.014 ms | **~1180× on the warm path**, harness-measured  |

**On the cold figures.** The scratch harness printed 98.7 ms for the pre-phase scanner and 16.5 ms for
the new cold path. That gap is the **OS page cache warming between the two runs, not a phase effect** —
the cold path is the same code. The only honest comparison is 16.5 ms cold vs 0.014 ms warm.

**On memory.** This phase adds a cache, which `checklists/review.md` §4 otherwise forbids — authorised
here because it is the objective. Retained: 52 `AppEntry` values (measured, not estimated) plus one
`Date`, bounded by the directory listing and replaced wholesale rather than accumulated. Low single-digit
KB against a 40–80 MB footprint.

---

## Failed tasks

None.

---

## Issues encountered

- **The failure case is the whole design, and it drove the type.** Returning a non-optional `Cache`
  would have been tidier but would have had to invent a sentinel date for "couldn't read". `Cache?`
  makes "this pass produced nothing cacheable" unrepresentable-as-success, which is what keeps a
  transient `contentsOfDirectory` failure from pinning an empty pane list for the whole session.
- **`cache.modified` is a non-optional `Date` compared against an optional.** `cache.modified == modified`
  relies on optional promotion: an unreadable date is `nil`, compares unequal, and falls through to a
  rescan. That is the desired direction — the unreadable case must never be treated as a cache hit — but
  it is subtle enough to be worth stating, since flipping the optionality would silently invert it.
- **AC3 is not empirically triggerable** on a shipped machine. `/System/Library/ExtensionKit/Extensions`
  cannot have its mtime moved, so the invalidation branch is reasoned about rather than exercised. The
  gate is one equality on a freshly-`stat`ed value, so the risk is low, but it is untested by
  construction and a future harness would need the directory injected.
- **The AC2 comparison was done by compiling the pre-phase scanner from `HEAD` next to the new one**
  against a stubbed `AppEntry`, in the scratchpad — not in the repo. That gave an element-for-element
  ordering check rather than an eyeballed screenshot diff, which is a stronger result than the phase
  document asks for.

---

## Deviations from the phase document

- **Diff is +24/−8 against an expected +45/−15.** Under. The cold scan body needed only its result bound
  to a name before returning; the phase reads as though the scan needed restructuring, and it did not.
- **The static-plus-`NSLock` fallback was not needed.** `AppEntry` is already `Sendable`, so the
  value-threaded form the phase preferred worked with no friction at all. Recording it explicitly
  because the phase document treats the `Sendable` threading as "the fiddly part" — it was not.
- **No pre-phase warning baseline was captured** (operator's call). `build.md` scores "zero **new**
  warnings" against one, so that check was substituted with "zero warnings from either changed file on a
  forced recompile".
- **Nothing else.** No new abstraction, no rename, no formatting-only edit.

---

## Follow-up work

| Observation                                                                                                                                | Where                                    | Suggested phase          |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------- | ------------------------ |
| Three pre-existing doc comments run well past the 100-char budget (the type doc, `displayName`, `loctableName`)                             | `Core/SettingsPaneScanner.swift:3,52,61` | **phase 34** (as planned) |
| `AppIndex.scan` now returns a 3-tuple; a fourth cache would justify a named result struct rather than widening it again                     | `Core/AppIndex.swift:454`                | none — only if it grows   |
| `Bundle(url:)` results and `SearchScopes.appBundles` are still uncached per the phase's explicit instruction; separate measurements needed  | `Core/AppIndex.swift:456`                | none — deliberate         |
| The mtime-invalidation branch is unreachable in a harness because `extensionsDir` is a hardcoded private constant                           | `Core/SettingsPaneScanner.swift:5`       | none unless it regresses  |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes — two files, purely in-memory, nothing persisted, no key or
  format change. The reverted code rescans on every refresh exactly as before.
- **Dependent phases that must also be reverted:** none. Nothing in the ROADMAP depends on 07.
- **Data risk on revert:** none — the cache lives only for the process's lifetime.

---

## Sign-off

- [x] All acceptance criteria met
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
