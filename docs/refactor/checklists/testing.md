# Testing checklist — the `Tools/` harnesses

Tinycast has **no XCTest target**. The `Tools/` harnesses are the only automated correctness signal in
the repository, and each one compiles the _real_ shipping source rather than a copy. That is what makes
them trustworthy — and what makes a red harness a hard stop.

Full command list: [`docs/development.md`](../../development.md).

---

## The rule

> **A harness that passed before a phase must pass after it.**
> No exceptions, no "I'll fix it next phase", no commenting out a case.

If a phase legitimately changes what a harness asserts, the phase document says so explicitly and the
harness change is part of the reviewable diff.

---

## Harness → owning source map

Use this to decide which harnesses a phase must run. If a phase touches any file in the right column,
the harness in the left column is **mandatory**.

| Harness                  | Compiles (paths relative to `Tinycast/`, `Features/` prefix implied unless shown)                                                                |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fuzz-test`              | `Launcher/Model/SearchRelevance.swift`                                                                                                           |
| `ranking-test`           | `Launcher/Model/SearchRelevance.swift`, `Launcher/Model/LauncherRankingStore.swift`                                                              |
| `calc-test`              | `Calculator/Model/*.swift`                                                                                                                       |
| `clipboard-test`         | `Clipboard/Model/ClipboardStore.swift`                                                                                                           |
| `scopes-test`            | `Launcher/Model/SearchScopes.swift`                                                                                                              |
| `raycast-test`           | `Backup/Model/RaycastFormat.swift`, `RaycastV1Decoder.swift`, `Backup/Service/Gunzip.swift`, `Clipboard/Model/ClipboardStore.swift`              |
| `emoji-test`             | `Emoji/Model/EmojiCatalog.swift`, `EmojiGridGeometry.swift`, `EmojiData.generated.swift`                                                         |
| `custom-command-test`    | `CustomCommands/Model/CustomCommand.swift`, `CustomCommands/Service/ShellCommandRunner.swift`                                                    |
| `snippets-test`          | `Platform/NotificationToken.swift`, `Platform/HealthTicker.swift`, `Snippets/Model/*.swift`, `Snippets/Service/*.swift`                          |
| `hotkey-test`            | `HotKeys/Model/DoubleTapModifier.swift`, `DoubleTapDetector.swift`                                                                               |
| `callout-test`           | `DesignSystem/Theme.swift`, `HotKeys/UI/CalloutPlacement.swift`                                                                                  |
| `system-action-test`     | `SystemActions/Model/SystemAction.swift`                                                                                                         |
| `volume-test`            | `SystemActions/Model/VolumeLevel.swift`                                                                                                          |
| `window-command-test`    | `WindowManagement/WindowCommand.swift`, `WindowLayout.swift`, `WindowActionMemory.swift`                                                         |
| `uninstall-test`         | `Uninstall/Model/UninstallTarget.swift`, `UninstallSearchRoot.swift`, `UninstallRules.swift`, `UninstallProtection.swift`, `UninstallPlan.swift` |
| `quicklink-test`         | `Quicklinks/Model/Quicklink.swift`, `QuicklinkDestination.swift`, `QuicklinkStore.swift`, `QuicklinkArchive.swift`                               |
| `palette-selection-test` | `Features/PaletteRowIndex.swift`, `Emoji/Model/EmojiGridGeometry.swift` — the flat selection index's map onto visible row order                  |

- [ ] Every harness whose sources this phase touched has been run
- [ ] Each one printed a pass result and exited 0

---

## The purity invariant

Every file in the right column above is **Foundation-only** (plus SQLite3, Combine, Darwin or
CommonCrypto where `AGENTS.md` names the exception). A harness failing to _compile_ — as opposed to
failing an assertion — almost always means someone added an `import AppKit` or an `import SwiftUI` to a
pure file.

- [ ] No pure-layer file gained an AppKit or SwiftUI import
- [ ] No pure-layer file gained a clock read, a network read or a filesystem read that is not injected
- [ ] `Features/Calculator/Model/` still takes its clock via `now`/`calendar` and its rates via `rates`
- [ ] `Features/Uninstall/Model/`'s deciding half still receives directory **names** and a `PathFacts`, never URLs
- [ ] `Features/HotKeys/Model/DoubleTap*` still take the clock as a parameter
- [ ] `Features/WindowManagement/` geometry still takes no `NSScreen` and no AX call
- [ ] `Features/PaletteRowIndex.swift` still imports Foundation alone, despite living under `Features/`

**This is the most likely way a refactor silently breaks the test suite.** A phase that moves files
(27–29) must re-run the full suite, because the harness command lines encode file paths.

---

## Running everything

Before a milestone boundary — after phases **10, 18, 23, 26, 29, 33, 34** — run all of them. Copy the
block from `docs/development.md`, or:

```
# from the repo root, ~2 minutes total
set -euo pipefail
# …paste the full harness block from docs/development.md…
```

- [ ] All 17 (18 from phase 19 onward) harnesses pass
- [ ] Result recorded in the progress file

---

## When a phase must change a harness

Legitimate only in these cases:

1. **Phase 19** adds `Tools/palette-selection-test.swift`.
2. **Phase 33** adds the `SettingsBackup` completeness assertion.
3. **Phases 27–29** update file _paths_ in the command lines — never assertions.
4. A phase document explicitly authorises an assertion change and says why.

Anything else is a red flag. A refactor that needs a test loosened is not a refactor.

- [ ] Harness assertion changes, if any, are authorised by the phase document
- [ ] `docs/development.md` and `AGENTS.md` command lines updated in the same commit as any path change
