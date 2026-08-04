# Hotkeys (in-house, zero dependencies)

`Core/HotKey/` holds:

- `KeyShortcut` — Sendable model, Carbon keycode + modifiers, layout-aware glyphs via `UCKeyTranslate`.
- `HotKeyBinding` — what an action is actually bound to: a `.combo(KeyShortcut)` or a
  `.doubleTap(DoubleTapModifier)`.
- `HotKeyCenter` — the Carbon `RegisterEventHotKey` layer, pausable.
- `DoubleTapModifier` / `DoubleTapDetector` / `DoubleTapMonitor` — the double-tap stack.

`HotKeyManager` owns them all: persistence, conflict lookup, and dispatch. Every action reads and
writes one `HotKeyBinding`, so the two kinds share persistence, conflict detection, the recorder and
the keycap rendering — only the *engine* differs.

## Persistence

Bindings persist as JSON strings under `KeyboardShortcuts_<name>` UserDefaults keys — a **legacy
format** from the removed KeyboardShortcuts package, kept so old bindings survive. The set of bound
bundle IDs lives in `boundAppBundleIDs` and is re-registered on launch. System Settings panes use
`boundPaneBundleIDs`; custom commands and quicklinks use their stable UUIDs in
`boundCustomCommandIDs` and `boundQuicklinkIDs`. Those two are the per-item case — unlike a fixed
catalog, there is no `allCases` to walk — so each needs an index for `start()` to re-register from
and to prune bindings whose record was deleted while Tinycast wasn't running. That prune is why
`QuicklinkStore` loads at launch even when the feature is off
(see [quicklinks.md](quicklinks.md#hotkeys)).

A `.combo` writes the original `{"carbonKeyCode":N,"carbonModifiers":N}` record and
`HotKeyBinding.init(from:)` tries that shape first, so nothing needs migrating. A `.doubleTap` writes
`{"doubleTapModifier":"command"}` — a shape a pre-double-tap build fails to decode and therefore reads
as *unbound*, which is the intended degradation. The same wrapper is what `SettingsBackup.HotkeyBackup`
stores, so old backup files import unchanged; a backup containing a double-tap cannot be read by an
older build, which is what the `version` 3 bump records (`version` 4 adds the quicklinks array).

System actions and window commands are the fixed-catalog case: they persist under
`KeyboardShortcuts_systemActionHotkey.<raw-id>` and `KeyboardShortcuts_windowCommandHotkey.<raw-id>`
and need **no** bound-ID index, because `start()` and `conflictOwner` can just iterate `allCases` and
`register` no-ops on an unbound item. A registered window-command shortcut still runs nothing while the
feature switch is off — `AppCore.runWindowCommand` re-checks it (see
[window-management.md](window-management.md)); a system-action shortcut likewise goes through
`AppCore.runSystemAction(id:)`, so the confirmation gate holds for a hotkey exactly as it does for the
palette.

## Double-tap modifiers

Any action can instead be bound to a **double-tapped lone modifier** — ⌃, ⌥, ⇧ or ⌘. Carbon cannot
register a modifier-only shortcut at all, so this is a separate engine that meets the combo path only
at `HotKeyBinding`.

`DoubleTapDetector` is the recognizer: Foundation-only, pure, and clock-injected (`now` is a caller-
supplied monotonic timestamp), so `Tools/hotkey-test.swift` drives it without an event tap. A **tap**
is a press that starts from no modifiers held, keeps exactly one of the four held with no `fn`
alongside, sees no key press or mouse click, and is released within `maxHold` (250 ms — the same
window `HyperKeyTap` calls a quick press). A **double-tap** is a second tap of the same modifier
starting within `maxGap` (300 ms) of the first one's release.

Only *momentary* keys may feed `hasOtherModifiers`. Caps Lock must not: `maskAlphaShift` tracks the
**latch**, not a press, so testing it would disqualify every tap for as long as Caps Lock is on and
silently kill the feature. Caps Lock is still ineligible as a *binding* — that is what the Hyper Key
is for.

It **fires on the second release, not the second press**. The modifier is then already up when the
action runs, so the palette never opens with a phantom ⌘ held and focus restoration isn't polluted —
and "double-tap and hold" is a deliberate non-event.

`DoubleTapMonitor` is the one platform file. It is a **listen-only** `CGEventTap` and it installs only
while something is actually bound to a double-tap, so users who never use the feature pay nothing. Two
details are load-bearing:

- It is `.tailAppendEventTap`, unlike the two head-inserted taps, so it observes events **after**
  `HyperKeyTap`'s rewrite. A Hyper-remapped right-side modifier therefore arrives as the full ⌃⌥⇧⌘
  chord and correctly reads as "not a lone modifier" — the left-side twin still double-taps.
- Like every keyboard tap it needs the **Accessibility** grant, and it never prompts for it. The
  binding records regardless; the recorder shows an inline warning that opens System Settings, and the
  one-second health timer installs the tap the moment the grant lands.

⇧ is bindable this way even though `KeyShortcut` rejects a bare ⇧ combo: a double-*tap* is unambiguous
where a bare ⇧ combo would shadow typing.

## Recorder

The settings recorder (`Features/Settings/ShortcutRecorder.swift`) is deliberately **not** a focusable
control: the active recorder is `HotKeyManager.recordingAction` state, and keys are captured by local
NSEvent monitors while both engines are paused. It records both kinds — type a combo, or double-tap a
modifier — by feeding its `.flagsChanged` / `.keyDown` monitors into the *same* `DoubleTapDetector`
the global monitor uses, so recording needs no event tap and no permission.

Setting `recordingAction` is what starts and stops the capture, so there is exactly **one**
`ShortcutCaptureSession` (`Core/HotKey/`) for the app rather than one per row — which is what lets the
callout above the field render the live state from outside the row that opened it. The field itself
only ever shows the binding; the prompt, the live preview and the conflict message all live in the
callout. See [ui.md](ui.md#the-shortcut-recorder-callout).
