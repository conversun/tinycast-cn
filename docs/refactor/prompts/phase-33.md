# Phase 33 kickoff — `SettingsBackup` completeness harness

Read `docs/refactor/phases/33-settings-backup-completeness-harness.md` completely.

## Task

Add a harness that fails when an `AppSettings` setting is added and neither backed up nor deliberately
excluded. **Keep the mirror hand-written.**

## Hard gates

- **Do NOT introduce reflection, `Mirror`, a macro, or code generation.** This will look like an
  improvement and it is the one thing this phase exists to prevent.

  The reason: the _explicit_ omission of `snippetsEnabled` — which doubles as keystroke-listening
  consent — is a **security control**. Any mechanism that auto-includes new properties would silently
  make the next consent flag backup-restorable, and `AGENTS.md` states the rule: consent flags live on
  the owning store, and an import must not grant a permission.

- Add `static let deliberatelyExcluded: [String: String]` mapping key → **reason**. Today it holds
  exactly one entry:
  `"snippetsEnabled": "Doubles as keyword-expansion consent; an import must not enable keystroke listening."`
- The harness must be **Foundation-only**. It cannot instantiate `AppSettings`. Two workable approaches:
  1. compile `AppSettings.swift`'s `Key` enum together with `SettingsBackup.swift` and compare the lists;
  2. if that does not work cleanly, extract **only** the `Key` enum into a Foundation-only
     `SettingsKeys.swift` — a purely additive extraction of 25 string constants — and compile that.
- **The assertion is symmetric**: every `Key` is covered, _and_ every `SettingsData` field maps to a real
  `Key`. A field for a setting that no longer exists is also a defect.
- **No "backup everything by default" fallback.** Omission must be deliberate and named.
- Do not modify `gather` or `apply`. This phase adds a guard; it does not rewrite the mirror.
- Do not touch `CurrencyRateStore` — its consent flag is deliberately outside `AppSettings`.
- Register the harness in `docs/development.md`, `AGENTS.md` and `checklists/testing.md`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run all 19 harnesses.

**Then prove the harness can fail:** add a dummy key to `AppSettings.Key`, run the harness, confirm it
fails with a message that names the missing key, then revert. A completeness harness that cannot detect
an incomplete mirror is worse than nothing, because it will be trusted.

## Summarise

Use the system-prompt format. Quote the harness's failure message from the scratch-key test. Confirm the
exported JSON still omits `snippetsEnabled`.
