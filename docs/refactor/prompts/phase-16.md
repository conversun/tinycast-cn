# Phase 16 kickoff — Observation: `AppSettings`

Read `docs/refactor/phases/16-observation-app-settings.md` completely.

## Task

Migrate `AppSettings` — 25 `@Published` properties, each with a `didSet` writing `UserDefaults`,
observed by the palette, every launcher row, and most Settings panes.

## Hard gates

- **The eight absence-vs-`false` checks must survive — and this is where the new compatibility policy is
  most likely to mislead you.** These properties use
  `defaults.object(forKey:) == nil || defaults.bool(…)`:
  `hyperKeyIncludesShift`, `hyperKeyReplacesGlyph`, `showFavoritesInCompactMode`, `openOnCursorScreen`,
  `customCommandsShowInLauncher`, `snippetsShowInLauncher`, `windowManagementShowInLauncher`,
  `quicklinksShowInLauncher`, `quicklinkConfirmsBeforeDelete`.
  That is **not** legacy support. It encodes _"this setting starts **on** for a fresh install"_, because
  `defaults.bool(forKey:)` returns `false` for an absent key. `docs/refactor/POLICY.md` lets you rename
  these keys; it does **not** let you change what a clean install starts with. Simplifying one silently
  flips that setting off for every new install and nothing in the build or the harnesses will tell you.
  Same for `ClipboardRetention`'s `-1`, `PopToRootTimeout`'s `0`, `windowGap`'s unset-reads-as-zero.
- **Keep the explicit `didSet` persistence blocks.** Do not convert to computed properties backed by
  `UserDefaults` — that changes read cost on a hot path. A `stored(_:default:)` property wrapper is
  _optional and discouraged in this phase_; prefer one change at a time.
- `launchAtLogin`'s `didSet` calls `LaunchAtLogin.set` — a side effect, not persistence. Keep it.
- `SettingsKey.showInMenuBar` stays an `@AppStorage` key shared with `TinycastApp`'s `MenuBarExtra`.
  Do not fold it into `AppSettings`.
- **The Combine sinks in `AppCore.start()`, `AppIndex.start()` and `HyperKeyTap.start()` subscribe to
  `settings.$x`, which disappears with `@Published`.** Convert them to the **minimal**
  `withObservationTracking` form that preserves current behaviour. Leave the wider cleanup — removing
  the deferral `Task`s and the `assumeIsolated` blocks — to phase 18. State exactly what you changed.
- `$settings.x` bindings in Settings panes become the `@Bindable` form; every control must still write
  through.
- **Do not modify `SettingsBackup.swift`.** Phase 33 handles it; it must compile unchanged.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only | grep SettingsBackup    # must be empty
```

Run `callout-test`, `scopes-test`, `volume-test`.

**Then run the app, walk all 14 Settings panes, toggle every control, quit, relaunch, and confirm every
change stuck.** A dead binding looks completely normal until you toggle it.

**Then wipe the Dev channel and relaunch**, and walk the panes again confirming every default is what it
should be. That is the only check that catches a broken absence-vs-false conversion.

## Summarise

Use the system-prompt format. **List all 25 keys** with their default handling, so the reviewer can diff
your list against the `Key` enum without reading the whole file. State exactly what you changed in each
of the three sink sites.
