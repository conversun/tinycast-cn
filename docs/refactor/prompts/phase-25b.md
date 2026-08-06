# Phase 25b kickoff — The remaining palette-UI action coordinators

Read `docs/refactor/phases/25b-palette-action-coordinators.md` completely, and follow the extraction
shape phases 24 and 25 established — see `docs/refactor/progress/25-remaining-coordinators.md` for how
the moves were proven.

## Task

Extract the ~195 lines of palette-UI action methods phases 24 and 25 left on `AppCore`, **one at a
time**, in this order, verifying between each: `LauncherCoordinator`, `ClipboardCoordinator`,
`EmojiCoordinator`, `CalculatorCoordinator`, then fold `setSnippetsEnabled` and
`revealSnippetsInFinder` into the existing `SnippetExpansionCoordinator`. Five commits on one branch is
ideal.

## Hard gates

- **`launch` stays one method and one funnel.** It dispatches on `AppEntry.Kind` to the other
  coordinators and is the single path from a palette row to any of them. Splitting it per kind, or
  letting a screen call a feature coordinator directly, reopens the bypass the funnel invariant exists
  to prevent.
- **`AppEntry.Kind` is still the only thing that says what an entry is.** Never re-derive a category
  from an entry ID.
- **`PaletteWindowController` must not appear in the diff.** `pasteKeepingWindowOpen` and
  `pasteStringKeepingWindowOpen` stay on it; the coordinators call them.
- **`Paster.swift` must not appear in the diff.** Every pasteboard effect stays there, including the
  private `internalType` marker the poller checks.
- **`selectClip` and the `followToken` bump move with the clipboard actions**, and `togglePinnedClip`
  keeps its order: `togglePinned` → `selectClip` → `followToken = UUID()`. They are one behaviour.
- **`setSnippetsEnabled` keeps its exact order** — guard → early-return on disable → `NSApp.activate`
  → confirm → set `snippetsEnabled` → `Permissions.ensureAccessibility()`. **This is a behavioural
  invariant, not a structural one**: `AGENTS.md` allows Accessibility to be requested only from that
  explicit Settings gesture. If the move cannot preserve the order, stop and say so.
- **`DialogController` stays single-owned.** `grep -c "DialogController()" Tinycast` must stay 1, and
  this phase should need **no new façade** — nothing being moved reaches `dialogs` or `messageHUD`
  except through `confirm`.
- **Leave `runWindowCommand`, the dialog façade and `start()` wiring on `AppCore`.** They are its,
  permanently.
- Code moves verbatim. Keep `AppCore` forwarders; phase 32 deletes them.
- Do not touch `Core/ClipboardStore.swift`, `Core/LauncherRankingStore.swift`, `Core/Calculator/*`,
  `Core/Emoji/*`, `Core/AppLauncher.swift`, `Core/CommandRegistry.swift`,
  `Features/PaletteRowIndex.swift`, `Features/PaletteScreen.swift`, or any coordinator from phases 24
  and 25 other than `SnippetExpansionCoordinator`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only | grep -E "PaletteWindowController|Paster"   # must be empty
grep -c "DialogController()" Tinycast -r                          # must be 1
grep -rn "AppCore.shared" Tinycast/Features/*/(*Coordinator).swift  # must be empty
```

Prove the moves by **body diff against `HEAD`**, not `git diff -M` — rename detection cannot pair these
while `AppCore.swift` survives. Extract the pre-change blocks from `HEAD` and diff line-by-line; every
difference must be a receiver rename or an access rewrite.

Run `clipboard-test`, `ranking-test`, `calc-test`, `emoji-test`, `snippets-test` and
`palette-selection-test`. The last must be **unchanged in count** — this phase adds no rows.

**Then run the app**: (1) pin a clip and confirm the highlight follows it into the Pinned section;
(2) paste an emoji with a non-default skin tone and confirm the base glyph is the one whose frequency
rises; (3) turn snippets off and on and confirm the consent dialog appears **before** the Accessibility
prompt.

## Summarise

Use the system-prompt format. State `AppCore`'s final line count — the target is under 560 — and list
what remains in it by category, so the next reader can see it is ownership and wiring only.
