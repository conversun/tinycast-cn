# Phase 32 — Retire `AppCore` forwarders, adopt `@Environment`

**Milestone:** M6 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

Phases 24–25 left thin forwarding methods on `AppCore` so no view had to change. Now move the call
sites onto the coordinators directly, and replace the 21 view-side `AppCore.shared` reaches with
`@Environment`.

## Why this phase exists

The forwarders were scaffolding. Left in place they re-grow `AppCore` and re-establish it as the thing
every view talks to — which is exactly the coupling C-1 set out to remove.

Separately, 21 view files reach `AppCore.shared` despite `AppCore` already being in the environment.

AC5's ~250 lines is reachable only as the last of three subtractions, and this is where the arithmetic
lands: 746 after phase 25, −195 in 25b, −99 when phase 28 extracts the three palette types, −~180 of
forwarders here.

## Architecture Review reference

**§2.3** · **C-1** · Roadmap W7.3

## Objectives

1. Point every call site at the owning coordinator; delete the forwarders.
2. Replace view-side `AppCore.shared` with `@Environment`.
3. Leave the three genuinely-global reaches alone (see boundaries).

## Expected files to modify

| File                                                  | Change                                                                            |
| ----------------------------------------------------- | --------------------------------------------------------------------------------- |
| `App/AppCore.swift`                                   | Delete the ~40 forwarders (25 from phases 24–25, ~15 more from 25b).              |
| `Palette/RootPaletteView.swift`                       | Call coordinators; drop `AppCore.shared`.                                         |
| Every `Features/*/UI/*Screen.swift`                   | Same.                                                                             |
| `Features/*/Settings/*SettingsView.swift` (~10 files) | `@ObservedObject … = AppCore.shared.settings` → `@Environment(AppSettings.self)`. |
| `Features/HotKeys/UI/ShortcutRecorder*.swift`         | Same.                                                                             |
| `Windows/*` where applicable                          | Same.                                                                             |

## Files that must NOT change

- Any coordinator's implementation — this phase changes callers, not callees
- Any store
- `App/AppDelegate.swift` — `AppCore.shared.start()` is the composition root's entry point and is
  correct
- `App/TinycastApp.swift` — the `MenuBarExtra` buttons legitimately reach the singleton; there is no
  environment in a `Scene`'s menu content

## Implementation boundaries

- **`AppCore.shared` is still legitimate in exactly three places:**
  1. `AppDelegate` — the one wiring point
  2. `TinycastApp`'s `MenuBarExtra` menu items — no environment available
  3. `PaletteWindowController.ensurePanel()` — it _builds_ the environment

  Everywhere else it must go.

- `@Environment` requires the object to be injected. `PaletteWindowController.ensurePanel()` and
  `AppCore.showSettings` are the two injection points. **A missing injection is a runtime crash, not a
  compile error** — enumerate what each view needs and confirm it is injected.
- Delete a forwarder **only** when its last call site has moved. A forwarder with a remaining caller
  stays, and the summary says which and why.
- Do not change any coordinator method's signature to make a call site prettier.
- `armedHover` in `RootPaletteView` reaches `AppCore.shared.palette.hoverHighlightArmed` from a `View`
  extension. Convert it to take the flag through the environment or as a parameter — **but do not
  change its semantics**: it must still only light on physical pointer movement, never during
  keyboard-driven scrolling.
- `KeyShortcut.collapsedModifierSymbols` was fixed in phase 26 and needs nothing here.

## Detailed acceptance criteria

1. `grep -rn "AppCore.shared" Tinycast` returns exactly three sites, all listed above.
2. `AppCore.swift` has no forwarding methods; it is object ownership, `start()`, and the dialog façade.
3. Every view compiles and **runs** — every `@Environment` lookup resolves.
4. `armedHover` behaves identically: hover lights on mouse movement, stays dark during ↑/↓ navigation.
5. `AppCore.swift` is under ~250 lines.
6. Zero behaviour change.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — all 17
- [ ] `checklists/regression.md` — **the full document**
- [ ] **Open every one of the 14 Settings panes.** A missing environment injection crashes on the pane
      that needs it, and only that pane
- [ ] Open About and Onboarding
- [ ] Every palette screen: launcher, clipboard, calculator history, emoji, uninstall, quicklinks,
      quicklink arguments
- [ ] Open every Actions menu on every screen
- [ ] Hover a launcher row with the mouse → it highlights
- [ ] Navigate with ↑/↓ so rows slide under a **stationary** pointer → **no hover highlight appears**
- [ ] Menu-bar menu: Open, Clipboard History, Settings, Quit — all work
- [ ] Dock reopen focuses an open aux window

## Regression risks

| Risk                                                                | Mitigation                                      |
| ------------------------------------------------------------------- | ----------------------------------------------- |
| **A missing `@Environment` injection crashes a rarely-opened pane** | AC3 + opening all 14 panes and both aux windows |
| `armedHover` starts lighting during keyboard nav                    | AC4 — the stationary-pointer test               |
| A forwarder is deleted while a caller remains                       | Compiler catches it                             |
| The menu-bar items break because they lost their singleton access   | Boundary: `TinycastApp` is exempt               |
| `AppCore` regrows because a "convenience" accessor is added         | AC2/AC5                                         |

## Rollback strategy

`git revert <sha>`.

## Expected commit size

~25 files, +120 / −180 lines. `AppCore` net −60.

## Suggested commit message

```
Retire the AppCore forwarders and adopt @Environment in views

Phases 24–25 left thin forwarders so no view had to change; call sites now
address their coordinator directly. The 21 view-side AppCore.shared
reaches become @Environment. Three legitimate singleton uses remain: the
app delegate, the MenuBarExtra menu, and the panel that builds the
environment.
```

## Dependencies

**Phases 25b and 29 (hard).**

25b, not 25. This phase points every call site at its owning coordinator, which requires one to exist —
and phases 24–25 left the launcher, clipboard, emoji and calculator actions on `AppCore` with no owner.
Without 25b those call sites have nothing to be pointed at, and objective 1 is unachievable for them.

## Definition of Done

- All acceptance criteria met
- All 14 Settings panes plus About and Onboarding opened without crashing
- The stationary-pointer hover test passed
- Merged

## Estimated difficulty

**Medium.** Wide but shallow, with one runtime-only failure mode.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Open all 14 panes.** This is the phase where "it builds" is worth the least. `@Environment` failures
  are runtime, per-view, and invisible until that exact view is instantiated.
- Run the grep and confirm exactly three remaining `AppCore.shared` sites, each one of the three
  documented exceptions.
- The stationary-pointer hover test is quick and it protects a deliberate behaviour that is easy to lose
  when a `View` extension stops reaching the singleton.
- If `AppCore` is over 250 lines, ask what is left. The answer should be: stored properties, `start()`,
  `prepareForTermination()`, and `showNotice`/`confirm`.
