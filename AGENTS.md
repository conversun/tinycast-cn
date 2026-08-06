> ## ⚠ An approved architecture refactor is in progress
>
> Some **structural** rules in this file — file layout, type ownership, which type does what — are being
> changed by it. That is deliberate, and a phase contradicting one of them is **not** an error.
>
> **If you are executing a phase from [`docs/refactor/`](docs/refactor/), the phase document overrides
> the architectural guidance here.** Read
> [`docs/refactor/prompts/system-prompt.md`](docs/refactor/prompts/system-prompt.md) for the full
> precedence ladder, and [`docs/refactor/POLICY.md`](docs/refactor/POLICY.md) for the migration and
> compatibility rules.
>
> **Behavioral invariants below always hold** — UI, keyboard behaviour, accessibility, permission and
> consent flows, Swift 6 data-race safety, and the explicitly off-limits files. A phase that contradicts
> one of *those* is wrong: stop and say so.
>
> **If you are not working from a `docs/refactor/` phase**, ignore this box entirely and follow this
> file as written.

## Project

Tinycast is a native macOS menu-bar launcher (a minimal Raycast): fuzzy app launcher, global +
per-app hotkeys, a text/image clipboard history, an inline calculator, and an emoji picker. SwiftUI +
AppKit, runs as an accessory (no Dock icon, `LSUIElement`). Targets **macOS 26+** (Liquid Glass) and
builds with the **Xcode 26** toolchain.

- **Build:** XcodeGen owns the project — `Tinycast.xcodeproj` is committed but generated from
  `project.yml`. After editing `project.yml`, run `xcodegen generate` and commit. There is **no**
  `Package.swift` / SwiftPM. Full build/test/sign/release steps: [`docs/development.md`](docs/development.md),
  [`docs/signing.md`](docs/signing.md).
- **Channels:** Debug builds are their own channel — `Tinycast Dev.app` / `com.tinycast.app.dev` — so a
  local run never shares prefs, caches, TCC grants or login item with an installed stable/beta.
  Anything newly persisted must stay keyed by `Bundle.main.bundleIdentifier`.
- **Tests:** no XCTest target — standalone `swiftc` harnesses in `Tools/` (see Critical Invariants and
  `docs/development.md`).

## Project Philosophy

General engineering principles — simple over clever, declarative views, Swift 6 isolation, remove dead
code — come from the global `CLAUDE.md` and are not repeated here. Tinycast adds one rule of its own:

- **Comments are single-line** — no stacked / multi-line blocks. Only comment the non-obvious (a
  _why_, a gotcha, a load-bearing invariant); never restate the code.

## Architecture

Full detail: [`docs/architecture.md`](docs/architecture.md).

- **Single-owner core.** `AppCore.shared` (`App/AppCore.swift`) is a `@MainActor` singleton owning
  every long-lived manager and the window controllers.
  `AppDelegate.applicationDidFinishLaunching` calls `AppCore.shared.start()` and nothing else — that
  is the one wiring point. Palette / paste / launch actions are methods on `AppCore` that views call.
- **Mostly AppKit windows.** `TinycastApp` (`@main`) declares only a `MenuBarExtra` scene. The command
  palette is a borderless floating `NSPanel` hosting SwiftUI; Settings/About are plain `NSWindow`s via
  `AuxWindowController`. SwiftUI `Settings` / `Window` scenes are deliberately avoided (unreliable for
  accessory apps).
- **Subsystems:** [palette](docs/palette.md) · [launcher & fuzzy match](docs/launcher.md) ·
  [calculator](docs/calculator.md) · [clipboard](docs/clipboard.md) · [emoji](docs/emoji.md) ·
  [snippets](docs/snippets.md) · [quicklinks](docs/quicklinks.md) ·
  [window management](docs/window-management.md) ·
  [hotkeys](docs/hotkeys.md) · [uninstall](docs/uninstall.md) ·
  [Raycast import](docs/raycast-import.md) · [UI & design system](docs/ui.md).

## Critical Invariants

Never break these without an explicit task to do so.

- **`AppCore` is the sole owner.** New long-lived state belongs on `AppCore`, wired in `start()`; don't
  create competing singletons or wire managers elsewhere.
- **`PaletteWindowController` solely owns the palette frame.** The hosting view sets
  `sizingOptions = []` so SwiftUI never drives the window size — otherwise the top edge drifts on the
  compact↔expanded swap.
- **The app is locked to `.darkAqua` globally.** The Liquid Glass material is tuned for a dark surface
  only; do not add light-mode styling.
- **The flat `selection` index must match the visible row order exactly**, including the inline
  calculator card at index 0 when present. Selection is the single source of truth for highlight /
  activation. `Features/PaletteRowIndex.swift` is that mapping, and it stays **Foundation-only and
  pure** — no SwiftUI, no AppKit — so `Tools/palette-selection-test.swift` compiles the shipped type
  rather than a copy. Section headers are not selectable and never consume an index.
- **`AppEntry.Kind` is the only thing that says what an entry is.** One case per launcher section, per
  `VisibilityStore` category and per Settings pane — never re-derive a category by sniffing an entry ID
  (that's what `isCustomCommand` used to do). A new category means a new case, a slice in
  `AppIndex.publishEntries()`, and the matching filter in `LauncherList.rows`, in that same order.
- **While a footer menu is open the palette search field never resigns first responder** — input is
  frozen instead (resigning shifts the text a point or two). See [palette.md](docs/palette.md).
- **Focus restoration is load-bearing.** Paste targets the recorded `previousApp` and requires the
  Accessibility permission (`Permissions.ensureAccessibility()`). See [palette.md](docs/palette.md).
- **`Features/Calculator/Model/` (incl. `CalcDateTime`) must stay Foundation-only *and pure*** — no AppKit /
  SwiftUI imports, no clock or network reads. `Tools/calc-test.swift` compiles the real engine
  sources. Both externally-sourced inputs are injected: the clock via `now`/`calendar`, the FX table
  via `rates` (`CurrencyRateStore` owns the fetch). Likewise `Features/Emoji/Model/`
  (`EmojiCatalog`, `EmojiGridGeometry`) stays AppKit/SwiftUI-free for `Tools/emoji-test.swift`, and
  `Features/Clipboard/Model/ClipboardStore.swift` must keep to Foundation + SQLite3 with no other app source, so
  `Tools/clipboard-test.swift` can compile it standalone. `Launcher/Model/LauncherRankingStore.swift` is the
  same deal for `Tools/ranking-test.swift` — Foundation only, with the clock injected via `now` and
  the store path via `fileURL`, as is `Launcher/Model/SearchScopes.swift` for `Tools/scopes-test.swift`.
  `CustomCommands/Model/CustomCommand.swift` and `CustomCommands/Service/ShellCommandRunner.swift` must stay free of AppKit /
  SwiftUI (Foundation plus Darwin for `mkstemp`) so
  `Tools/custom-command-test.swift` can compile them standalone — which is why the custom-command
  confirmation gate lives in `AppCore` and not in the runner. All of `Features/Snippets/Model/` and
  `Service/` compiles into `Tools/snippets-test.swift` (it globs both), so the model, Markdown serializer,
  template engine, repository and keyword policies stay Foundation-only, and the AppKit files there
  keep their dependencies to what the harness can stub. `SystemActions/Model/SystemAction.swift` is also
  Foundation-only for `Tools/system-action-test.swift`; platform effects belong in
  `SystemActionRunner`, while confirmation and failure UI remain in `AppCore`.
  `SystemActions/Model/VolumeLevel.swift` is the same split for `Tools/volume-test.swift` — the 5% step grid and the
  percentage string are pure Foundation, CoreAudio lives in `SystemActionRunner` and observation in
  `VolumeState`, so both the HUD and the Set Volume slider walk one tested grid. `Features/WindowManagement/`
  splits the same way for `Tools/window-command-test.swift`: `WindowCommand.swift`, `WindowLayout.swift`
  and `WindowActionMemory.swift` stay Foundation + CoreGraphics and pure (no AX, no `NSScreen`, no
  clock — `WindowActionMemory` takes `now` as a parameter), while every `AXUIElement` call and the
  Cocoa↔AX coordinate flip live in `WindowMover.swift`.
- **`WindowLayout` works exclusively in AX space** — global coordinates, top-left origin, +Y **down**.
  `WindowMover.AXGeometry` is the only place that converts, and it anchors the flip on the **primary**
  display's height, never the window's own screen: doing otherwise shears every rect on a
  differently-sized display by the height difference, which is invisible on one monitor and wrong on
  every mixed-size setup. The visible consequence is that "Top Half" has `minY == visibleFrame.minY`;
  `Tools/window-command-test.swift` asserts it. Nothing in this feature ever touches
  `backingScaleFactor` — all three of `NSScreen.frame`, `visibleFrame` and AX coordinates are in points,
  so mixed-DPI correctness is automatic. See [window-management.md](docs/window-management.md).
- **Uninstall moves to the Trash and never deletes.** `FileManager.trashItem` is the only removal
  call in the feature; `removeItem` must never appear there. That is what makes display-name
  attribution tolerable — a false positive costs a drag back, not the user's data — so a
  "delete permanently" option would have to drop name matching in the same commit. The deciding half
  (`UninstallTarget.swift`, `UninstallSearchRoot.swift`, `UninstallRules.swift`,
  `UninstallProtection.swift`, `UninstallPlan.swift`) stays Foundation-only and pure for
  `Tools/uninstall-test.swift`, with every environment fact injected: the scanner hands the rules
  directory **names**, never URLs, and hands the classifier a `PathFacts`. Every `FileManager`,
  `lstat` and Full Disk Access read lives in `UninstallScanner`, which **detects** FDA (a silent,
  promptless probe) and never requests it — this feature asks for no permission and never escalates
  privilege. `tccRelativePrefixes` is **measured, not assumed**: probe a location by creating and
  trashing a throwaway directory there before adding it, because *listing* is not the test —
  `~/Library/Containers` enumerates fine and still refuses the move, while
  `~/Library/Application Scripts` allows it. A locked candidate can never enter the checked set; that invariant lives in
  `UninstallSelection`'s one intersection, not in the view. Tinycast also refuses to plan its own
  uninstall, compared against the **running** identity so the Dev channel refuses itself too.
  See [uninstall.md](docs/uninstall.md).
- **Quicklinks are authored data, and their store never deletes.** `Quicklinks/Model/` splits like
  `Uninstall/Model/`: `Quicklink.swift`, `QuicklinkDestination.swift`, `QuicklinkStore.swift` and
  `QuicklinkArchive.swift` stay Foundation-only (plus SQLite3) and pure for
  `Tools/quicklink-test.swift` — the home directory is injected, never read — while `QuicklinkLauncher`
  owns every `NSWorkspace` call and `QuicklinkArgumentSession` the prompt state. The database lives in
  **Application Support**, not Caches, and a database that won't open is **reported, never discarded**:
  `ClipboardStore`'s delete-and-recreate is only sound because history is regenerable, and a link
  library is not. `Quicklink.precedes` is the one display order, sorted through by both the store and
  the `AppIndex` slice. There is **one template engine**: quicklinks expand through
  `SnippetTemplateEngine` rather than a second parser, which is what makes `| raw` mean something —
  it opts a value out of the automatic percent-encoding a URL destination asks for. `{selectedText}`
  is accepted as an alias for `{selection}`, but nothing ever *writes* it. See
  [quicklinks.md](docs/quicklinks.md).
- **`Launcher/Model/SearchRelevance.swift` is Foundation-only and pure**, so `Tools/fuzz-test.swift` compiles
  the shipped scorer rather than a copy of it. It owns both `FuzzyMatch` (the tiered
  exact/prefix/word-start/substring/subsequence scorer) and the field bands. **Searchable fields stay
  separate** — display name, Spotlight alternate names, bundle id, executable name are never flattened
  into one string, because the field is what picks the band. Bands are one `bandStride` apart, an
  order of magnitude above `FuzzyMatch.maximumScore` and two above `LauncherRankingStore`'s boost cap:
  that gap is what keeps a learned boost reordering *within* a tier and never across a tier or a
  field. A new searchable field means a new `Band` case and a `consider` call, in priority order.
- **`EmojiData.generated.swift` is emitted by `node Tools/gen-emoji.js` and
  `CurrencyData.generated.swift` by `node Tools/gen-currencies.js`** — never edit either by hand.
  Currency names, signs and uncontested nouns are generated (Frankfurter × CLDR); the only
  hand-maintained currency data is `CalcCurrency.contested`, the nouns several currencies share
  (`dollars`, `pounds`). Don't add slang or synonyms there — no source of truth, so they rot.
- **Every networked feature ships off and is consent-gated.** Tinycast is offline by default; a
  feature that reaches the network must be opt-in behind a Settings toggle whose dialog names the
  provider, the cadence and what leaves the machine, and its owning store must re-check consent at
  every entry point — including on both sides of the `await` around the request, since consent can
  be withdrawn mid-flight. Consent flags live on the owning store, never in `AppSettings`
  (`SettingsBackup` mirrors that type, and an import must not grant network access). Model the gate
  so the *safe* state is the default: `CalcEngine.evaluate`'s `currency:` parameter defaults to
  `.off`, so forgetting to pass one disables the feature rather than enabling it. Fetch on a private
  **cacheless** `URLSession` (`.ephemeral`, `urlCache = nil`), never `URLSession.shared` — a cacheable
  response would leave a second copy in the on-disk `URLCache` that opting out doesn't delete.
  `CurrencyRateStore` is the reference implementation — follow it rather than inventing a second shape.
- **Snippets are channel-isolated and path-identified.** Persist them under
  `~/Library/Application Support/<bundle-id>/Snippets/`; `StoredSnippet.ID` is the standardized source
  path, and external rename is delete + create. The feature ships off and its enable switch doubles as
  keyword-expansion consent: `snippetsEnabled` is excluded from settings backups, and Accessibility —
  the only permission, since the listen-only tap needs nothing more — may be requested only from that
  explicit Settings gesture, never from startup, callbacks, watchers or health checks.
  See [snippets.md](docs/snippets.md).
- **The two Raycast export formats share no mapper.** `RaycastFormat.detect` is the *only* branch
  between them; `RaycastImportV1` and `RaycastImportV2` own their own decrypt and their own field
  mapping, and neither is ever tried as a fallback for the other (that is what makes a wrong
  passphrase report a wrong passphrase instead of "not a Raycast export"). They meet only at
  `RaycastImport.Result`. `RaycastFormat.swift` and `RaycastV1Decoder.swift` stay Foundation +
  CommonCrypto + Carbon so `Tools/raycast-test.swift` compiles them standalone, which is why the
  decoder returns Raycast's own values and `RaycastImportV1` — not the decoder — validates them
  against `PopToRootTimeout` / `EmojiSkinTone` / `HyperKeyPhysicalKey` / `KeyShortcut`. Never commit a
  real `.rayconfig` as a fixture: the harness builds its own. See
  [raycast-import.md](docs/raycast-import.md).
- **Swift 6 language mode: data-race violations are hard errors.** Almost everything is `@MainActor`;
  cross-actor model types are `Sendable`; heavy / IO work (app scan, image decode) is pushed off-main
  via `Task.detached` / `nonisolated`. Keep that boundary. House idioms: `NotificationToken` (RAII) for
  block observers, `isolated deinit` for `ClipboardStore`'s SQLite teardown, decode raw Carbon / C
  pointers to plain values before crossing into actor code.
- **Clipboard writes stamp a private `internalType` marker** so the poller skips Tinycast's own writes.
- **Hotkeys persist under legacy `KeyboardShortcuts_<name>` UserDefaults keys** (from the removed
  KeyboardShortcuts package) so old bindings survive. `HotKeyBinding` is the one thing an action is
  bound to and it has two cases with two engines: a `.combo` is a Carbon registration, a `.doubleTap`
  is recognized by `DoubleTapMonitor` (Carbon cannot see a lone modifier at all). Its `Codable`
  conformance is the compatibility seam — a `.combo` must keep encoding as the bare
  `{"carbonKeyCode":N,"carbonModifiers":N}` record and decoding must keep trying that shape first, or
  every existing binding and backup breaks. `HotKeys/Model/DoubleTapModifier.swift` and
  `DoubleTapDetector.swift` stay Foundation-only and pure with the clock injected as a parameter, for
  `Tools/hotkey-test.swift`; every `CGEvent` call lives in `DoubleTapMonitor.swift`, which is
  listen-only, installs *only* while something is bound to a double-tap, and never prompts for
  Accessibility. See [hotkeys.md](docs/hotkeys.md).
- **Tinycast presents its own dialogs, never `NSAlert` / `NSSlider` / system popovers.** Every
  confirmation, failure report and value prompt goes through `DialogController` (`Windows/Dialog/`,
  owned by `AppCore`; reachable elsewhere via `AppCore.showNotice` / `confirm`). Presentation is
  `async`, so there is no nested run loop, and the presenter refuses a second dialog while one is up
  — that, not a flag, is what stops a held hotkey stacking dialogs. **↵ runs the primary action,
  Escape cancels, and Cancel always renders leading** (the left button), matching macOS convention.
- **A dialog has three independent axes; never let one infer another.** The **icon**
  (`DialogRequest.symbol`, required) is always the *subject's* own glyph — the command being
  confirmed uses its `SystemAction.sfSymbol`, so the Restart dialog shows the same icon as the
  Restart row. Tone never picks an icon. The **tone** (`DialogTone`: `.neutral` / `.success` /
  `.danger`) tints only that glyph. The **button** takes its color from `DialogAction.Role`
  (`.standard` white / `.destructive` red / `.cancel` secondary), so a red-glyph security warning can
  still carry a plain white button — as "Import executable commands?" does. Resolve every glyph
  through `SymbolImage`, not `Image(systemName:)`: some catalog symbols are bundled assets
  (`toggleBluetooth`). A button never prints its key cap; hovering it shows a `Tooltip`
  (`DesignSystem/Tooltip.swift`) instead, styled like the palette's own keycap chips.
- **A transient readout is a HUD, not a dialog.** `VolumeHUDController`'s box is volume/mute only,
  since that one needs an actual level and number; every other success/info confirmation (system
  commands, Custom Commands, Snippets) goes through `MessageHUDController`'s pill, whose trailing
  glyph *is* its `DialogTone` — a pill has no subject to name, so the dialogs' icon rule doesn't
  apply, and the mapping stays file-scoped so nothing can reach for it when building a
  `DialogRequest`. Both are driven by `HUDPresenter`, which owns the one-at-a-time / auto-dismiss /
  fade policy; a new HUD means a new presenter, not a second shape bolted onto an existing
  controller. See [ui.md](docs/ui.md#dialogs--hud).
- **Glass is for controls; content takes the panel recipe.** `glassEffect` needs a backdrop to lens,
  so it only works *inside* a window that already has a `VisualEffectView` — the action capsule, the
  menu circle, `PopoverMenu`, a dialog's buttons. On a bare borderless panel it falls back to an
  opaque backing and shows as a dark edge. Both HUDs therefore use `black panelDimming` →
  `VisualEffectView()` → `clipShape`, exactly like a dialog.
- **Read [`docs/ui.md`](docs/ui.md) before any restyle or new view.** `DesignSystem/Theme.swift` is the
  single design-token source.
- **`DesignSystem/Scrolling/EdgeDissolve.swift` and `DesignSystem/Scrolling/ThinScrollbar.swift` are
  off-limits.** Both are tuned by eye against the palette's floating bars, so any edit is a visual regression. Do not touch them to fix a
  scroll bug, and never as a side effect of a restyle or refactor — needing to is the signal that the
  real fix belongs elsewhere (a scroll target, an inset, an intent). Edit either one only under an
  explicit task to change that look.

## Project Layout

- `Tinycast/DesignSystem/` — the shared visual primitives: `Theme.swift` is the design-token source,
  plus `KeyCapChip`, `Tooltip`, `SymbolImage`, `VisualEffectView`, `PopoverMenu`,
  `SettingsComponents`, `Scrolling/` and `Interaction/`.
- `Tinycast/Platform/` — the system shims: `Permissions`, `LaunchAtLogin`, `CursorScreen`,
  `AppDisplayName`, `NotificationToken`, `AppPaths`, `Signposts` and `Images/`.
- `Tinycast/Palette/` — the palette shell: `PalettePanel`, `PaletteWindowController`,
  `RootPaletteView`, the `PaletteScreen` protocol, `PaletteCoordinator` and the `PaletteState` /
  `PaletteMode` / `PasteTarget` state types.
- `Tinycast/Windows/` — the non-palette AppKit surfaces: `AuxWindowController` (Settings, About,
  Onboarding), `Dialog/` and `HUD/`, kept separate because a dialog asks and a HUD reports, plus
  `About/`.
- `Tinycast/Features/<Name>/` — one folder per feature, holding everything that feature owns:
  `Launcher/`, `Clipboard/`, `Calculator/`, `Emoji/`, `Quicklinks/`, `Snippets/`, `Uninstall/`,
  `SystemActions/`, `CustomCommands/`, `HotKeys/`, `Backup/`, `WindowManagement/`, `Onboarding/`.
  Larger features split into `Model/` (pure — the standalone-harness inputs), `Service/` (effects:
  stores, monitors, runners, AppKit glue), `UI/` (screens, views and the feature's coordinator) and
  `Settings/` (its own panes). **A file under `Model/` may not import AppKit or SwiftUI** — that is
  the checkable form of the purity invariants above. Small features stay flat.
  `Features/PaletteRowIndex.swift` sits at the top level because the palette, not one feature, owns it.
- `Tinycast/Features/Settings/` — the Settings shell only: `SettingsRootView`, `SettingsTab`,
  `AppSettings`, and `Panes/` for the two panes no feature owns (General, Permissions). Every other
  pane lives with its feature. Each `SettingsTab` maps to one `…SettingsView` built on the
  `SettingsPane` / `SettingsCard` scaffold in `DesignSystem/SettingsComponents.swift`; the four
  launcher-category panes (Applications, System Settings, System Actions, Commands) are thin wrappers
  over the shared `LauncherItemsCard`.
- `Tinycast/App/` — `@main` app, delegate and `AppCore`, the composition root.
- `Tools/` — standalone test harnesses and the emoji generator.
- `.github/workflows/release.yml` — the entire release pipeline (see `docs/development.md`).

## Naming vocabulary

A type's suffix says what it *is*. Each row below is a suffix, what it means, and — where the set is
small enough to enumerate — every type that currently carries it, so a reader can tell a closed set
from an open one. The table governs **top-level types**; a private nested helper is free to be named
for its job.

**A new type takes an existing suffix, or this table gains a row in the same commit.**

| Suffix        | Means                                                          | Members                                                                        |
| ------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `Store`       | Owns persisted state and publishes it                          | open (10)                                                                      |
| `Coordinator` | A feature's action surface, called by `AppCore` and the palette | open (10)                                                                      |
| `Controller`  | Owns one AppKit window or surface                              | open (5)                                                                       |
| `Catalog`     | Pure static namespace over a built-in list                     | `CommandCatalog`, `EmojiCatalog`, `SystemActionCatalog`, `WindowCommandCatalog` |
| `Index`       | A searchable collection, rebuilt as its inputs change          | `AppIndex`, `EmojiIndex`, `PaletteRowIndex`                                    |
| `Runner`      | Performs one effectful operation on request                    | `ShellCommandRunner`, `SystemActionRunner`, `UninstallRunner`                   |
| `Session`     | Transient state for one in-progress interaction                | `QuicklinkArgumentSession`, `ShortcutCaptureSession`, `UninstallSession`        |
| `Policy`      | A pure decision — no state, no effects                         | the three `Snippet…Policy` types                                               |
| `Engine`      | A pure evaluator: input → output                               | `CalcEngine`, `SnippetTemplateEngine`                                          |
| `Monitor`     | Watches an external stream and reports changes; owns no policy | `DoubleTapMonitor`, `RunningAppsMonitor`                                       |
| `Scanner`     | Reads the filesystem to produce candidates                     | `SettingsPaneScanner`, `UninstallScanner`                                      |
| `State`       | Shared observable state that persists nothing itself           | `OnboardingState`, `PaletteState`, `VolumeState`                               |
| `Manager`     | **Closed set of two.** Sole owner of a subsystem's lifecycle *and* its policy, started from `AppCore.start()`. Do not add a third — a new type wanting this suffix wants `Store`, `Monitor` or `Coordinator` instead. | `ClipboardManager`, `HotKeyManager` |

`Manager` survives on two types because neither alternative is honest. `ClipboardManager` polls, but it
also owns the capture policy (`sensitiveTypes`, `maxTextLength`, `internalType`, the disabled-apps
filter) and the paste-side handshake, which the two real `Monitor`s do not. `HotKeyManager` persists
bindings like a `Store`, but it also drives Carbon registration and double-tap dispatch.

Exceptions, each earning its own word:

- `Launcher` (`AppLauncher`, `QuicklinkLauncher`) — reserved synonym for an `NSWorkspace.open` wrapper.
  Clearer than `Runner` for opening things.
- `Repository` (`SnippetRepository`) — conflict-detecting, revision-checked file semantics that `Store`
  does not imply.
- `Center` (`HotKeyCenter`) — the Carbon registration layer specifically.
- `Presenter` (`HUDPresenter`) — owns the one-at-a-time / auto-dismiss / fade policy for both HUDs.
- Domain terms with no better alternative: `SnippetTextInjector`, `WindowMover`, `HyperKeyTap`.
- `Registry` and `ViewModel` are retired: a static table is a `Catalog`, shared app state is a `State`.
- SwiftUI-layer suffixes (`View`, `Screen`, `Card`, `Row`, `Sheet`) are a separate vocabulary and are
  not governed by this table.
