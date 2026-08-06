# Phase 35 kickoff — Retire the compatibility machinery

Read `docs/refactor/POLICY.md` and then
`docs/refactor/phases/35-retire-compatibility-machinery.md` completely.

## Task

Delete the three pieces of code that exist only to keep old Tinycast data readable:

1. The legacy `KeyboardShortcuts_<name>` UserDefaults key namespace.
2. `HotKeyBinding`'s hand-written `Codable` conformance (use the synthesised one).
3. `ClipboardStore`'s two `ALTER TABLE` schema migrations and `columnExists`.

Then amend `AGENTS.md`'s three superseded clauses **and delete the refactor banner at the top of it** —
the refactor is finished at this point and the banner would be false.

## Hard gates

- **Delete, do not translate.** No migration that reads an old key and writes a new one. No fallback
  decoder. No "upgrade path". A developer with old data wipes the Dev channel — that is the supported
  answer now.
- **The net line count must be negative.** If it is not, something was rewritten rather than removed.
- **Do not touch Raycast import** — `RaycastFormat`, `RaycastV1Decoder`, `RaycastImportV1`,
  `RaycastImportV2`, `Tools/raycast-test.swift`. That is _another application's_ format, not Tinycast's
  legacy. It looks like compatibility code and it is not.
- **Do not touch the snippet Markdown serializer.** User-authored interchange format.
- `HotKeyAction.defaultsKey` stays the single place that computes a key. The new namespace must be
  per-action and stable within the build.
- `ClipboardStore` and `QuicklinkStore` stay harness-compiled: Foundation + SQLite3, no other app source.
- **Do not rename SQLite columns.** Fold `source_app` and `pinned_at` into `schema` under their existing
  names — the row decoder and the prepared statements reference them and renaming buys nothing.
- Simplifying `HotKeyBinding.Codable` **changes the settings-backup file format**. That is allowed. The
  only requirement is export → import round-trips _within this build_.
- Do not touch `HotKeyCenter`, `DoubleTapMonitor`, or double-tap detection. Persistence only.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "KeyboardShortcuts_" Tinycast          # must be empty
grep -rn "ALTER TABLE\|columnExists" Tinycast   # must be empty
git diff --stat                                  # net must be negative
```

Run all 19 harnesses.

**Then run the app from a wiped Dev channel:**

```
rm -rf ~/Library/Caches/com.tinycast.app.dev
rm -rf "$HOME/Library/Application Support/com.tinycast.app.dev"
defaults delete com.tinycast.app.dev
```

Set a combo shortcut, a double-tap shortcut and a per-app one. Quit, relaunch, confirm all three fire.
Export a settings backup, wipe again, import, confirm all three return.

## Summarise

Use the system-prompt format. State the net line delta. Confirm `Raycast*` and the snippet serializer are
absent from the diff, and quote the three `AGENTS.md` clauses you amended.
