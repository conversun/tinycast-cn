# Phase 06 — HotKey binding cache

---

## Status

| Field                         | Value                              |
| ----------------------------- | ---------------------------------- |
| **Status**                    | Complete                           |
| **Started**                   | 2026-08-05                         |
| **Completed**                 | 2026-08-05                         |
| **Operator**                  | abue-ammar                         |
| **Branch**                    | `refactor/06-hotkey-binding-cache` |
| **Commit**                    | single commit on the branch        |
| **Claude conversations used** | 1                                  |
| **Actual effort**             | ~0.5h vs. estimate of M            |

---

## Completed tasks

- [x] Objective 1 — `private var bindings: [HotKeyAction: HotKeyBinding]`, populated once in `start()`
- [x] Objective 2 — every read served from it; `setBinding` writes through to `UserDefaults`
- [x] Objective 3 — `candidateActions` cached in `candidateActionsCache`, invalidated in `setBinding`
- [x] Objective 4 — `UserDefaults` still the on-disk source of truth, in its current shape

### Where the three moving parts live

| Part              | Location                     | Detail                                                                                         |
| ----------------- | ---------------------------- | ---------------------------------------------------------------------------------------------- |
| Populated         | `HotKeyManager.swift:50`     | One pass over `candidateActions` calling `storedBinding(for:)`                                 |
| Written through   | `HotKeyManager.swift:94–102` | Map and `UserDefaults` assigned in the **same branch**, so a failed encode cannot split them   |
| Cache invalidated | `HotKeyManager.swift:123`    | After the four-arm index switch, **before** `syncDoubleTaps()` so the rebuild sees the new set |

**`prune` ordering.** Both `prune` calls run _before_ the population loop. `prune` deletes the orphaned
defaults keys and rewrites the index; `candidateActions` is first computed — and first cached — only
after that, so the map is built from the already-pruned index and a dropped record never enters memory
for the session. `prune` needs no cache invalidation of its own because nothing has read
`candidateActions` at that point; `start()` is its only caller.

## Acceptance criteria

- [x] AC1 — `binding(for:)` performs no `UserDefaults` read and no JSON decode after `start()` —
      verified by: it is `bindings[action]`, and `grep -n 'storedBinding'` shows exactly one call site,
      the population loop. The only `UserDefaults.standard.string(forKey: action.defaultsKey)` in the
      file is inside `storedBinding`
- [x] AC2 — `setBinding` updates map **and** `UserDefaults` **and** the bound-ID index, atomically from
      the caller's view — verified by: one synchronous `@MainActor` call; both stores are assigned in the
      same `if let` branch, and all four index arms (app, pane, custom command, quicklink) are untouched
      below it. Operator confirmed at runtime by deleting a bound custom command — binding and index
      entry both cleaned up
- [x] AC3 — `candidateActions` computed at most once per mutation — verified by: the getter returns the
      cache when non-nil, and `candidateActionsCache = nil` appears exactly once, in `setBinding`
- [x] AC4 — `syncDoubleTaps()` reads the map, not `UserDefaults` — verified by: it calls
      `binding(for:)`, which is now the map lookup. Operator confirmed a double-tap binding still fires
- [x] AC5 — stored format unchanged by this phase — verified by: `HotKeyBinding.swift` and
      `KeyShortcut.swift` absent from `git diff --name-only`; the encode path is byte-identical;
      `storedBinding` is the old reader verbatim; all four index key names kept
- [x] AC6 — a binding survives quit and relaunch — **verified at runtime by the operator**, wiping the
      Dev channel, setting shortcuts, quitting and relaunching
- [x] AC7 — `SettingsBackup` export → import round-trips — **verified at runtime by the operator.**
      `SettingsBackup.swift` is untouched; export reads `binding(for:)` plus the still-`UserDefaults`-backed
      index vars, import writes through `setBinding`, so its per-item `conflictOwner` check sees each
      preceding insert because every `setBinding` invalidates the candidate cache
- [x] AC8 — launch-time `binding(for:)` calls drop to the single population pass — verified
      **statically only**: `storedBinding` has one call site. The "~140" figure was never measured, and
      phase 01 left no baseline to measure it against

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | §1 `xcodegen generate` clean, **no** `.xcodeproj` churn (correct — no files added). §2 Debug `BUILD SUCCEEDED`, zero compiler warnings, zero new against a pre-phase baseline captured on this branch, no Swift 6 concurrency diagnostics, no isolation escapes added. §3 Release not required (no generic/`@inlinable`/engine code, not M1's last phase) but run anyway — `BUILD SUCCEEDED`, zero type-checker timeouts. §4 below. §5 launch and §6 startup timing run by the operator |
| `checklists/testing.md`    | PASS   | `hotkey-test` — 34 passed, 0 failed, exit 0. By the harness → source map **no** harness is strictly mandatory: `hotkey-test` compiles `DoubleTapModifier.swift` + `DoubleTapDetector.swift`, not `HotKeyManager.swift`. It ran because the phase document names it as a gate. Phase 06 is not a milestone boundary, so the full suite was not required. Purity invariant intact — one non-pure file changed, no import added anywhere in the diff                                       |
| `checklists/regression.md` | PASS   | Core sweep + **Hotkeys** in full + **Clean install** (phase 06 is listed in both), run by the operator against a wiped Dev channel, who reported everything passing                                                                                                                                                                                                                                                                                                                     |
| `checklists/review.md`     | PASS   | §1–8 mechanically clean. 1 file, +16/−4 against an expected +55/−25 — under, not over. No file from the must-NOT-change list appears                                                                                                                                                                                                                                                                                                                                                    |

### Measurements

| Metric                     | Before    | After     | Δ                                         |
| -------------------------- | --------- | --------- | ----------------------------------------- |
| Binary size (Release)      | 3,473,464 | 3,489,992 | **+16,528 B (+0.476 %)**                  |
| Clean install verified?    | —         | yes       | operator-verified against a wiped channel |
| Cold launch, median of 3   | —         | —         | operator-run; no phase-01 baseline exists |
| RSS after 10 palette opens | —         | —         | n-a, see below                            |
| Phase-specific signpost    | —         | —         | no signpost covers `binding(for:)`        |

**On the binary.** The "before" figure was measured by stashing the change and building Release from
HEAD on the same tree, so +16,528 B is phase 06's own contribution and not phase 05's — phase 05 added
zero bytes. It is under `build.md` §4's 2 % ceiling, but it is the largest single-phase growth so far
(01: +1,856 · 02: +0 · 03: +0 · 04: +16 · 05: +0). The cause is the Release-specialized
`Dictionary<HotKeyAction, HotKeyBinding>` metadata and witness tables — a generic instantiation the
binary did not previously carry. It is the direct price of the phase's objective.

> The 3,489,992-byte binary is over `build.md` §4's 3 MB upto 4MB budget, and was already over it at the phase-01
> baseline of 3,473,448. Pre-existing, recorded the same way in `progress/03` and `progress/04`.

**On memory.** This phase adds a cache, which `checklists/review.md` §4 otherwise forbids — authorised
here because it is the objective. Retained: one dictionary holding only actually-bound actions, plus a
cached array of a few dozen enum values. Single-digit KB against a 40–80 MB footprint.

---

## Failed tasks

None.

---

## Issues encountered

- **The population loop and `prune` had to be ordered deliberately, and the phase document is right to
  flag it.** Prune-then-populate means a record deleted while Tinycast was not running never reaches the
  map. Populate-then-prune would have left it live in memory for the whole session while the defaults
  key was already gone — the cache/disk drift the phase's risk table names, and invisible until the
  stale shortcut fired.
- **A `nil` binding whose encode fails is the one place map and index can still disagree.** The index
  arms key off `binding != nil`, so a non-`nil` binding that fails to encode marks the index bound while
  both stores end up unbound. This is pre-existing and was preserved exactly; encoding a `HotKeyBinding`
  cannot realistically fail. Noted rather than fixed, per the phase's scope.
- **Two existing comments were falsified by the change and were reworded in place**, not left to rot:
  the `decoder` rationale said "allocates dozens per edit" (there is no per-edit scan any more) and the
  `syncDoubleTaps` guard said "a rebuild re-decodes every action" (it no longer decodes). Both stayed
  one line.
- **The GUI verification could not be done from the agent side** — no screen recording, and `open` fails
  from this shell. The whole of `regression.md`, plus `build.md` §5–6, was run by the operator.

---

## Deviations from the phase document

- **Diff is +16/−4 against an expected +55/−25.** Substantially under. The phase reads as though the
  cache needs new plumbing; in practice `conflictOwner`, `register` and `syncDoubleTaps` all already
  funnel through `binding(for:)`, so redirecting that one accessor to the map carried them for free.
  AC4 in particular required no edit at all.
- **`storedBinding(for:)` is a new private method the phase document does not name.** It is the old
  `binding(for:)` body moved verbatim so the decode has exactly one home, which is what makes AC1
  checkable by grep. Not a new abstraction — the same code under a name.
- **One behaviour narrowing, entailed by the phase's own instruction.** The map covers exactly
  `candidateActions`, which the phase requires ("populate the whole map in `start()`… do not make the
  cache lazy-per-key"). So an _orphaned_ defaults key — an app or settings pane whose bundle ID is no
  longer in `boundBundleIDs` / `boundPaneBundleIDs` — now reads as unbound, where `binding(for:)`
  previously surfaced it. The old code already ignored such orphans in `start()`'s register loop and in
  `syncDoubleTaps`, so reads now agree with registration rather than contradicting it. Unreachable in
  normal use: nothing writes the key without also writing the index. Reviewed and accepted by the
  operator.
- **No Release build was required** by `build.md` §3, but one was run to get an honest size figure.

---

## Follow-up work

| Observation                                                                                                                                                           | Where                               | Suggested phase                  |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | -------------------------------- |
| `setBinding`'s index arms key off `binding != nil` rather than the write that actually landed, so a failed encode marks the index bound while both stores are unbound | `Core/HotKeyManager.swift:107–120`  | none — pre-existing, unreachable |
| `boundBundleIDs` and `boundPaneBundleIDs` have no `prune` counterpart the way the two UUID indexes do, so an uninstalled app's index entry lingers indefinitely       | `Core/HotKeyManager.swift:63–71`    | new phase, if ever               |
| `HotKeyManager` still calls `objectWillChange.send()` by hand; it now has real stored state to observe, which is the prerequisite this phase existed to create        | `Core/HotKeyManager.swift:92`       | **phase 15** (as planned)        |
| Retiring the legacy `KeyboardShortcuts_<name>` key and the JSON-string encoding — deliberately not smuggled in here                                                   | `Core/HotKey/KeyShortcut.swift:161` | **phase 35** (as planned)        |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes — one file, no persistence shape change, no key rename. The
  reverted code reads the same `UserDefaults` the new code writes.
- **Dependent phases that must also be reverted:** none yet. **Phase 15 depends on 06** and must not
  start against a reverted 06, since it migrates this state to `@Observable`.
- **Data risk on revert:** none. `UserDefaults` is the source of truth throughout, so a revert simply
  goes back to reading it directly.

---

## Sign-off

- [x] All acceptance criteria met
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
