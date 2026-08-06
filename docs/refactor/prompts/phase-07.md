# Phase 07 kickoff — Settings-pane scan cache

Read `docs/refactor/phases/07-settings-pane-scan-cache.md` completely before editing.

**Read `Tinycast/Core/SpotlightNames.swift` first.** It already solves this exact problem one function
away, and your solution should read as its sibling.

## Task

`SettingsPaneScanner.scan()` re-reads and re-parses ~40 `.appex` `Info.plist` and `InfoPlist.loctable`
files on every palette open. Cache the result, invalidated by the modification date of
`/System/Library/ExtensionKit/Extensions`.

## Hard gates

- **Prefer threading the cache through `AppIndex` as a value**, exactly as `alternateNameCache` already
  is: `let reusing = …` → detached scan → store what comes back. This avoids static mutable state and
  needs no lock.
- If a `Sendable` constraint makes that genuinely impossible, a static guarded by an `NSLock` is
  acceptable — **say so and justify it**. Do not reach for `nonisolated(unsafe)` without a lock.
- Invalidation key is **only** the directory's `contentModificationDate`. No time-based expiry, no
  launch-count heuristic, no manual refresh path.
- Do not change `displayName`, `loctableName`, `isSettingsPane`, `nameOverrides` or `skippedBundleIDs`.
- **Cache nothing else.** Not `Bundle(url:)` results, not `SearchScopes.appBundles`.
- `AppIndex.scan` stays `nonisolated` and is still called from `Task.detached`.
- Handle the failure case: if `contentsOfDirectory` fails, the current code returns `[]`. That must not
  be cached as a successful empty scan forever.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run `fuzz-test`, `ranking-test` and `scopes-test`.

## Summarise

Use the system-prompt format. State whether you used the value-threaded or the static form, and why.
Confirm the published `.systemSettings` entry list is unchanged in count and order.
