# Phase 26 kickoff — Fix the three dependency inversions

Read `docs/refactor/phases/26-dependency-inversions.md` completely.

## Task

Three places in `Core/` reach up into `AppCore.shared`. Break each by injecting what it needs:

1. `HotKeyManager.displayName` — reaches `appIndex`, `customCommands`, `quicklinks`
2. `KeyShortcut.collapsedModifierSymbols` — reaches `settings.hyperKey`, `hyperKeyReplacesGlyph`
3. `SystemActionRunner`'s async completion handler — reaches `AppCore.shared.presentSystemActionFailure`

## Hard gates

- **Closures, not protocols.** Each injection is one closure property or one extra parameter, set once
  in `AppCore.start()`. Do **not** introduce a `NameResolving` protocol, a `FailureReporting` protocol,
  or any abstraction. The architecture review is explicit: no protocol added for testability.
- `displayName`'s resolver should be as narrow as possible — e.g.
  `var displayName: (HotKeyAction) -> String?` — with `HotKeyManager` keeping its own fallbacks for the
  cases that resolve from **static catalogs** rather than stores: `.togglePalette`, `.toggleClipboard`,
  `.toggleEmoji`, `.systemAction`, `.windowCommand`.
- `collapsedModifierSymbols` becomes a pure function of its arguments. **Do not change what it
  produces**: the ✦ collapse is keyed on _configuration_, not on tap health, so glyphs never flicker,
  and leftover modifiers keep canonical order after the ✦.
- `SystemActionRunner`'s callback is set once; the existing `Task { @MainActor in … }` inside the
  `openApplication` completion handler stays — only the destination changes.
- **Do not try to make any of these three files harness-compiled.** Removing the inversion is the
  objective; adding a harness is a separate, later decision.
- `HotKeyManager` keeps `capture` and `doubleTapMonitor` as `let`. Ownership does not change here.
- Do not touch `HotKeyBinding.swift`, `HotKeyCenter.swift`, `DoubleTapMonitor.swift`,
  `SystemAction.swift`, `AppIndex.swift`, `CustomCommand.swift`, `QuicklinkStore.swift`, or any
  coordinator.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
grep -rn "AppCore.shared" Tinycast/Core     # must be EMPTY — this is the headline criterion
```

Run `hotkey-test`, `callout-test`, `system-action-test`.

**Then run the app** and test the conflict message for **all six** action kinds as the existing owner:
app, settings pane, custom command, quicklink, system action, window command. A resolver wired for four
of six looks fine until you hit the fifth.

## Summarise

Use the system-prompt format. Paste the output of the `AppCore.shared` grep. Confirm no protocol was
introduced.
