# Window Management

Rectangle-style window actions — halves, quarters, thirds, sizing, nudging, display moves and native
fullscreen — searchable in the palette and bindable to global shortcuts. 30 commands, no new
dependencies and no new permission: they reuse the Accessibility grant clipboard paste already needs.

Ships **off**. Settings › Window Management is the switch, and while it is off there are no launcher
entries and a still-registered shortcut moves nothing.

## Layout

| File                                             | Imports                      | Role                                                                |
| ------------------------------------------------ | ---------------------------- | ------------------------------------------------------------------- |
| `Features/WindowManagement/WindowCommand.swift`      | Foundation                   | Catalog: id, name, symbol, kind, group, `cyclesOnRepeat`, `resizes` |
| `Features/WindowManagement/WindowLayout.swift`       | Foundation + CoreGraphics    | **Pure.** Every frame the commands produce                          |
| `Features/WindowManagement/WindowActionMemory.swift` | Foundation + CoreGraphics    | **Pure.** Per-window cycle position and restore point               |
| `Features/WindowManagement/WindowMover.swift`        | AppKit + ApplicationServices | `@MainActor`. Every `AXUIElement` call and the coordinate flip      |

The first three compile into `Tools/window-command-test.swift`, so they must not gain an AppKit,
SwiftUI or `NSScreen` dependency, and must stay pure — `WindowActionMemory` takes `now` as a parameter
rather than reading a clock. CoreGraphics is needed only because `CGRect`'s `Equatable` conformance
lives in that overlay rather than in Foundation.

Adding a command is four edits in `WindowCommand.swift` (a case in `ID`, plus `name`, `symbol` and
`group` arms), an arm in `WindowLayout.placement` or `tileFractions`, and bumping
`commands.count == 30` in the harness.

## Coordinate space

**`WindowLayout` works exclusively in AX space**: global coordinates, top-left origin, +Y pointing
_down_. `WindowMover.AXGeometry` is the only place that converts to and from Cocoa's bottom-left space.
The visible consequence is that Top Half has `minY == visibleFrame.minY`, which the harness asserts
specifically to stop a bottom-left convention creeping back in.

The flip is anchored on the **primary** display's height — the display whose Cocoa frame origin is
`(0, 0)` — never on the window's own screen. Both global spaces are anchored on the primary; flipping
through the window's own screen height shears every rect on a differently-sized display by the height
difference. That bug is invisible on a single monitor and wrong on every mixed-size multi-monitor
setup, so it is worth stating twice.

`AXGeometry` is snapshotted once per command: `NSScreen.screens` can change between calls on hotplug,
wake or a resolution change, and mixing two anchors inside one command corrupts the result.

Nothing here touches `backingScaleFactor`. `NSScreen.frame`, `NSScreen.visibleFrame` and AX
coordinates are all in points, so mixed-DPI correctness is automatic; a scale factor appearing anywhere
in this feature is a bug. `visibleFrame` already excludes the menu bar, the Dock and the notch.

## Geometry

**Tiles** come from fractional bounds of `visibleFrame`. Gaps use one rule that composes across every
family: an edge sitting on the screen boundary takes the full gap, an interior edge takes half. Two
adjacent tiles therefore leave exactly `gap` between them and every screen edge is inset by `gap`, with
no per-family special cases. Rects are rounded on their four **edges**, not origin + size, so two tiles
sharing a fractional boundary (480.333 for thirds of 1441) round it identically — no overlaps, no
one-point seams.

**Free-floating commands** (Maximize, Almost Maximize, Reasonable Size, Center, Make Larger/Smaller,
the nudges) work in
`canvas = visibleFrame.insetBy(gap)` instead: a centred window has no neighbour to gutter against.

**Make Larger / Make Smaller** step by 5% of the _screen_, not of the window, and the step is forced
even so each edge moves a whole point. That makes the two commands exactly invertible — `size × 0.95 ×
1.05 ≠ size`, so a size-relative step would shrink a little on every round trip — and it feels the same
at any window size. Both directions saturate into exact no-ops: the ceiling is the canvas, the floor is
`max(200×150, 15% of canvas)`.

**Reasonable Size** is 60% of the canvas, centred, capped at 1025×900 points. The cap is what makes it
display-independent — a laptop gets the fraction, a 4K or 5K display gets a moderate window instead of
a 2304×1296 one. It ignores the window's current size entirely, so it is idempotent.

**Center Half** is half the screen's _area_: half width, full height, horizontally centred — the family
sibling of Center Third.

An oversized or off-screen window is always clamped back onto the display; `clamped` pins the leading
edge rather than shoving the window off the far side. Maximize Height and Maximize Width keep the
untouched axis's position but clamp it, so a window sitting off the display doesn't come back
full-height and still off-screen.

## Cycling and Restore

Both reduce to one question — _has the user moved this window themselves since our last action?_ — so
`WindowActionMemory` answers it once. It is generic over the key so it stays Foundation-only: the app
keys by `AXUIElement` (via `CFEqual`/`CFHash` plus the pid), the harness keys by `Int`.

`decide` is a pure query returning the cycle step, which is then fed into `WindowLayout.Input.step` —
cycle state is never hidden inside the geometry. Its rules, in order:

1. No record → step 0, capture the current frame as the restore point, `canRestore: false`.
2. The frame drifted from `appliedFrame` by more than 2 pt → step 0, **and refresh** the restore point.
3. A different command, a different display, cycling disabled, a non-cycling command, or a lapsed
   `cycleTimeout` → step 0.
4. Otherwise → `(step + 1) % 3`.

Two details carry their weight:

- **Rule 2 compares against the frame we observed, never the one we asked for.** Terminal resizes in
  whole character cells and never lands exactly on target; comparing against the target would read as
  "the user moved it" on every press and break both cycling and Restore for such apps.
- **Restore is single-level, not a stack.** Left Half → Maximize → Top Right → Restore lands on the
  original frame, because rule 1 captures once and the intermediate actions never overwrite it. A stack
  has no defensible answer for what a _second_ Restore press should do.

Rule 1 also delivers the "works for windows Tinycast never moved" requirement: the capture happens in
`WindowMover.perform` before a single write.

**Cycling covers the four halves only** (½ → ⅓ → ⅔), and is off by default. Top and Bottom Half cycle
through _vertical_ thirds, which have no commands of their own — the Thirds group is horizontal — so
they are expressed as fractions rather than other command IDs.

Growth is bounded three ways: an LRU cap of 64, an `NSWorkspace.didTerminateApplicationNotification`
observer (the house `NotificationToken` RAII idiom) dropping a quit app's keys, and lazy invalidation
when a read fails. Nothing is persisted.

## Applying a placement

`WindowMover.perform(_:target:gap:cycleOnRepeat:)` is the only entry point. `target` is **explicit**
because the palette is frontmost when a command dispatches from it — `AppCore.runWindowCommand` passes
`windowController.previousApp`, the same recorded app the paste path targets, and restores focus to it
rather than dropping it. It is synchronous: every AX call is a bounded mach round trip capped by a 1s
messaging timeout, and `await` would only add reentrancy between a held hotkey's repeats. The timeout
is set on the application element _and again_ on the window element — it is per-element and never
inherited.

The write sequence is **size → position → size**. Whichever single order you pick is wrong in one
direction: growing first fails when the source display is smaller than the target size, shrinking first
leaves the window shrunken after a cross-display move. Writing the size on both sides of the position
write costs one extra round trip and makes both directions correct with no branching; one of the two is
always a no-op.

**Failing quietly** is a requirement, not a nicety, and has three distinct paths:

- Position not settable → return with **zero** writes; the window is untouched.
- Size not settable → the move-only branch: one position write placing the size it already has inside
  the slot per the placement's anchor. One coherent move, never a half-applied one.
- The position write fails after the shrink → roll the size back. Net visible effect: nothing.

The frame is read back **once** afterwards, for three reasons: to detect an app-imposed minimum size
(AX exposes no attribute for it, so the read-back is the only way to learn it), to record a truthful
`appliedFrame`, and to report whether anything actually changed. When the app refused to shrink, the
window is re-placed per the placement's `anchor` so a left half stays left-aligned instead of drifting
centre. **One correction, no loop** — iterating against an app that fights back just makes the window
visibly jitter.

**Toggle Fullscreen** uses the undocumented `AXFullScreen` attribute, falling back to pressing
`AXFullScreenButton`, then a quiet no-op. There is deliberately no synthetic ⌃⌘F third attempt: it is
app-rebindable and could fire an unrelated menu command. It does not read geometry back — the
transition is animated and asynchronous, so any frame read there is a mid-animation value — and it
clears the cycle chain while keeping the restore point, since macOS restores the pre-fullscreen frame
itself but the user's original frame is still the right Restore target.

Windows that are minimized, not `AXWindow`-roled (sheets, popovers), already natively fullscreen, or
that report no position or size are rejected before any work happens.

`AXEnhancedUserInterface` is cleared for the duration of the writes and restored immediately, because
some apps reinterpret frame writes while it is on — but never while VoiceOver is running, which would
break the screen reader. **This mitigation is inherited convention and unverified on macOS 26**; if a
stock Electron app tiles correctly without it, delete the helper rather than keep it.

## Wiring

- **`AppEntry.Kind.windowCommand`** — entries are `window-command:<id>`, published by
  `AppIndex.setWindowCommandsVisible(_:)` between the system-action and custom-command slices.
  `LauncherView.rows` mirrors that position with a "Window Management" section; the slice order is the
  flat-selection invariant, so the two must move together.
- **`HotKeyAction.windowCommand(id:)`** — persisted under
  `KeyboardShortcuts_windowCommandHotkey.<raw-id>`, matching the legacy prefix convention. Unlike
  custom commands there is no bound-ID index to maintain: the catalog is fixed, so `HotKeyManager.start`
  and `conflictOwner` iterate `WindowCommand.ID.allCases` and `register` no-ops on an unbound command.
- **`AppCore.runWindowCommand(id:)`** is the one funnel for both palette activation and the global
  hotkey, so the feature switch cannot be bypassed by either.
- **Settings** — `windowManagementEnabled` (off), `windowManagementShowInLauncher` (on), `windowGap`
  (0) and `windowCycleOnRepeat` (off). All four ride in settings backups: unlike `snippetsEnabled` they
  grant no permission class of their own.
- **Per-command visibility** reuses `VisibilityStore` as-is; clearing a recorded shortcut is how a
  hotkey is disabled, so there is no separate per-command enabled flag. Window commands deliberately
  get **no** launcher-category pane of their own — they are managed inside Settings › Window
  Management, the same call already made for snippets.

## Testing

`Tools/window-command-test.swift` (319 assertions) covers the catalog, the AX-space convention lock,
tiling on divisible and non-divisible screens, off-origin and negative-coordinate displays, gap
arithmetic including degenerate values, sizing, the Make Larger/Smaller round trip, nudges, display
moves and wrapping, restore recovery, every `WindowActionMemory` rule, and a fuzz sweep over every
command × gap × screen × degenerate window frame checking for non-finite output, negative dimensions,
off-screen results, non-determinism and drift on repeat.

Everything runs headless because the layer is pure. `WindowMover` is not compiled into the harness and
has no automated coverage — the AX paths need manual verification, particularly:

1. A non-resizable window (System Information) must fail silently, left untouched rather than
   half-moved.
2. **A mixed-resolution multi-monitor setup** — the coordinate-flip bug appears nowhere else. Tile on
   the secondary display, then round-trip Next/Previous Display.
3. Toggle Fullscreen on a window that accepts it and one that refuses it.
4. Cycling: three presses of Left Half, then drag the window and confirm the next press restarts at ½.
5. Restore on a window Tinycast has never moved.
