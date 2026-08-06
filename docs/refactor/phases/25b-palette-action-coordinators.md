# Phase 25b — The remaining palette-UI action coordinators

**Milestone:** M4 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

The ~195 lines of palette-UI action methods phases 24 and 25 left on `AppCore`. Four small coordinators
and one fold into an existing one, after which `AppCore` really is the composition root.

## Why this phase exists

**C-1 scoped the whole of `AppCore`**, but the roadmap enumerated phases 24 and 25 against the
orchestration blocks and never scheduled the action methods the palette calls directly. M4 therefore
closes with `AppCore` still owning launcher dispatch, clipboard paste, emoji paste, calculator copy and
the snippets consent gate — which makes M4's Definition of Done ("`AppCore` is the composition root and
nothing else") false.

Two concrete consequences, not just tidiness:

1. **Phase 32 cannot do its job.** Its objective is _"Point every call site at the owning coordinator;
   delete the forwarders."_ These methods are not forwarders — they are implementations with no
   coordinator behind them, so 32 either leaves them (and `AppCore` stays the thing every view talks
   to, the exact coupling C-1 set out to remove) or improvises five extractions inside a `Risk: Med`
   phase scoped as a caller-side change.
2. **Phase 29 has no home for them.** Its feature table lists a coordinator under Quicklinks, Snippets,
   Uninstall, SystemActions and CustomCommands, and **none** under Launcher, Clipboard, Emoji or
   Calculator. The asymmetry is this gap, already written down.

`progress/23` filed 128 lines of the same material as "a gap in 29" and `progress/25` filed the rest.
This phase is where both land.

## Architecture Review reference

**C-1** · the balance of it, after 24 and 25

## Objectives

Extract, in this order, verifying each before the next:

1. **`LauncherCoordinator`** (~115 lines) — `launch`, `runCommand`, `resetRanking`, `showInFinder`,
   `quit`.
2. **`ClipboardCoordinator`** (~45 lines) — `paste`, `pasteKeepingWindowOpen`, `copyToClipboard`,
   `revealClipboardImage`, `togglePinnedClip`, `selectClip`.
3. **`EmojiCoordinator`** (~20 lines) — `pasteEmoji`, `copyEmoji`, `pasteEmojiKeepingWindowOpen`.
4. **`CalculatorCoordinator`** (~18 lines) — `copyCalculatorResult`, `copyHistoryEntry`,
   `copyHistoryExpression`.
5. **Fold `setSnippetsEnabled` and `revealSnippetsInFinder` into `SnippetExpansionCoordinator`** — no
   new type. It already owns that feature, including its consent gate.

## Expected files to modify

| File                                                            | Change                                                              |
| --------------------------------------------------------------- | ------------------------------------------------------------------- |
| `Tinycast/Features/Launcher/LauncherCoordinator.swift`          | **New.**                                                            |
| `Tinycast/Features/Clipboard/ClipboardCoordinator.swift`        | **New.**                                                            |
| `Tinycast/Features/Emoji/EmojiCoordinator.swift`                | **New.**                                                            |
| `Tinycast/Features/Calculator/CalculatorCoordinator.swift`      | **New.**                                                            |
| `Tinycast/Features/Snippets/SnippetExpansionCoordinator.swift`  | +2 methods, moved verbatim.                                         |
| `Tinycast/Core/AppCore.swift`                                   | −195 lines; +4 properties; forwarders retained.                     |

## Files that must NOT change

- `Tinycast/Core/PaletteWindowController.swift` — **still the frame owner.** `pasteKeepingWindowOpen`
  and `pasteStringKeepingWindowOpen` stay on it; the coordinators call them.
- `Tinycast/Core/Paster.swift` — every pasteboard effect stays here, including the `internalType`
  marker
- `Tinycast/Core/AppLauncher.swift`, `Core/CommandRegistry.swift`
- `Tinycast/Core/ClipboardStore.swift`, `Core/LauncherRankingStore.swift` — both harness-compiled
- `Tinycast/Core/Calculator/*`, `Core/Emoji/*` — both harness-compiled and Foundation-only
- `Tinycast/Features/PaletteRowIndex.swift`, `Features/PaletteScreen.swift`
- Every coordinator from phases 24 and 25 except `SnippetExpansionCoordinator`
- `Tinycast/Core/EdgeDissolve.swift`, `Core/ThinScrollbar.swift`

## Implementation boundaries

- **Code moves verbatim.** Receiver renames and access rewrites only, exactly as 24 and 25 did. Prove it
  by body diff against `HEAD`, not by `git diff -M` — rename detection cannot pair these while
  `AppCore.swift` survives.
- **`launch` stays one funnel.** It dispatches on `AppEntry.Kind` to the other coordinators and is the
  single path from a palette row to any of them. Do not split it per kind, and do not let a screen call
  a feature coordinator directly instead — that would reintroduce the bypass `AGENTS.md`'s funnel
  invariant exists to prevent.
- **`AppEntry.Kind` is still the only thing that says what an entry is.** `launch`'s dispatch keeps
  reading `app.kind`; never re-derive a category from an entry ID.
- **`selectClip` and the `followToken` bump move together with the clipboard actions.** They are one
  behaviour: a write promotes the row, the selection follows it, the list scrolls. Splitting them
  breaks the pinned-row follow.
- **`togglePinnedClip` keeps its exact order** — `togglePinned` → `selectClip` → `followToken = UUID()`.
- **The flat `selection` index is untouched.** No coordinator computes a row order; `selectClip` asks
  `ClipboardStore.rowIndex(of:in:)` exactly as today.
- **`setSnippetsEnabled` keeps its exact order** — guard → early-return on disable → `NSApp.activate`
  → confirm → set `snippetsEnabled` → `Permissions.ensureAccessibility()`. That ordering is the
  consent-then-permission gate `AGENTS.md` pins: Accessibility may be requested **only** from this
  explicit Settings gesture.
- All five present through `AppCore.showNotice` / `confirm` / `showMessage`. **`DialogController` stays
  single-owned**, and no new façade should be needed — none of these methods reaches `dialogs` or
  `messageHUD` directly today except through `confirm`.
- **Do not create a coordinator for the dialog façade, `runWindowCommand`, or `start()` wiring.** Those
  are `AppCore`'s, permanently.
- Keep `AppCore` forwarders. Phase 32 deletes them.

## Detailed acceptance criteria

1. All four new coordinators exist, are `@MainActor`, and reference no `AppCore.shared`.
2. `AppCore.swift` is under ~560 lines, and its remaining members are ownership, `init`, `start()`,
   `prepareForTermination`, feature-switch tracking, the dialog façade, `runWindowCommand`, the
   forwarders, and the three palette types phase 28 extracts. **Nothing else.**
3. `grep -c "DialogController()" Tinycast` is 1.
4. `PaletteWindowController` and `Paster` are unchanged.
5. Every launcher activation works, per kind: application, system settings, command, custom command,
   system action, window command, quicklink, snippet.
6. Clipboard: paste, ⌘-paste-in-place, copy, reveal image, pin/unpin — and after each, **the selection
   lands on the row that moved**.
7. Emoji: paste, copy, paste-in-place — each still records frequency on the base glyph and applies the
   configured skin tone at copy time.
8. Calculator: ↵ on the inline card records history then copies; ↵ on a history row re-copies without
   re-recording.
9. Snippets: the Settings switch still confirms before enabling, and Accessibility is still requested
   from that gesture and nowhere else.
10. `palette-selection-test` is unchanged in count — this phase adds no rows.

## Manual verification checklist

- [ ] `checklists/build.md` including **startup timing**
- [ ] `checklists/testing.md` — `clipboard-test`, `ranking-test`, `calc-test`, `emoji-test`,
      `snippets-test`, `palette-selection-test`
- [ ] `checklists/regression.md` — **the full document**
- [ ] Launch one entry of every `AppEntry.Kind` from the palette
- [ ] Copy an image, open the clipboard, paste it → lands in the right app, row follows
- [ ] Pin a clip → it jumps to Pinned and **the highlight goes with it**; unpin → same in reverse
- [ ] ⌘↵ paste-in-place → the palette stays open and the text lands in the previous app
- [ ] Paste an emoji with a non-default skin tone set → the toned glyph is pasted, the base glyph is
      the one whose frequency rises
- [ ] ↵ on the inline calculator card → copies, and the calculation appears in history
- [ ] Turn snippets off, then on → the consent dialog appears **before** the Accessibility prompt
- [ ] Turn snippets on while already on → no dialog, no prompt

## Regression risks

| Risk                                                                            | Mitigation                                                    |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `selectClip` splits from the clipboard actions and the pinned-row follow breaks  | Boundary keeps them together; AC6                             |
| `launch` is split per kind and a funnel gate becomes bypassable                  | Boundary — one funnel; AC5 walks every kind                   |
| The snippets consent→permission order changes and Accessibility is asked earlier | Boundary spells the order out; AC9. **Behavioural invariant** |
| Emoji frequency starts tallying the toned glyph rather than the base             | AC7                                                           |
| A coordinator is created for `runWindowCommand` or the dialog façade             | Boundary — both stay on `AppCore`                             |
| `EmojiCoordinator` / `CalculatorCoordinator` are judged too small to be worth it | See *Notes for reviewers*                                     |

## Rollback strategy

`git revert <sha>`. Consider five separate commits on one branch, one per objective, so a single
problematic extraction can be dropped without losing the others.

## Expected commit size

6 files, +290 / −230 lines. `AppCore` net −195.

## Suggested commit message

```
Extract the launcher, clipboard, emoji and calculator coordinators

Closes the AppCore decomposition C-1 scoped: the palette-UI action methods
phases 24 and 25 left behind now sit with their features, and the snippets
consent gate joins the coordinator that already owns that feature. What
remains on AppCore is ownership, start() wiring, the dialog facade and
runWindowCommand.

launch stays one funnel dispatching on AppEntry.Kind, so no screen can reach
a feature coordinator around a confirmation gate.
```

## Dependencies

**Phase 25 (hard).** Blocks 29 and 32.

Run it **before 26**. It is not that 26 reads this code — it does not — but 28 moves `AppCore.swift`
wholesale and 29 must name these files in its feature table, so extracting first keeps both diffs
honest moves rather than moves-plus-extractions.

## Definition of Done

- All acceptance criteria met
- `AppCore` under ~560 lines and holding nothing but ownership, wiring, façade and forwarders
- **M4's Definition of Done is now literally true**
- Full regression document walked
- Merged

## Estimated difficulty

**Low.** Every move is verbatim and no harness compiles `AppCore.swift`. The volume is a third of
phase 25's.

## Estimated Claude context usage

**Medium.** One coordinator at a time; the file is already 275 lines lighter than it was at phase 25.

## Notes for reviewers

- **`EmojiCoordinator` and `CalculatorCoordinator` are ~20 lines each**, which brushes against phase
  25's rule that "a coordinator for one method is over-engineering". They clear it: that rule was about
  `runWindowCommand`, a *single* method with no store. These are three public methods each with a store
  dependency (`frequentEmoji`, `calcHistory`), and phase 29 gives both features a folder regardless. If
  you disagree, the fallback is to leave both on `AppCore` and accept that AC2 lands ~40 lines higher —
  but do not merge them into one "small actions" coordinator, which would be a grab bag with no owner.
- **Check `launch` is still one method.** Splitting it is the failure mode that reopens the funnel
  bypass.
- **Check `Paster.swift` is absent from the diff.** Every pasteboard effect, including the private
  `internalType` marker the poller checks, belongs there.
- The snippets fold is the one behavioural-invariant risk in the phase. Read the consent ordering
  before and after.
