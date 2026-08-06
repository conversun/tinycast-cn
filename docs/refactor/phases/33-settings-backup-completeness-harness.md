# Phase 33 — `SettingsBackup` completeness harness

**Milestone:** M6 · **Effort:** M · **Risk:** Low · **Context:** Med

> **Compatibility policy applies.** See [`../POLICY.md`](../POLICY.md). **This phase is unaffected.** The `snippetsEnabled`
> exclusion is a _security_ control, not a compatibility one.

---

## Overview

`SettingsBackup` is a 336-line hand-written mirror of `AppSettings`. **Keep it manual** — and add a
harness that fails when a setting is added and neither backed up nor deliberately excluded.

## Why this phase exists

Adding a setting today requires five coordinated edits, and forgetting the `SettingsBackup` one is
silent: the setting simply does not round-trip through an export.

The temptation is codegen or `Codable` reflection. **Resist it.** The _explicit_ omission of
`snippetsEnabled` — which doubles as keystroke-listening consent — is a security control. Any mechanism
that auto-includes new properties would silently make the next consent flag backup-restorable, and
`AGENTS.md` states the rule: _"Consent flags live on the owning store, never in `AppSettings`… an import
must not grant network access."_

So: fix the failure mode, not the design.

## Architecture Review reference

**M-6**

## Objectives

1. Add `Tools/settings-backup-test.swift` asserting that every `AppSettings` UserDefaults key is either
   present in `SettingsBackup.SettingsData` or listed in an explicit exclusion set.
2. Add that exclusion set, with a reason per entry.
3. Register the harness everywhere the others are registered.

## Expected files to modify

| File                                                        | Change                                                                        |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `Tools/settings-backup-test.swift`                          | **New.**                                                                      |
| `Features/Backup/Model/SettingsBackup.swift`                | Add `deliberatelyExcluded`, documented.                                       |
| `Settings/AppSettings.swift`                                | Possibly expose the `Key` enum at `internal` so the harness can enumerate it. |
| `docs/development.md`, `AGENTS.md`, `checklists/testing.md` | Register the harness.                                                         |

## Files that must NOT change

- `SettingsBackup`'s `gather` and `apply` implementations — this phase adds a guard, it does not rewrite
  the mirror
- `CurrencyRateStore` — its consent flag is deliberately outside `AppSettings` and outside the backup
- Any other store

## Implementation boundaries

- **The mirror stays manual.** No `Codable` reflection, no `Mirror`, no macro, no code generation. If
  Claude proposes any of those, reject it and re-read this section.
- The exclusion set is a `static let deliberatelyExcluded: [String: String]` — key to **reason**. Today
  it holds exactly one entry:
  `"snippetsEnabled": "Doubles as keyword-expansion consent; an import must not enable keystroke listening."`
- The harness must be Foundation-only, like every other one. It cannot import AppKit, so it cannot
  instantiate `AppSettings`. Two workable approaches:
  - compile `AppSettings.swift`'s `Key` enum and `SettingsBackup.swift` together and compare the two
    static lists; or
  - if `AppSettings.swift` cannot be compiled standalone, extract **only** the `Key` enum into its own
    Foundation-only file and compile that.

  Prefer the second if the first does not work cleanly — a `SettingsKeys.swift` holding 25 string
  constants is a reasonable, purely additive extraction.

- The assertion is symmetric: every `Key` is covered, **and** every `SettingsData` field maps to a real
  `Key`. A field for a setting that no longer exists is also a defect.
- Do not add a "backup everything by default" fallback. The whole point is that omission must be
  deliberate and named.

## Detailed acceptance criteria

1. `Tools/settings-backup-test.swift` compiles standalone with `swiftc -swift-version 6` and Foundation
   only.
2. It fails if a `Key` is added without a `SettingsData` field or an exclusion entry — **verify by
   adding a scratch key, running it, then reverting**.
3. It fails if a `SettingsData` field names a key that does not exist.
4. `deliberatelyExcluded` contains `snippetsEnabled` with its reason.
5. `gather`/`apply` behaviour is unchanged — an export before and after the phase is byte-identical.
6. Registered in `docs/development.md`, `AGENTS.md` and `checklists/testing.md`.
7. All 19 harnesses pass.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — all 19, including the new one
- [ ] `checklists/regression.md` — Core sweep + **Settings & backup** in full
- [ ] **The scratch-key test:** add a dummy key to `AppSettings.Key`, run the harness → it **fails** with
      a useful message. Revert.
- [ ] Export settings before the phase and after → **byte-identical files**
- [ ] Import that file → every setting applies, summary counts match
- [ ] Confirm the exported JSON contains **no** `snippetsEnabled`
- [ ] Enable snippets, export, disable snippets, import → snippets stay **off**
- [ ] Import a Raycast config → snippets stay off, currency conversion stays off

## Regression risks

| Risk                                                                                 | Mitigation                                                                                              |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Someone "improves" this later into reflection and consent flags start round-tripping | The phase doc and the exclusion set's reason field both say why; put a one-line note in `AGENTS.md` too |
| The `Key` extraction changes a key string                                            | AC5 — the byte-identical export                                                                         |
| The harness passes vacuously                                                         | AC2 — the scratch-key test is mandatory                                                                 |
| `AppSettings` gains a compile-time dependency that breaks it                         | The extraction is additive; `AppSettings` imports its own key file                                      |

## Rollback strategy

`git revert <sha>`. Additive — a harness and a static dictionary.

## Expected commit size

5 files, +140 / −10 lines.

## Suggested commit message

```
Add a SettingsBackup completeness harness

The mirror stays hand-written on purpose: the explicit omission of
snippetsEnabled is a security control, and any reflection-based scheme
would silently make the next consent flag backup-restorable. Instead the
harness fails when a setting is added and neither backed up nor listed in
deliberatelyExcluded with a reason.
```

## Dependencies

**Phase 16** (`AppSettings` settled). Independent of 29–32.

## Definition of Done

- All acceptance criteria met
- Scratch-key test performed
- Export byte-identical before/after
- Merged

## Estimated difficulty

**Medium.** The Foundation-only constraint on the harness is the design work.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **If the diff contains `Mirror`, a macro, or any reflection, revert.** That is the one thing this
  phase exists to prevent, and it will look like an improvement.
- Do the scratch-key test. A completeness harness that cannot detect an incomplete mirror is worse than
  nothing, because it will be trusted.
- Verify the exported file still omits `snippetsEnabled`, and that importing cannot turn snippets on.
  That is a privacy property, not a preference.
- Check the exclusion set's reason strings are real reasons, not restatements of the key name.
