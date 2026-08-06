# Phase 35 — Retire the compatibility machinery

**Milestone:** M7 · **Effort:** M · **Risk:** Low · **Context:** Med

> **This phase exists only because of [`POLICY.md`](../POLICY.md).** It deletes code whose sole purpose
> is compatibility with a Tinycast that, under the policy, has no users.

---

## Overview

Three pieces of the codebase exist purely to keep old data readable. The policy makes them dead. Delete
them and take the simplification.

## Why this phase exists

`docs/architecture-review.md` treats each of these as a fixed constraint, because at the time it was
written they were. The compatibility policy changes that, and leaving the machinery in place would mean
carrying complexity for a guarantee nobody needs — which is precisely the outcome the policy exists to
avoid.

It runs **last**, after the structural work, so it deletes code that has already settled rather than
code that is about to move.

## Architecture Review reference

Supersedes the compatibility clauses in **§2.4 hotkeys**, the `HotKeyBinding` note in
`AGENTS.md`'s Critical Invariants, and `checklists/review.md`'s legacy-key item.

## Objectives

1. Retire the legacy `KeyboardShortcuts_<name>` UserDefaults key namespace.
2. Simplify `HotKeyBinding`'s hand-written `Codable` conformance to the synthesised one.
3. Delete `ClipboardStore`'s two schema-migration `ALTER TABLE` guards.
4. Amend `AGENTS.md` so the contract matches reality — including **removing the refactor banner** at
   the top of it. The refactor is over; a banner announcing one in progress would be false.

## Expected files to modify

| File                                            | Change                                                                                                                |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `Features/HotKeys/Service/HotKeyBindings.swift` | Own key namespace, e.g. `hotkey.<action>`; drop the legacy prefix.                                                    |
| `Features/HotKeys/Model/HotKeyBinding.swift`    | Delete `init(from:)` / `encode(to:)`; synthesised `Codable`.                                                          |
| `Features/HotKeys/Model/KeyShortcut.swift`      | Only if its `Codable` was shaped by the legacy record.                                                                |
| `Features/Clipboard/Model/ClipboardStore.swift` | Delete the `source_app` and `pinned_at` `ALTER TABLE` migrations and `columnExists`; fold both columns into `schema`. |
| `Features/Backup/Model/SettingsBackup.swift`    | Drop the `version` field's back-compat comment; keep the field.                                                       |
| `AGENTS.md`                                     | Amend the three superseded clauses; remove the refactor banner.                                                       |
| `Tools/clipboard-test.swift`                    | Only if it asserts on the migration path.                                                                             |

## Files that must NOT change

- `Features/Backup/Model/Raycast*.swift` and `Tools/raycast-test.swift` — **external format**, not
  Tinycast's legacy (POLICY carve-out 3)
- `Features/Snippets/` Markdown serializer — user-authored interchange format
- `CurrencyRateStore` — its consent flag is a security control
- `SettingsBackup`'s `deliberatelyExcluded` set and the `snippetsEnabled` omission

## Implementation boundaries

- **Delete, do not translate.** No migration reads the old key and writes the new one. No fallback
  decoder. If a developer has old data, they wipe the Dev channel.
- The new hotkey key namespace must still be **per-action and stable within the build** —
  `HotKeyAction.defaultsKey` remains the single place that computes it.
- `SettingsBackup.HotkeyBackup` encodes `HotKeyBinding` values, so simplifying the conformance changes
  the **backup file format**. That is allowed: export → import must round-trip within this build, and
  nothing more. Verify it.
- `ClipboardStore`'s `schema` gains `source_app TEXT` and `pinned_at REAL` as ordinary columns. The
  `items_pinned_at` partial index can move into `schema` alongside them.
- `ClipboardStore` and `QuicklinkStore` remain harness-compiled and Foundation + SQLite3 only.
- Do **not** change the SQLite column _names_ — the row decoder, the prepared statements and the schema
  all reference them, and renaming buys nothing here (POLICY carve-out 2).
- Do not touch `HotKeyCenter`, `DoubleTapMonitor` or the double-tap detection. Only persistence changes.
- `HotKeyBinding` must still round-trip both cases — a `.combo` and a `.doubleTap` — through the
  synthesised conformance. Confirm with `hotkey-test` or a scratch round-trip.

## Detailed acceptance criteria

1. `grep -rn "KeyboardShortcuts_" Tinycast` returns nothing.
2. `HotKeyBinding` has no hand-written `init(from:)` or `encode(to:)`.
3. Both `HotKeyBinding` cases round-trip through `Codable`.
4. `ClipboardStore` has no `ALTER TABLE` and no `columnExists`; `schema` declares all seven columns.
5. `clipboard-test`, `quicklink-test` and `hotkey-test` pass, with any harness edits authorised here.
6. A settings backup exported by this build imports into this build with every binding restored.
7. `AGENTS.md`'s three superseded clauses are amended, **the refactor banner at the top is removed**,
   and `POLICY.md`'s "Conflicts" section is updated to say so.
8. Net line count is **negative**.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — all 19 harnesses
- [ ] `checklists/regression.md` — Core sweep + **Hotkeys** + **Clipboard** + **Clean install**
- [ ] **Wipe the Dev channel.** Launch. Set a combo shortcut, a double-tap shortcut and a per-app one
- [ ] Quit and relaunch → all three still fire
- [ ] `defaults read com.tinycast.app.dev | grep -i keyboardshortcuts` → nothing
- [ ] Export a settings backup → wipe again → import → all three bindings return and fire
- [ ] Copy text and an image; pin one; quit; relaunch → history intact, pin intact
- [ ] Clipboard search on a 2-char and a 4-char query (fallback and FTS paths both exercise the schema)
- [ ] Confirm a Raycast `.rayconfig` still imports (external format untouched)

## Regression risks

| Risk                                                                                                                                | Mitigation                                                           |
| ----------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| A binding fails to decode because the synthesised `Codable` shape differs from what was written moments earlier in the same session | AC3 + the set-quit-relaunch check                                    |
| `ClipboardStore`'s schema change breaks a _fresh_ database creation                                                                 | AC4 + the clean-install run; there is no old database to worry about |
| The backup format changes and export/import stops round-tripping                                                                    | AC6 — the only compatibility that still matters                      |
| Raycast import is caught up in the cleanup                                                                                          | On the must-not-change list; `raycast-test`                          |
| A migration is "helpfully" written to move old keys across                                                                          | Boundary: delete, do not translate                                   |

## Rollback strategy

`git revert <sha>`. **No data risk** — local data is disposable. After a revert, wipe the Dev channel and
re-set your shortcuts.

## Expected commit size

5–6 files, +40 / −140 lines. **Net negative** — that is the point of the phase.

## Suggested commit message

```
Retire the compatibility machinery

Under docs/refactor/POLICY.md there are no existing users, so the code
that existed only to keep old data readable is dead: the legacy
KeyboardShortcuts_ key namespace, HotKeyBinding's hand-written Codable
seam, and ClipboardStore's two ALTER TABLE migrations. Deleted rather
than translated — no migration path. AGENTS.md amended to match and
its refactor-in-progress banner removed.
Raycast import is untouched: that is another app's format, not our legacy.
```

## Dependencies

**Phases 29, 30 and 34.** Runs last so it deletes settled code.

## Definition of Done

- All acceptance criteria met
- `AGENTS.md` amended, refactor banner removed, `POLICY.md`'s conflicts section closed out
- Clean install + backup round-trip both verified
- Merged

## Estimated difficulty

**Low–Medium.** Deletion is easy; the care is in not deleting an external format by mistake.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **The net line count must be negative.** If it is not, something was rewritten rather than removed.
- Check that no migration snuck in. `grep -rn "ALTER TABLE\|legacy\|migrat" Tinycast` should come back
  clean apart from Raycast's own naming.
- Confirm `Raycast*` and the snippet Markdown serializer are absent from the diff. They look like legacy
  code and are not — they read formats Tinycast does not own.
- The backup round-trip is the one compatibility check that survives. Do it: export, wipe, import.
- Read the amended `AGENTS.md` clauses **and confirm the refactor banner is gone**. The contract has to
  end this roadmap accurate, or the next contributor inherits a document that lies twice — once about the
  hotkey format, once about a refactor that finished months ago.
