# Phase 26 — Fix the three dependency inversions

**Milestone:** M4 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

Three places in `Core/` reach _up_ into `AppCore.shared`. Break each one by injecting what it needs.

## Why this phase exists

The intended direction is `Features → AppCore → stores → pure core`. These three invert it:

| Site                                   | Reaches for                                  | Why it is a problem                                                 |
| -------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------- |
| `HotKeyManager.displayName` (4 refs)   | `appIndex`, `customCommands`, `quicklinks`   | You cannot understand `HotKeyManager` without three other stores    |
| `KeyShortcut.collapsedModifierSymbols` | `settings.hyperKey`, `hyperKeyReplacesGlyph` | A pure-ish formatting helper depends on global app state            |
| `SystemActionRunner` async completion  | `AppCore.shared.presentSystemActionFailure`  | Bends the documented "runner owns effects, `AppCore` owns UI" split |

None is a type-level cycle, but each is a cycle in reasoning — and each blocks the file from ever being
harness-reachable.

## Architecture Review reference

**§2.3 Dependency direction** · Roadmap W5.7

## Objectives

1. `HotKeyManager.displayName` takes a name-resolver closure, injected at wiring time.
2. `KeyShortcut.collapsedModifierSymbols` takes the Hyper display preference as parameters.
3. `SystemActionRunner` reports its async failure through an injected callback.

## Expected files to modify

| File                                     | Change                                                    |
| ---------------------------------------- | --------------------------------------------------------- |
| `Tinycast/Core/HotKeyManager.swift`      | `displayName` uses an injected resolver.                  |
| `Tinycast/Core/HotKey/KeyShortcut.swift` | `collapsedModifierSymbols(from:hyperKey:replacesGlyph:)`. |
| `Tinycast/Core/SystemActionRunner.swift` | `onAsyncFailure` callback instead of `AppCore.shared`.    |
| `Tinycast/Core/AppCore.swift`            | Wires all three in `start()`.                             |
| Call sites of `collapsedModifierSymbols` | Pass the two new arguments.                               |

## Files that must NOT change

- `Tinycast/Core/HotKey/HotKeyBinding.swift`, `HotKeyCenter.swift`, `DoubleTapMonitor.swift`
- `Tinycast/Core/SystemAction.swift` — harness-compiled
- `Tinycast/Core/AppIndex.swift`, `Core/CustomCommand.swift`, `Core/Quicklinks/QuicklinkStore.swift`
- Any coordinator from phases 24–25

## Implementation boundaries

- **Closures, not protocols.** Each injection is one closure property set once in `AppCore.start()`.
  Do **not** introduce a `NameResolving` protocol, a `FailureReporting` protocol, or any abstraction —
  the review is explicit that no protocol should be added for testability.
- `displayName`'s resolver signature should be as narrow as possible, e.g.
  `var displayName: (HotKeyAction) -> String?` with `HotKeyManager` supplying its own fallbacks for the
  cases it already knows (`.togglePalette`, `.toggleClipboard`, `.toggleEmoji`, `.systemAction`,
  `.windowCommand` — all of which resolve from static catalogs, not from stores).
- `collapsedModifierSymbols` becomes a pure function of its arguments. **Do not** change what it
  produces: the ✦ collapse is keyed on _configuration_, not on tap health, so the glyphs never flicker,
  and leftover modifiers keep canonical order after the ✦.
- `SystemActionRunner`'s callback is set once. The existing `Task { @MainActor in … }` inside the
  `openApplication` completion handler stays — only the destination changes.
- **Do not** attempt to make any of these three files harness-compiled in this phase. Removing the
  inversion is the objective; adding a harness is a separate, later decision.
- `HotKeyManager` keeps `capture` and `doubleTapMonitor` as `let` properties. This phase does not touch
  ownership.

## Detailed acceptance criteria

1. `grep -rn "AppCore.shared" Tinycast/Core` returns **nothing**.
2. No protocol was introduced.
3. `collapsedModifierSymbols` is a pure function; it reads no global state.
4. The recorder's "Used by …" conflict message still names apps, panes, custom commands, system actions,
   window commands and quicklinks correctly.
5. Hyper Key ✦ collapse renders identically in launcher rows, Settings recorders and the recorder
   callout.
6. Turning "Replace occurrences of ⌃⌥⇧⌘ with ✦" off restores the full modifier glyphs everywhere.
7. A screen-saver launch failure still surfaces its dialog.
8. `AppCore.start()` wires all three, once.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — `hotkey-test`, `callout-test`, `system-action-test`
- [ ] `checklists/regression.md` — Core sweep + **Hotkeys** + **System actions & window management**
- [ ] Bind a shortcut to an app; try to bind the same combo to a **custom command** → the conflict
      message names the **app**
- [ ] Repeat with a quicklink, a system action and a window command as the existing owner → each is
      named correctly
- [ ] Bind a shortcut to a **settings pane**; conflict message names the pane
- [ ] Set a Hyper Key with ✦ replacement **on** → launcher rows, Settings rows and the recorder callout
      all show ✦
- [ ] Turn ✦ replacement **off** → all three show ⌃⌥⇧⌘
- [ ] Toggle "Include Shift" → the glyph set changes consistently in all three places
- [ ] Delete `/System/Library/CoreServices/ScreenSaverEngine.app` is not testable; instead verify a
      different async failure path, or confirm by inspection that the callback is wired
- [ ] `grep -rn "AppCore.shared" Tinycast/Core` → empty

## Regression risks

| Risk                                                                               | Mitigation                                 |
| ---------------------------------------------------------------------------------- | ------------------------------------------ |
| The conflict message stops naming user-created items (custom commands, quicklinks) | AC4 + testing each of the six action kinds |
| ✦ collapse diverges between the three render sites                                 | AC5/AC6 — check all three                  |
| A protocol sneaks in "for cleanliness"                                             | AC2                                        |
| The failure callback is wired but never set, so a real failure is silent           | AC8 — read `start()`                       |
| `HotKeyManager` loses its static-catalog fallbacks and shows raw IDs               | AC4                                        |

## Rollback strategy

`git revert <sha>`. In-memory wiring only.

## Expected commit size

5 files, +60 / −45 lines.

## Suggested commit message

```
Break the three Core → AppCore.shared inversions

HotKeyManager's conflict-message name lookup, KeyShortcut's ✦ collapse
preference, and SystemActionRunner's async failure report each reached up
into AppCore.shared. All three now take what they need — one closure or
two parameters, wired once in start(). No protocols introduced.
```

## Dependencies

Phase 15 (`HotKeyManager` observation) and **phase 25** (`AppCore` settled). Blocks 27.

## Definition of Done

- All acceptance criteria met
- `grep -rn "AppCore.shared" Tinycast/Core` empty
- All six conflict-owner kinds verified by hand
- Merged

## Estimated difficulty

**Medium.**

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Run the grep yourself.** It is the phase's headline criterion and it takes two seconds.
- The conflict-owner test is tedious but it is the only thing that catches a resolver wired for four of
  six action kinds. Do all six.
- Check the ✦ collapse in **three** places — a launcher row keycap, a Settings recorder, and the
  recorder's callout. They render through different paths.
- If a protocol appeared, revert. The review is explicit: no protocol for testability.
