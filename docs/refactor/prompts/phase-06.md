# Phase 06 kickoff — HotKey binding cache

Read `docs/refactor/phases/06-hotkey-binding-cache.md` completely before editing.

## Task

`HotKeyManager.binding(for:)` reads `UserDefaults` and JSON-decodes on every call — ~140 times at
launch, up to ~70 per keystroke while recording. Load bindings into an in-memory
`[HotKeyAction: HotKeyBinding]` once in `start()`, write through on mutation, serve every read from it.

## Hard gates

- **Do not change the persisted format in this phase.** `docs/refactor/POLICY.md` no longer freezes it
  for compatibility — but this phase caches reads, it does not redesign storage. Retiring the legacy
  `KeyboardShortcuts_<name>` key and the JSON-string encoding is **phase 35**, with its own diff and its
  own verification. Do not smuggle it in here.
- The four bound-ID index keys keep their names and semantics for the same reason:
  `boundAppBundleIDs`, `boundPaneBundleIDs`, `boundCustomCommandIDs`, `boundQuicklinkIDs`.
- `binding(for:)` keeps its exact signature and return type.
- **Populate the whole map in `start()`.** Do not make it lazy per key — there must be no cache-miss
  path to reason about.
- `setBinding` must update the map, `UserDefaults`, **and** the relevant bound-ID index.
- `prune(key:live:action:)` must still delete orphaned defaults keys _and_ leave the in-memory map
  reflecting the pruned state. Mind the ordering relative to population.
- **Do not** add `@Observable` and **do not** remove `objectWillChange.send()`. That is phase 15.
- Do not modify `HotKeyBinding.swift`, `KeyShortcut.swift`, `HotKeyCenter.swift`,
  `DoubleTapMonitor.swift` or `SettingsBackup.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run the hotkey harness. Then wipe the Dev channel, launch, set three shortcuts, quit, relaunch, and
confirm all three still fire.

## Summarise

Use the system-prompt format. State explicitly where the map is populated, where it is written through,
and how `prune` interacts with population order.
