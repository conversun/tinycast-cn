# Phase 06 — HotKey binding cache

**Milestone:** M1 · **Effort:** M · **Risk:** Low · **Context:** Med

> **Compatibility policy applies.** See [`../POLICY.md`](../POLICY.md). The persisted key format is no longer frozen for compatibility. Changing it is still
> not this phase's objective — that is phase 35.

---

## Overview

`HotKeyManager.binding(for:)` reads `UserDefaults` and JSON-decodes on every call — ~140 times at launch,
up to ~70 per keystroke while a shortcut recorder is open, and once per visible launcher row per render.
Load the bindings into memory once and write through on change.

## Why this phase exists

Beyond the wasted work, this is a prerequisite: `HotKeyManager` currently calls `objectWillChange.send()`
manually because its state lives in `UserDefaults` rather than in a stored property. Phase 15 cannot
migrate it to `@Observable` until it has real state to observe.

## Architecture Review reference

**M-4** · §6 P-5 · C-3 wave C

## Objectives

1. Add `private var bindings: [HotKeyAction: HotKeyBinding]`, populated once in `start()`.
2. Serve every read from it; write through to `UserDefaults` on every mutation.
3. Cache `candidateActions` and invalidate it in `setBinding`.
4. Keep `UserDefaults` the on-disk source of truth, in its current shape — reshaping it is phase 35.

## Expected files to modify

| File                                | Change                                                       |
| ----------------------------------- | ------------------------------------------------------------ |
| `Tinycast/Core/HotKeyManager.swift` | The cache, the write-through, the cached `candidateActions`. |

## Files that must NOT change

- `Tinycast/Core/HotKey/HotKeyBinding.swift` — its `Codable` conformance is phase 35's to change, not this one's
- `Tinycast/Core/HotKey/KeyShortcut.swift`
- `Tinycast/Core/HotKey/HotKeyCenter.swift`
- `Tinycast/Core/HotKey/DoubleTapMonitor.swift`
- `Tinycast/Core/Backup/SettingsBackup.swift` — it reads through `binding(for:)` and must keep working
  unchanged

## Implementation boundaries

- **Do not change the persisted format in this phase.** Under [`POLICY.md`](../POLICY.md) it is no
  longer frozen for compatibility — but this phase is about caching reads, not about redesigning
  storage. Retiring the legacy `KeyboardShortcuts_<name>` key and the JSON-string encoding is
  **phase 35**, where it gets its own diff and its own verification.
- The four bound-ID index keys (`boundAppBundleIDs`, `boundPaneBundleIDs`, `boundCustomCommandIDs`,
  `boundQuicklinkIDs`) keep their names and semantics for the same reason.
- `binding(for:)` keeps its exact signature and return type.
- **Do not** make the cache lazy-per-key. Populate the whole map in `start()` from `candidateActions`, so
  there is one load and no cache-miss path to reason about.
- `prune(key:live:action:)` must still delete the orphaned defaults keys _and_ update the index — the
  in-memory map must reflect the pruned state.
- Do not add `@Observable`, do not remove `objectWillChange.send()`. That is phase 15.
- Do not change `conflictOwner`'s semantics: comparing whole `HotKeyBinding` values is what gives
  double-taps conflict detection on the same terms as combos.

## Detailed acceptance criteria

1. `binding(for:)` performs no `UserDefaults` read and no JSON decode after `start()` has run.
2. `setBinding` updates the map **and** `UserDefaults` **and** the relevant bound-ID index, atomically
   from the caller's point of view.
3. `candidateActions` is computed at most once per mutation, not once per access.
4. `syncDoubleTaps()` reads the map, not `UserDefaults`.
5. The stored format is unchanged **by this phase** — it is phase 35's to change.
6. A binding survives quit and relaunch **within this build**.
7. `SettingsBackup` export → import still round-trips.
8. Launch-time `binding(for:)` calls drop from ~140 to the single population pass.

## Manual verification checklist

- [ ] `checklists/build.md` including the **startup timing** step
- [ ] `checklists/testing.md` — `hotkey-test`
- [ ] `checklists/regression.md` — Core sweep + **Hotkeys** in full
- [ ] Wipe the Dev channel, launch, set three shortcuts (a combo, a double-tap, a per-app one)
- [ ] Quit and relaunch → all three still fire
- [ ] Set a new combo shortcut; it fires immediately without a relaunch
- [ ] Delete a binding with plain Delete in the recorder; it stops firing and the key is removed
- [ ] Trigger a conflict; the recorder names the correct current owner
- [ ] Delete a custom command that had a binding; the binding and its index entry are both cleaned up
- [ ] Export a settings backup, wipe the Dev channel, import it → every binding comes back

## Regression risks

| Risk                                                                                                 | Mitigation                                                                                             |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| **Cache and `UserDefaults` drift after a prune** — the map says bound, disk says not, or the reverse | AC2; verify by deleting a bound custom command                                                         |
| A binding is lost across a relaunch because the write-through missed a path                          | AC6                                                                                                    |
| A binding set by an _external_ write (a settings import) is not seen                                 | `SettingsBackup.apply` calls `setBinding`, so it goes through the write-through path — confirm it does |
| Recorder conflict detection breaks                                                                   | Manual conflict test                                                                                   |
| Double-tap map rebuilt from stale data                                                               | AC4                                                                                                    |

## Rollback strategy

`git revert <sha>`. Safe: `UserDefaults` remains the source of truth throughout, so a revert goes back
to reading it directly. **No data risk** — and under [`POLICY.md`](../POLICY.md) local data is
disposable anyway.

## Expected commit size

1 file, +55 / −25 lines.

## Suggested commit message

```
Cache hotkey bindings in memory

binding(for:) re-read UserDefaults and JSON-decoded on every call —
~140 times at launch and up to ~70 per keystroke while recording. Load
once in start(), write through on change. The stored format is left alone
here; retiring the legacy key shape is phase 35.
```

## Dependencies

Phase 01. **Blocks phase 15.**

## Definition of Done

- All acceptance criteria met
- Bindings verified to survive a relaunch from a clean install
- Merged

## Estimated difficulty

**Low–Medium.** The logic is simple. The care goes into `prune` ordering and the write-through paths.

## Estimated Claude context usage

**Medium** — one file, but it is 227 dense lines with four persistence namespaces.

## Notes for reviewers

- Check `prune` carefully: it runs at `start()` either before the map is populated or after, and
  getting that order wrong leaves a pruned binding live in memory for the whole session.
- `setBinding` has four `switch` arms updating four different index keys. Confirm all four still work —
  app, settings pane, custom command, quicklink.
- **Reject any attempt to "simplify" `HotKeyBinding.Codable` here.** The policy permits it; this phase
  does not. It belongs in phase 35 with its own verification, not smuggled into a caching change.
