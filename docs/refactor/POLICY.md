# Migration and compatibility policy

**Authoritative on migration and compatibility questions — and only those.** On any such question it
overrides a phase document, a checklist, `docs/architecture-review.md` or `AGENTS.md`. On anything else
it has no authority: the phase document wins.

That is rank 2 of the precedence ladder in
[`prompts/system-prompt.md`](prompts/system-prompt.md#why-you-will-see-conflicts-and-how-to-resolve-them):

1. **Behavioral invariants** — UI, keyboard, accessibility, permissions and consent, Swift 6 data-race
   safety, the off-limits files. Never overridden.
2. **This document** — compatibility and migration only.
3. **The phase document** — beats `AGENTS.md`'s architectural guidance.
4. **The standing prompt.**
5. **`docs/architecture-review.md`** — rationale, never an instruction.

---

## The policy

Treat this refactor as if the application is a brand-new app.

**Do NOT implement any backward compatibility, migration logic, or legacy support.**

Specifically:

- Do **not** preserve old `UserDefaults` keys.
- Do **not** read or migrate legacy storage paths.
- Do **not** support old persisted enum / raw string values.
- Do **not** add fallback logic for previous database schemas or serialized models.
- Do **not** keep compatibility shims, deprecated APIs, aliases, or one-time migration code.
- Do **not** compare old vs. new defaults or storage to preserve existing user data.

You may freely:

- Rename persisted keys.
- Rename enums and raw values.
- Change storage locations.
- Replace persistence formats.
- Remove obsolete models and code.
- Redesign internal architecture without considering upgrades from previous versions.

Assume:

- There are **no existing users**.
- There is **no upgrade path**.
- A clean installation is the only supported scenario.
- Existing local data may be discarded entirely.

Optimize for the cleanest, simplest, most maintainable architecture — not for compatibility with
previous releases.

---

## Three things this policy does **not** license

These look like compatibility constraints and are not. They remain in force.

### 1 · An intended default is not backward compatibility

`AppSettings` contains eight properties written as:

```swift
defaults.object(forKey: Key.x) == nil || defaults.bool(forKey: Key.x)
```

That is not legacy support. It encodes **"this setting defaults to _on_ for a fresh install"**, because
`defaults.bool(forKey:)` returns `false` for an absent key and these settings must start `true`.

Simplifying it to `defaults.bool(forKey:)` changes the **fresh-install default** — a UX change, which
is still forbidden.

**Rule:** you may rename these keys freely. You may not change what a fresh install starts with. The
same applies to `ClipboardRetention`'s `-1`-means-forever encoding, `PopToRootTimeout`'s `0`-means-
immediately encoding, and `windowGap`'s unset-reads-as-zero.

### 2 · Internal consistency within one build still matters

Rename anything you like, but within a single build the reader and the writer must agree:

- `SettingsKey.showInMenuBar` is shared between `AppSettings` and `TinycastApp`'s `@AppStorage`. Rename
  it in both or neither.
- `AppEntry.id` values (including `CommandID` raw values and the `quicklink:` / `custom-command:` /
  `window-command:` prefixes) are the keys for favourites, visibility and learned ranking **within a
  session**. Rename freely; keep every producer and consumer in step.
- `ClipboardManager.internalType` marks Tinycast's own pasteboard writes so the poller skips them.
  Rename it if you want; if the writer and the poller disagree, Tinycast re-captures its own pastes in
  a loop.
- SQLite column names must match between the schema, the prepared statements and the row decoder.

### 3 · External formats are not "legacy"

Compatibility with **another application's** format is not backward compatibility with a previous
Tinycast, and it stays:

- **Raycast import** (`.rayconfig`, both v1 and v2). Tinycast reads a format it does not own. Do not
  touch `RaycastFormat`, `RaycastV1Decoder`, `RaycastImportV1`, `RaycastImportV2` or their harness.
- **Snippet Markdown files.** The on-disk format is user-authored and user-editable; it is an interchange
  format, not an internal one.

Tinycast's **own** export formats — `SettingsBackup` JSON and `QuicklinkArchive` JSON — are internal.
You may change them freely. The only requirement is that **export → import round-trips within the same
build**.

---

## What this changes about the roadmap

| Phase                            | Was                                                                                            | Now                                                                                                  |
| -------------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **05** AppPaths                  | Every resolved path had to stay byte-identical                                                 | Change paths freely. Adopt `AppPaths` everywhere the harness constraint allows. Risk **Med → Low**   |
| **06** HotKey binding cache      | Legacy `KeyboardShortcuts_<name>` key format and JSON string shape frozen                      | Format is no longer frozen. _Changing_ it is still not this phase's objective — see phase 35         |
| **15** HotKeyManager observation | Persisted format unchanged                                                                     | No longer a constraint                                                                               |
| **16** AppSettings observation   | 25 keys frozen; `defaults export` diff mandatory                                               | Keys renameable. **The eight fresh-install defaults still stand** (carve-out 1). Risk **High → Med** |
| **17** Stores observation        | Data-safety verification                                                                       | Replaced by clean-install verification                                                               |
| **30** Naming                    | Persisted identifiers frozen — the phase's entire sharp edge                                   | Rename persisted keys along with their types. Risk essentially removed                               |
| **31** `AppEntry.Kind`           | Raw values frozen for `hiddenKinds`                                                            | Renameable (carve-out 2 applies)                                                                     |
| **33** SettingsBackup harness    | Unchanged — the `snippetsEnabled` exclusion is a **security** control, not a compatibility one | Unchanged                                                                                            |
| **35** _(new)_                   | —                                                                                              | Retire the compatibility machinery this policy makes dead                                            |

Phase **33 is unaffected**. The exclusion of `snippetsEnabled` from settings backups exists because it
doubles as keystroke-listening consent and an import must not grant a permission. That is a security
control and this policy does not touch it. The same goes for `CurrencyRateStore`'s consent flag.

---

## What this changes about verification

The **Data safety** section of `checklists/regression.md` is replaced by **Clean install**. You are no
longer checking that existing data survived; you are checking that a fresh install works.

Before any phase that touches storage:

```bash
# Wipe the Dev channel completely. This is now the expected, supported action.
rm -rf ~/Library/Caches/com.tinycast.app.dev
rm -rf "$HOME/Library/Application Support/com.tinycast.app.dev"
defaults delete com.tinycast.app.dev 2>/dev/null || true
tccutil reset Accessibility com.tinycast.app.dev 2>/dev/null || true
```

Then launch and confirm the app builds its state from nothing: onboarding runs, stores initialise,
settings take their intended defaults, nothing crashes on an absent key or an absent file.

---

## Conflicts with `AGENTS.md`

`AGENTS.md` is loaded into every Claude Code session **before** anything the operator pastes, and it
describes the codebase as it is today. Conflicts with this policy are therefore guaranteed, not
accidental. Three are known and listed here so they are recorded rather than discovered mid-phase:

1. > _"Hotkeys persist under legacy `KeyboardShortcuts_<name>` UserDefaults keys (from the removed
   > KeyboardShortcuts package) so old bindings survive."_

   **Superseded.** Old bindings need not survive.

2. > _"Its `Codable` conformance is the compatibility seam — a `.combo` must keep encoding as the bare
   > `{"carbonKeyCode":N,"carbonModifiers":N}` record … or every existing binding and backup breaks."_

   **Superseded.** See phase 35.

3. > _"`SettingsBackup` … Every field is optional so an import applies only the keys actually present."_

   **Retained** — but for a different reason. Optionality supports **partial** files and Raycast
   imports, not old Tinycast versions.

`AGENTS.md` now carries a banner at the top pointing here and stating that structural rules are being
changed by the refactor — so the correction arrives in the first thing an agent reads, rather than
depending on the operator pasting the standing prompt.

The three clauses above are still **superseded but not yet deleted**. Phase 35 deletes them, amends the
surrounding text, and **removes the banner** — the refactor is over at that point and the banner would
become a lie. Until then, this document wins and a phase that trips over one of them should proceed and
note it.
