# Tinycast — Architecture Review & Refactoring Blueprint

**Scope of audit:** all 170 Swift files (35,270 lines; ~28,800 in `Tinycast/`, ~6,500 in `Tools/`),
`project.yml`, `.github/workflows/`, and all 17 documents in `docs/`.
**Constraints honoured throughout:** identical UI, identical UX, identical permissions model, no
regression in binary size (<3 MB upto 4MB), RAM (40–80 MB) or startup time, no new dependencies, incremental
only.

---

## 1. Executive Summary

Tinycast is, bluntly, in the top decile of macOS codebases of its size. It is not a codebase that
needs rescuing; it is a codebase that has outgrown the shape it was poured into. Almost every problem
below is a _scaling_ problem — the code is correct, fast and thoughtfully written, but the places
where new features are added have become shared bottlenecks.

### Scores

| Axis                  | Score        | One-line justification                                                                                                                     |
| --------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **Architecture**      | **7.5 / 10** | Coherent single-owner core and a genuinely good (but unnamed and undocumented-as-such) pure/effect split; undermined by two god objects.   |
| **Maintainability**   | **6.5 / 10** | A written invariants contract and valuable comment _content_; hurt by feature code split across three trees and by comment _volume_ (H-1). |
| **Performance**       | **8.5 / 10** | Memoized search, off-main IO, byte-bounded caches, measured decisions. Four concrete hot spots remain.                                     |
| **Scalability**       | **5.5 / 10** | **The weakest axis.** Adding one feature currently edits 10–14 files across 3 trees. This does not survive to 50 features.                 |
| **Memory efficiency** | **9.0 / 10** | Best-in-class: cost-bounded `NSCache`, preview purge on hide, capped stores, bounded in-memory windows.                                    |
| **Concurrency**       | **9.0 / 10** | Swift 6 complete mode, correct `assumeIsolated` at every C boundary, `isolated deinit` for C resources, disciplined `Task.detached`.       |
| **Code organization** | **5.5 / 10** | `Core/` is a 46-file flat dumping ground; ~20 competing type-name suffixes; 181 stacked comment blocks against a rule forbidding them.     |
| **Technical debt**    | **7.5 / 10** | Low _rot_; the debt is structural (concentration), not decay.                                                                              |
| **Overall**           | **7.4 / 10** |                                                                                                                                            |

### Biggest strengths (do not lose these in any refactor)

1. **The pure-core / effect-shell discipline is the real architecture.** Every serious subsystem is
   split into a Foundation-only, injectable-dependency, harness-compilable half and a platform half:
   `WindowLayout` vs `WindowMover`, `UninstallRules`/`UninstallPlan` vs `UninstallScanner`,
   `SystemAction` vs `SystemActionRunner`, `SnippetTemplateEngine` vs `SnippetTextInjector`,
   `QuicklinkDestination` vs `QuicklinkLauncher`, `VolumeLevel` vs CoreAudio, `SearchRelevance` vs
   `AppIndex`. This is ports-and-adapters, enforced not by protocols but by _what the test harness can
   compile_ — which is stronger, because it cannot be faked. **This should become the explicitly named
   organizing principle of the folder tree, not an emergent property.**
2. **Consent and permission modelling.** `CurrencyRateStore` is a reference implementation: default-off,
   ephemeral cacheless `URLSession`, consent re-checked on _both_ sides of the `await`, consent flag
   deliberately excluded from `SettingsBackup` so an import cannot grant network access. The same rigour
   applies to snippets (Accessibility requested only from the enabling gesture) and uninstall (FDA
   _detected_, never _requested_; `trashItem` only, `removeItem` never).
3. **Comment _content_ is excellent** — comments state _why_, name the gotcha, and cite the measurement
   (`SpotlightNames.Cache`: "76 ms cold, 0.2 ms after"; `IconCache.artworkExtent`: "folders paint 98% of
   the width and documents 69%"). The knowledge captured here is the most valuable asset for onboarding
   contributors. **The volume and formatting of that content is a separate problem — see H-1.** The fix
   is to relocate the good long explanations into `docs/`, not to lose them.
4. **Memory hygiene.** `NSCache` sized by _decoded byte cost_ rather than object count, previews purged
   on window hide, a 1000-row in-memory clipboard window with pinned rows exempted, capped ranking /
   history / frequency stores.
5. **Zero dependencies, XcodeGen-owned project.** Binary-size and merge-conflict risk are both near
   zero, and — critically for §4 — **moving files costs nothing but `xcodegen generate`.**

### Biggest weaknesses

1. **`AppCore.swift` (1,348 lines) is a god object.** It is simultaneously the DI container, the palette
   controller, the quicklink coordinator, the snippet expansion orchestrator, the system-action
   dispatcher, the uninstall coordinator, the dialog façade, the custom-command runner and the
   import/export front-end. It is the single hottest merge-conflict surface in the repository.
2. **`RootPaletteView.swift` (1,126 lines) is a god view** with **13 `@EnvironmentObject`s**. Under
   `ObservableObject`, _any_ change to _any_ of those 13 objects invalidates the entire palette body —
   including its filter chain — regardless of the current mode.
3. **No adoption of Observation (`@Observable`).** 26 `ObservableObject` classes, zero `@Observable`.
   The deployment target is macOS 26. This is the highest-leverage change available: it _reduces_ memory
   (no per-property Combine publisher storage), _reduces_ recomputation (per-property dependency
   tracking), _removes_ ~30 `MainActor.assumeIsolated { }` hazards, and _costs zero binary size_.
4. **A feature is not a place.** "Quicklinks" is 6 files in `Core/Quicklinks/`, 2 in
   `Features/Quicklinks/`, 2 in `Features/Settings/`, ~185 lines of `AppCore`, a slice method in
   `AppIndex`, 5 properties in `AppSettings`, 5 fields in `SettingsBackup`, 4 cases in `CommandRegistry`,
   an index in `HotKeyManager`, a `PaletteMode` case, and 5 code paths in `RootPaletteView`.
5. **Comment volume has inverted the signal-to-noise ratio.** 1,850 comment lines against 26,379 lines of
   non-generated source (**7.0%**), but the distribution is the problem, not the total: **181 stacked
   comment blocks** (a direct violation of the project's own "single-line, no stacked blocks" rule) and
   **953 comment lines over 100 characters — 51% of every comment in the codebase**, against only 158
   _code_ lines that long. The longest single comment line is **588 characters**. Files like
   `CurrencyRateStore` (27.7% comments) and `WindowActionMemory` (21.5%) read as prose with code
   interleaved. See H-1.

---

## 2. Current Architecture

### 2.1 The stated architecture

```
                       ┌─────────────────────────────────────────┐
   @main TinycastApp ──│  MenuBarExtra scene (the only Scene)     │
        │              └─────────────────────────────────────────┘
        │ NSApplicationDelegateAdaptor
        ▼
   AppDelegate.applicationDidFinishLaunching
        │  (one call, the single wiring point)
        ▼
   ┌────────────────────────────────────────────────────────────────────────────┐
   │  AppCore.shared            @MainActor, ObservableObject, 1348 lines        │
   │  ────────────────────────────────────────────────────────────────────────  │
   │  owns 21 long-lived objects · owns 5 window controllers                    │
   │  + is the action surface every SwiftUI view calls into                     │
   └────────────────────────────────────────────────────────────────────────────┘
        │                    │                      │
        ▼                    ▼                      ▼
   PaletteWindow-       AuxWindow-             Dialog / HUD
   Controller           Controller             Controller(s)
   (NSPanel +           (NSWindow +            (NSPanel + async
    NSHostingView)       NSHostingView)         continuation)
        │                    │
        ▼                    ▼
   RootPaletteView      SettingsRootView / AboutView / OnboardingView
   (1126 lines,          (14 panes)
    13 @EnvironmentObject)
```

`docs/architecture.md` describes exactly this and it is accurate. AppKit owns every window; SwiftUI is
used only as content; the SwiftUI `Settings`/`Window` scenes are deliberately avoided.

### 2.2 The _hidden_ architecture — and it is the good one

Independently of the folder tree, every mature subsystem has converged on the same four-layer shape.
The `Tools/` harnesses are what enforce it.

```
   ┌─ PURE LAYER ───────────────────────────────────────────────────────┐
   │  Foundation-only. No AppKit, no clock, no network, no filesystem.  │
   │  Every environment fact is an injected parameter.                  │
   │  ⇒ Compiled verbatim by a Tools/ harness. Cannot drift.            │
   │                                                                    │
   │  SearchRelevance · SearchScopes · LauncherRankingStore ·           │
   │  Calculator/* · Emoji{Catalog,GridGeometry} · SystemAction ·       │
   │  VolumeLevel · WindowCommand/Layout/ActionMemory ·                 │
   │  Uninstall{Target,SearchRoot,Rules,Protection,Plan} ·              │
   │  Quicklink{,Destination,Store,Archive} · Snippets/* ·              │
   │  CustomCommand · ShellCommandRunner · HotKey/DoubleTap{Modifier,   │
   │  Detector} · ClipboardStore · RaycastFormat · RaycastV1Decoder     │
   └────────────────────────────┬───────────────────────────────────────┘
                                │ consumed by
   ┌─ EFFECT LAYER ─────────────▼───────────────────────────────────────┐
   │  All platform I/O. One file per feature, by convention.            │
   │  AppIndex/SpotlightNames/SettingsPaneScanner · WindowMover ·       │
   │  UninstallScanner · UninstallRunner · SystemActionRunner ·         │
   │  QuicklinkLauncher · SnippetTextInjector · CurrencyRateStore ·     │
   │  Paster · HotKeyCenter · HyperKeyTap · DoubleTapMonitor            │
   └────────────────────────────┬───────────────────────────────────────┘
                                │ published through
   ┌─ OBSERVABLE STATE ─────────▼───────────────────────────────────────┐
   │  26 @MainActor ObservableObject stores/sessions/indices            │
   └────────────────────────────┬───────────────────────────────────────┘
                                │ rendered by
   ┌─ VIEW LAYER ───────────────▼───────────────────────────────────────┐
   │  Features/ — declarative, thin, no business logic (holds well)     │
   └────────────────────────────────────────────────────────────────────┘
```

**This is the architecture.** It just isn't the folder structure. §4 proposes making the two agree.

### 2.3 Dependency direction — where it inverts

The intended direction is `Features → AppCore → stores → pure core`. Three inversions exist:

```
   Core/HotKeyManager.swift:150,155,158,164  ──┐
   Core/HotKey/KeyShortcut.swift:49          ──┼──▶ AppCore.shared   ← Core reaching "up"
   Core/SystemActionRunner.swift:69          ──┘
```

- `HotKeyManager.displayName(of:)` reaches into `AppCore.shared.appIndex` / `.customCommands` /
  `.quicklinks` purely to render a conflict message.
- `KeyShortcut.collapsedModifierSymbols` reaches `AppCore.shared.settings` for the ✦ display preference.
- `SystemActionRunner` reaches `AppCore.shared.presentSystemActionFailure` from an async completion
  handler — the one place the documented "runner never shows UI" rule is bent.

None is a _cycle_ at the type level (Swift tolerates it), but each is a cycle at the _reasoning_ level:
you cannot understand `HotKeyManager` without understanding `AppIndex`, `CustomCommandStore` and
`QuicklinkStore`.

Total `AppCore.shared` references: **54 across 24 files**, including 21 from view files that already
have `AppCore` in the environment.

### 2.4 The palette's control flow (the hottest path in the app)

```
  ⌥Space (Carbon) ─▶ HotKeyCenter ─▶ HotKeyManager.perform ─▶ AppCore.togglePalette
                                                                     │
                    ┌────────────────────────────────────────────────┘
                    ▼
      PaletteWindowController.show()
        · records previousApp (paste/focus target)
        · resolves PasteTarget once per summon        ← good: not per render
        · resolves the screen anchor once per session ← good: no drift on resize
        · positions, layouts off-screen, orders front
                    │
                    ▼
      RootPaletteView.body  ── evaluates, per render:
        appResults      = appIndex.matches(query)  [memoized 1-deep]
                            .filter(visibility.isVisible)      ← NOT memoized
                            + favorites.ordered(...)           ← NOT memoized, O(n) dict
        clipResults     = store.search(query)      [memoized 1-deep]
        histResults     = calcHistory.search(query)[memoized 1-deep]
        emojiSections   = EmojiGrid.sections(...)  [index memoized 1-deep]
        calcResult      = CalcMemo.evaluate(query) [memoized]
        + 7-way switch for content()
        + 7-way switch for actionsContent
        + 7-way switch for resultCount / selection
        + 7-way switch for activateSelection
        + 7-way switch for actionPillLabel
```

The flat-`selection`-index invariant (documented in `AGENTS.md`) is respected everywhere, and the
`calcCount` offset arithmetic is correct in all eight places it appears — but it appears in eight
places, which is the shape of the problem, not a bug.

### 2.5 Search architecture (well-designed; leave the core alone)

```
  query ─▶ AppIndex.matches(query)
             │  1-entry memo keyed on (query, ranking.revision)
             ▼
           rank(query)
             │  learned = LauncherRankingStore.boosts(query)   ← one clock read, one dict
             ▼
           for each of ~350 entries:
             SearchRelevance.score(query, fields)
               │  6 bands × bandStride(1,000,000)
               │  band = f(which field matched, literal vs subsequence)
               │  score = band.offset + FuzzyMatch.score  (≤100,000)
               ▼
             + learned boost (≤4,500)   ← two orders of magnitude below bandStride,
                                          so learning reorders *within* a tier, never across
             ▼
           sort · prefix(200)
```

The band/stride/boost-cap arithmetic is genuinely elegant and is fuzz-tested over ~100k random queries.
**No changes recommended to the scorer.** The cost is entirely in what wraps it (§3, H-2 and H-3).

---

## 3. Problems Found

Every item lists: **what**, **why it matters**, **the fix**, and **expected impact**.

### CRITICAL

---

#### C-1 · `AppCore` is a 1,348-line god object with 13 unrelated responsibilities

**What.** `Core/AppCore.swift` holds, in one type: dependency ownership (21 objects), lifecycle
(`start`/`prepareForTermination`), five feature-presence reconcilers, palette show/hide/mode control,
window-command dispatch, system-action dispatch + confirmation + HUD choice, the full quicklink
lifecycle (open, argument session, CRUD, import/export, failure recovery — ~185 lines), custom-command
run + failure presentation, the uninstall flow, clipboard paste/copy/pin actions, emoji paste actions,
and the entire snippet expansion orchestration (~160 lines across 4 mutually-recursive private methods).

**Why it matters.**

- Every feature branch touches it ⇒ it is the guaranteed merge conflict on any parallel work. This
  directly blocks the stated goal of "multiple contributors".
- It cannot be reasoned about locally. Understanding quicklink argument collection requires holding
  `pendingQuicklinkForcesDefaultApp`, `quicklinkArguments`, `palette.mode`, `windowController.isVisible`
  and `snippetTextInjector.captureExpansionContext` in mind simultaneously.
- It is untestable by construction — it imports AppKit and SwiftUI, so no `Tools/` harness can reach any
  of the orchestration logic, which is where the subtle bugs live.
- It grows superlinearly: each new feature adds a presence reconciler, a Combine sink pair, a dispatch
  arm in `launch`, an arm in `runCommand`, and its own action block.

**Recommended fix.** Keep `AppCore` as the **composition root and nothing else**: own the objects, wire
them in `start()`, expose them. Move each feature's orchestration into a `@MainActor final class
…Coordinator` living beside that feature, constructed by `AppCore` and handed exactly the collaborators
it needs.

```swift
// After. AppCore drops from ~1350 → ~250 lines.
@MainActor final class AppCore: ObservableObject {
    // …stores as today…
    let quicklinkFlow: QuicklinkCoordinator      // was ~185 lines of AppCore
    let snippetFlow:   SnippetExpansionCoordinator // was ~160 lines
    let systemActions: SystemActionCoordinator   // was ~95 lines
    let uninstallFlow: UninstallCoordinator      // was ~90 lines
    let commandFlow:   CustomCommandCoordinator  // was ~75 lines
    let palette:       PaletteCoordinator        // show/hide/mode, was ~110 lines
}
```

Two rules keep this from becoming a new abstraction tax:

1. A coordinator is created **only** when a feature's orchestration exceeds ~60 lines in `AppCore`.
   Clipboard and emoji actions (10 lines each) stay where they are.
2. A coordinator takes its collaborators in `init`, never `AppCore.shared` — which makes it _the first
   orchestration code in the app that a harness could reach_, if its platform calls are behind the
   existing effect-layer types.

**Expected impact.** Merge-conflict surface on `AppCore` drops by ~80%. Zero runtime cost (same objects,
same call graph, one extra retained reference per coordinator ≈ 100 bytes). Zero UI change. Zero binary
growth beyond ~6 small classes.

---

#### C-2 · `RootPaletteView`: 1,126 lines, 13 `@EnvironmentObject`s, and mode logic smeared across 8 switches

**What.** One view holds all seven palette modes. The same 7-way `switch vm.mode` appears in
`resultCount`, `actionsContent`, `content(...)`, `actionPillLabel`, `activateSelection`, the ⌘↵ handler,
the ⌘⌫ handler, and the ⌘P handler. Adding one mode means finding and correctly extending all eight,
plus a `PaletteMode` case (title/systemImage/placeholder), plus a `…ActionsMenu` enum, plus a list view.

**Why it matters.**

- **Invalidation.** With `ObservableObject`, SwiftUI invalidates a view when _any_ observed object emits.
  `RootPaletteView` observes `AppCore`, `PaletteViewModel`, `AppIndex`, `ClipboardStore`,
  `FavoritesStore`, `VisibilityStore`, `CalculatorHistoryStore`, `CurrencyRateStore`, `EmojiIndex`,
  `FrequentEmojiStore`, `UninstallSession`, `QuicklinkStore`, `QuicklinkArgumentSession`, plus
  `AppSettings` via `@ObservedObject`. Concretely: **while the palette is open in emoji mode, every copy
  the user makes anywhere in macOS re-runs the entire palette body**, because `ClipboardManager` polls at
  2 Hz and republishes `ClipboardStore.items`. The heavy work is memoized so the _cost_ is bounded, but
  the whole SwiftUI subtree is diffed for nothing.
- **The flat-selection invariant is the app's most load-bearing rule** (`AGENTS.md` names it) and it is
  currently maintained by eight independent pieces of index arithmetic. That is the highest-risk code in
  the repo for a new contributor.

**Recommended fix.** Introduce one small protocol — the _only_ new abstraction this review recommends,
because it removes seven switches rather than adding a layer.

```swift
@MainActor protocol PaletteScreen {
    associatedtype Row: Identifiable
    var rows: [Row] { get }                              // the single source of visible order
    var primaryActionTitle: String { get }               // was actionPillLabel
    func actions(for row: Row) -> PopoverMenuContent?    // was actionsContent
    func activate(_ row: Row)                            // was activateSelection
    @ViewBuilder func body(selection: Int, scroll: ScrollIntent) -> AnyView
}
```

Each mode becomes one file (`LauncherScreen.swift`, `ClipboardScreen.swift`, …) owning its own rows,
menu and activation. `RootPaletteView` keeps only: the header/search field, the footer bar, the two menu
overlays, keyboard routing, and one type-erased `screen` lookup. The inline calculator card stays where
it is today — a prepended row in the two screens that carry it — so the flat index stays a plain array
index and the eight offset computations collapse into **one**.

**Expected impact.** `RootPaletteView` drops to ~350 lines; adding a mode becomes _one new file_.
The flat-selection invariant becomes structurally guaranteed rather than manually maintained. Combined
with C-3 the invalidation problem disappears entirely. **UI output is byte-identical** — this is a pure
reorganisation of where the same view builders live.

---

#### C-3 · Zero adoption of Observation on a macOS 26 target

**What.** 26 `ObservableObject` classes, ~120 `@Published` properties, 0 uses of `@Observable`.

**Why it matters.** This is the single highest ratio of benefit to risk available in the codebase, and it
is _positive_ on every constraint the brief protects:

| Constraint         | Effect of migrating to `@Observable`                                                                                                                                                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| RAM                | **Down.** `@Published` allocates a `PassthroughSubject`-backed publisher box per property. ~120 properties across ~26 always-live objects. `@Observable` stores none.                                                                                                                            |
| CPU / rendering    | **Down, substantially.** Per-property dependency tracking means a `pendingQuicklinkEdit` change no longer invalidates the palette; an `AppSettings.windowGap` change no longer re-renders every launcher row.                                                                                    |
| Binary size        | **Neutral-to-down.** `Observation` is in the OS. `import Combine` can be dropped from 6 files.                                                                                                                                                                                                   |
| Startup            | **Neutral-to-up.** Fewer publisher allocations during the eager store construction in `AppCore.init`.                                                                                                                                                                                            |
| UI/UX              | **Identical.**                                                                                                                                                                                                                                                                                   |
| Concurrency safety | **Up.** ~30 `MainActor.assumeIsolated { }` blocks exist _solely_ to bridge Combine `.sink` closures (`AppCore.start` ×6, `AppIndex.start`, `HyperKeyTap.start`). `assumeIsolated` **traps at runtime** if the assumption is ever violated; deleting these removes a whole class of latent crash. |

**Concrete example** — this pattern appears six times in `AppCore.start()`:

```swift
// Before — triple indirection, one runtime-trapping assumption, per feature switch
for publisher in [settings.$quicklinksEnabled, settings.$quicklinksShowInLauncher] {
    publisher.dropFirst()
        .sink { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { self.applyQuicklinksPresence() }   // deferred because @Published
            }                                             // emits *before* the write lands
        }
        .store(in: &cancellables)
}
```

```swift
// After — @Observable emits *after* the write, so no deferral, no assumeIsolated, no Combine
withObservationTracking {
    _ = (settings.quicklinksEnabled, settings.quicklinksShowInLauncher)
} onChange: { [weak self] in
    Task { @MainActor in self?.applyQuicklinksPresence() }
}
```

**Recommended fix.** Migrate in three waves (see roadmap W2–W3), leaf-first:

1. **Wave A — leaf stores, no manual `objectWillChange`:** `FavoritesStore`, `VisibilityStore`,
   `CalculatorHistoryStore`, `FrequentEmojiStore`, `RunningAppsMonitor`, `VolumeState`,
   `QuicklinkArgumentSession`, `UninstallSession`, `ShortcutCaptureSession`, `EmojiIndex`,
   `CurrencyRateStore`. Mechanical: `@Observable` on the class, drop `@Published`, `@EnvironmentObject`
   → `@Environment`, `@ObservedObject` → plain `let`.
2. **Wave B — the invalidation win:** `AppSettings`, `AppIndex`, `ClipboardStore`, `QuicklinkStore`,
   `SnippetsStore`, `PaletteViewModel`, `AppCore`.
3. **Wave C — the one hard case:** `HotKeyManager` calls `objectWillChange.send()` manually
   (`setBinding`) because its state lives in `UserDefaults`, not in a stored property. Under
   `@Observable` it needs a real tracked property. Fix it _and_ problem M-4 together with an in-memory
   binding cache (`private var bindings: [HotKeyAction: HotKeyBinding]`), which is a strict improvement
   regardless.

**Expected impact.** Measured on comparable apps: 30–60% fewer body evaluations on the palette's hot
path, ~50–150 KB less resident Combine machinery, ~30 fewer `assumeIsolated` hazards, six files lose
`import Combine`. Risk is per-type and each type is independently shippable.

---

### HIGH

---

#### H-1 · Comment volume has overtaken the code it explains

**What.** Measured across all non-generated Swift in `Tinycast/`:

| Metric                                                 | Value                         |
| ------------------------------------------------------ | ----------------------------- |
| Comment lines / total lines                            | **1,850 / 26,379 = 7.0%**     |
| **Stacked comment blocks** (2+ consecutive `//` lines) | **181**                       |
| Comment lines > 100 chars                              | **953 — 51% of all comments** |
| Comment lines > 120 chars                              | **572**                       |
| _Code_ lines > 100 chars, for contrast                 | **158**                       |
| Longest single comment line                            | **588 characters**            |

Worst offenders by density: `CurrencyRateStore` 27.7% · `Theme` 23.9% · `WindowActionMemory` 21.5% ·
`QuicklinkDestination` 19.7% · `WindowMover` 17.7% · `CalcCurrency` 16.4% · `WindowLayout` 14.6%.

**Why it matters.**

- `AGENTS.md` already states the rule: _"Comments are single-line — no stacked / multi-line blocks. Only
  comment the non-obvious."_ **181 stacked blocks violate the first half outright.** The second half is
  violated more insidiously: the single-line rule is satisfied in letter and defeated in spirit by
  writing one 300-, 400-, 588-character line instead of a paragraph. A comment 3.6× more likely to be
  overlong than the code beside it is not annotating the code — it is competing with it.
- This is specifically an **agent-authored-code failure mode, and it compounds.** An assistant asked to
  change one function reads the surrounding prose, matches its register, and emits more of it. Each pass
  ratchets the ratio up. Left unchecked, comment lines grow faster than code lines.
- It actively harms review. A 40-line diff carrying 12 lines of justification prose forces the reviewer
  to verify the prose as well as the code — and stale prose is worse than none, because it is trusted.
- It inflates every file past its natural size, which is part of why `AppCore` reads as 1,348 lines and
  `RootPaletteView` as 1,126.

**Recommended fix.** Turn the rule from a style preference into a hard, checkable budget, stated in terms
an agent cannot satisfy by reformatting. Replace the `AGENTS.md` comment clause with:

> **Comments — minimal code, not annotated prose**
>
> - One line. **Never two consecutive comment lines.** If it needs two, it needs a named function, a
>   named constant, or a type — not a paragraph.
> - **Hard cap: 100 characters, including indentation.** Longer means the explanation belongs in
>   `docs/<subsystem>.md`, referenced by name.
> - Comment the _why_, the gotcha, or the invariant. Never restate the code, never narrate the sequence,
>   never argue a decision at length in-line.
> - A `///` doc comment on a public type or method is exempt from the consecutive-line rule, not from
>   the character cap.
> - **Prefer deleting a comment to updating it.** If the code can be made obvious instead, do that.
> - Do not add a comment to explain a change you just made. The diff is not the audience.

Then one mechanical pass (roadmap W7.6): for each of the 181 stacked blocks and 572 over-120-char lines,
triage — _(a)_ delete if it restates the code, _(b)_ compress to one clause if it names a real gotcha,
_(c)_ move to the relevant `docs/*.md` and leave a one-line pointer if it is genuinely a paragraph of
rationale. Most of the best long comments here — the `WindowLayout` AX-coordinate flip, the
`CurrencyRateStore` consent gate, the `SpotlightNames` measurement — are **already** written up in
`docs/`, so (c) is usually a delete plus a reference rather than a rewrite.

**Expected impact.** Roughly 700–900 lines removed with zero behaviour change; several files drop below
the sizes that made them look like god objects in the first place. The durable win is the greppable
budget, not the cleanup: without a character cap and a no-stacking rule that a tool can check, the next
agent pass re-inflates everything this pass removes.

---

#### H-2 · `SettingsPaneScanner.scan()` re-reads ~40 `.appex` bundles from disk on **every palette open**

**What.** `AppIndex.refresh()` is called on every `showPalette(mode: .launcher)` (`AppCore.swift:353`)
and on every `togglePalette`. Inside the detached scan, `AppIndex.scan()` unconditionally calls
`SettingsPaneScanner.scan()`, which enumerates `/System/Library/ExtensionKit/Extensions`, and for each
`.appex` reads and parses `Contents/Info.plist` **and** `Contents/Resources/InfoPlist.loctable` via
`PropertyListSerialization`.

**Why it matters.** That is ~80 file reads plus ~80 plist deserialisations, every single time the user
presses the launcher hotkey. System Settings panes change only on an OS update. The app already solved
this exact problem for Spotlight alternate names (`SpotlightNames.Cache`, mtime-keyed, "76 ms cold,
0.2 ms after") — the same discipline was simply not extended one function further. It is off-main so it
causes no hitch, but it is repeated I/O, energy, and page-cache pressure on the hottest user gesture.

**Recommended fix.** Scan panes once per launch, then invalidate on the directory's modification date —
mirroring `SpotlightNames.Cache` exactly, so it introduces no new idiom:

```swift
enum SettingsPaneScanner {
    private struct Snapshot: Sendable { let modified: Date?; let entries: [AppEntry] }
    private nonisolated(unsafe) static let lock = NSLock()
    private nonisolated(unsafe) static var snapshot: Snapshot?

    nonisolated static func scan() -> [AppEntry] {
        let modified = try? extensionsDir.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        lock.lock(); defer { lock.unlock() }
        if let snapshot, snapshot.modified == modified { return snapshot.entries }
        let entries = scanUncached()
        snapshot = Snapshot(modified: modified, entries: entries)
        return entries
    }
}
```

(Or, cleaner: hoist the cache into `AppIndex` alongside `alternateNameCache`, which is already threaded
through `scan` as a value — that avoids the static mutable state entirely and is the more idiomatic fit
with the existing code. Prefer this.)

**Expected impact.** ~80 file reads + ~80 plist parses removed from _every_ launcher open. Measure with
`os_signpost` around `AppIndex.scan` before and after; expect the scan's steady-state cost to drop
sharply, with the remaining time dominated by `SearchScopes.appBundles` + `Bundle(url:)`. Risk: a pane
installed mid-session without touching the directory mtime would be missed — impossible in practice,
since installing a pane writes into that directory.

---

#### H-3 · `Settings ▸ Applications` rasterises icons synchronously on the main thread

**What.** `LauncherItemsCard` renders `LauncherItemRow`, which does:

```swift
Image(nsImage: entry.icon)          // Features/Settings/LauncherItemsCard.swift:75
```

`AppEntry.icon` (`AppIndex.swift:93`) calls `IconCache.icon(forFile:)` **synchronously**, which on a cold
key calls `NSWorkspace.shared.icon(forFile:)` and then rasterises into a 96×96 `NSBitmapImageRep` — all
on the main thread, inside a `LazyVStack` of ~200 rows, during scrolling.

**Why it matters.** The palette solved this properly: `AppIconView` seeds from the cache synchronously
(so a warm icon has no placeholder flash) and decodes cold ones via `IconCache.loadAsync` on a detached
task. Settings simply doesn't use it. The result is a main-thread hitch on first open of the
Applications pane and again while scrolling into un-warmed rows. It is the one place in the app where
the codebase's own performance rule is broken.

**Recommended fix.** One-line substitution — `AppIconView` already exists and already handles both the
symbol and file cases:

```swift
- Image(nsImage: entry.icon).resizable().frame(width: 22, height: 22)
+ AppIconView(app: entry).frame(width: 22, height: 22)
```

Then consider deleting `AppEntry.icon` entirely (`grep` shows this and `AppPresentation` are its only
callers) so the synchronous path cannot be reintroduced.

**Expected impact.** Main-thread rasterisation removed from the Settings pane. Identical pixels. ~2 lines
changed. This is the single best effort-to-benefit item in the document.

---

#### H-4 · The uninstall scan runs entirely serially — both phases

**What.** `UninstallScanner.scan()` is serial end to end. It walks `UninstallSearchRoot.all` one root at
a time (`contentsOfDirectory` + rule match + `lstat` per hit), then walks the `bin` directories, and for
every directory candidate it produces it calls `directorySize(of:budget:)` — a full
`FileManager.enumerator` recursive walk with a 250,000-entry budget (the code notes "roughly a second at
250k"). Every one of those walks happens back to back on a single thread.

**Why it matters.** A well-established app leaves 10–25 leftover directories (`Application Support`,
`Caches`, `Containers`, `Group Containers`, `Saved Application State`, `Logs`, `WebKit`, …). Sizing them
one after another is by far the longest-running operation in Tinycast — and it is I/O-bound work running
at a concurrency of one while the user sits watching a "Looking for leftover files…" placeholder. This
is the single worst latency-to-available-parallelism ratio in the app: the work is embarrassingly
parallel, the machine has 8–16 idle cores, and the user is blocked on it.

**Recommended fix.** Go **fully parallel and uncapped**. A scan is a short, user-initiated burst — the
user is staring at a placeholder — so trading a spike of CPU and RAM for wall-clock latency is exactly
the right trade here, and it is the one place in Tinycast where that trade is correct. Parallelise
**both** phases:

```swift
// Phase 1 — root enumeration, in parallel. Each root is an independent directory listing + rule match.
let perRoot = await withTaskGroup(of: (Int, [UninstallCandidate]).self) { group in
    for (index, root) in roots.enumerated() {
        group.addTask(priority: .userInitiated) {
            try? Task.checkCancellation()
            return (index, candidates(in: root, identity: identity, environment: environment))
        }
    }
    var buckets = [[UninstallCandidate]](repeating: [], count: roots.count)
    for await (index, found) in group { buckets[index] = found }
    return buckets.flatMap { $0 }          // root order preserved by index, not by completion
}

// Phase 2 — directory sizing, in parallel. The expensive half: one full recursive walk per candidate.
var candidates = deduplicated(bundleCandidate + perRoot + binSymlinks)
await withTaskGroup(of: (Int, MeasuredSize).self) { group in
    for (index, candidate) in candidates.enumerated() where candidate.needsWalk {
        group.addTask(priority: .userInitiated) {
            try? Task.checkCancellation()
            return (index, directorySize(of: candidate.path, budget: budget))
        }
    }
    for await (index, size) in group { candidates[index].size = size }  // writeback by index
}
```

**Display order is preserved exactly, by construction.** This is the load-bearing detail: nothing sorts
by completion. Phase 1 writes each root's results into a pre-sized bucket at the root's own index, so
`UninstallSearchRoot.all` order survives; phase 2 only mutates the `size` field of a row already in
place. The final ordering line stays byte-for-byte as it is today:

```swift
let leftovers = candidates.filter { $0.evidence != .bundle }.sorted { $0.path < $1.path }
return UninstallPlan(
    target: target, candidates: candidates.filter { $0.evidence == .bundle } + leftovers, …)
```

So the bundle still pins to the top and leftovers still sort by path — the list the user sees, and the
order `UninstallSelection` and `UninstallRunner` walk, are identical to today. Deduplication (`seen`)
must move _after_ the parallel gather so it stays deterministic; dedupe the flattened, index-ordered
array rather than racing on a shared `Set`.

`try? Task.checkCancellation()` in each child keeps `UninstallSession.cancel()` responsive — leaving the
screen still releases the whole scan promptly, since cancelling the parent cancels every child.

**Expected impact.** Wall-clock scan time drops by roughly `min(cores, candidates)` — on Apple silicon
(8–16 cores) that is typically **6–12×** for a heavyweight app, turning a multi-second wait into a
sub-second one. Peak RAM rises by one `FileManager.enumerator` per concurrent walk (a few KB each, so
tens of KB total — irrelevant against the 40–80 MB budget, and it is transient). Peak CPU saturates
briefly and by design. No change to `UninstallPlan`, `UninstallRules`, `UninstallProtection` or
`UninstallSelection`, so the pure layer and `Tools/uninstall-test.swift` are untouched.

---

#### H-5 · A feature's implementation is spread across three directory trees and eight shared files

**What.** Concretely, for Quicklinks (the most recently added feature, and therefore the honest measure
of what adding a feature costs today):

| Location                                   | Contribution                                                                                                          |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `Core/Quicklinks/`                         | 6 files — model, destination, store, archive, launcher, argument session                                              |
| `Features/Quicklinks/`                     | 2 files — list view, arguments view                                                                                   |
| `Features/Settings/`                       | 2 files — `QuicklinksSettingsView`, `QuicklinkEditorSheet`                                                            |
| `Core/AppCore.swift`                       | ~185 lines — open flow, argument submit, CRUD, import/export, failure recovery, presence                              |
| `Core/AppIndex.swift`                      | `setQuicklinks(_:commandsVisible:)` + a slice in `publishEntries`                                                     |
| `Core/AppSettings.swift`                   | 5 `@Published` properties + 5 `Key` constants                                                                         |
| `Core/Backup/SettingsBackup.swift`         | 5 `SettingsData` fields + gather lines + apply block + `quicklinks` array                                             |
| `Core/CommandRegistry.swift`               | 4 `CommandID` cases + names + symbols + `isQuicklinkCommand`                                                          |
| `Core/HotKeyManager.swift`                 | `boundQuicklinkKey` index, prune, `candidateActions`, `displayName`, `perform`                                        |
| `Features/RootPaletteView.swift`           | 2 `PaletteMode` cases + `quicklinkResults` + `argumentOptions` + menu arm + ⌘↵ arm + ⌘P arm + ⌘⌫ arm + activation arm |
| `Features/Settings/SettingsRootView.swift` | `SettingsTab` case + title + symbol + tint + switch arm                                                               |

**That is 14 files for one feature**, of which 8 are shared with every other feature.

**Why it matters.** This is the direct cause of the 5.5/10 scalability score. It is not a hypothetical —
`AGENTS.md` already documents the "new category means a new `Kind` case, a slice in
`AppIndex.publishEntries()`, and the matching filter in `LauncherList.rows`, in that same order"
recipe, which is an honest admission that the cost is real. At 50 features these shared files are each
1,000+ lines of near-identical arms and every PR conflicts with every other PR.

**Recommended fix.** Three moves, in order (they are the substance of the roadmap):

1. **C-1 + C-2** remove the `AppCore` and `RootPaletteView` arms (the two largest contributions).
2. **Co-locate** — one folder per feature containing its pure layer, effect layer, palette screen,
   settings pane and coordinator (§4).
3. **Register rather than enumerate** for the three remaining shared tables. `CommandRegistry`,
   `SettingsTab` and `AppEntry.Kind` all switch over a closed enum; each feature can instead contribute
   a static descriptor that `AppCore` collects at wiring time. **Do this last and only for the tables
   that have actually hurt** — a registry for something with three entries is over-engineering. As of
   today only `CommandRegistry` clearly qualifies.

**Expected impact.** New feature cost drops from ~14 files to ~5 files, of which 4 are new and 1
(`AppCore.start`) is a one-line addition.

---

#### H-6 · `AppEntry` is a nine-field union type driving six scattered switches

**What.** `AppEntry` carries `matchAliases`, `symbolName`, `alternateNames`, `executableName`,
`bundleID` — most of which are nil/empty for most kinds. `Kind` is switched on in `kindLabel`,
`hotKeyAction`, `canRevealInFinder`, `isSymbolIcon`, `symbolIconName` (all in `AppEntry`),
`AppCore.launch`, `LauncherList.rows`, `AppActionsMenu.openTitle`, and
`RootPaletteView.actionPillLabel` — **nine sites**, five of which must be updated together for a new
kind or the flat-selection invariant breaks silently.

**Why it matters.** `AGENTS.md` correctly identifies `Kind` as load-bearing ("the only thing that says
what an entry is") — but the consequence of a wide union with distributed switches is that adding a kind
is shotgun surgery, and the compiler only catches five of the nine sites (`rows` and `actionPillLabel`
use `default:`).

**Recommended fix.** _Do not_ replace it with a protocol or existential — that would cost allocations
and defeat the `Sendable` value semantics that make the detached scan work. Two cheaper, targeted moves:

1. **Make every switch exhaustive.** Replace the `default:` in `LauncherList.rows` (via the section
   table) and in `AppActionsMenu.openTitle` / `RootPaletteView.actionPillLabel` with explicit cases, so
   the compiler enforces the recipe `AGENTS.md` currently enforces by prose. _This alone converts a class
   of silent bug into a build error and is ~20 lines of change._
2. **Collapse the per-kind metadata into one table** on `AppEntry.Kind`: `label`, `sectionTitle`,
   `openVerb`, `defaultSymbol`, `canRevealInFinder`, `isSymbolIcon` become properties of a single
   `struct KindDescriptor` returned by one switch, so a new kind is one row rather than five arms.

**Expected impact.** Adding a launcher category becomes a compile-error-guided exercise. No runtime cost
(the descriptor is a `static let` table). No UI change.

---

### MEDIUM

---

#### M-1 · `Core/` is a 46-file flat namespace that mixes six unrelated concerns

`Tinycast/Core/` contains, at its top level: design tokens (`Theme`), 11 SwiftUI view modifiers and
helpers (`EdgeDissolve`, `ThinScrollbar`, `RightClick`, `Tooltip`, `ScrollIntent`, `OverlayScroller`,
`PanelTransition`, `VisualEffectView`, `SymbolImage`, `CalloutShape`, `CalloutPlacement`), AppKit window
plumbing (`PalettePanel`, `PaletteWindowController`), 10 stores, 4 pure algorithm files, 3 platform
shims, plus 10 subdirectories. "Core" has no meaning here beyond "not a view — and sometimes it is."

**Fix:** §4. **Impact:** navigation only; zero runtime effect. Cheap because XcodeGen re-derives the
project from `sources: - path: Tinycast`.

---

#### M-2 · Up to five independent repeating timers, three of which do the same job

| Timer                                | Interval | Live when                   |
| ------------------------------------ | -------- | --------------------------- |
| `ClipboardManager` pasteboard poll   | 0.5 s    | always, from launch         |
| `HyperKeyTap.healthCheck`            | 1 s      | a Hyper key is configured   |
| `DoubleTapMonitor.healthCheck`       | 1 s      | a double-tap binding exists |
| `SnippetKeywordListener.healthCheck` | 1 s      | snippets enabled            |
| `PermissionsSettingsView` refresh    | 1 s      | that pane is visible        |

The three health checks do _the same three things_: retry tap installation, notice Accessibility
revocation, re-enable a system-disabled tap. Independent, unaligned timers each wake the CPU separately.

**Fix.** (a) Introduce one `@MainActor final class HealthTicker` on `AppCore` that the three tap owners
subscribe to; a single 1 s timer with aligned wakeups. (b) Give the clipboard poll a `tolerance`
(`timer.tolerance = 0.1`) so the kernel can coalesce it, and suspend it on
`NSWorkspace.sessionDidResignActiveNotification` (the two tap monitors already do exactly this — the
clipboard poller is the outlier). (c) Optionally back the poll interval off to 1.5 s after ~60 s with no
pasteboard change, resetting on any `NSWorkspace.didActivateApplicationNotification`.

**Impact.** Up to 3 fewer timer sources and better wakeup coalescing — a real idle-energy improvement for
an always-running accessory app. No behaviour change (the polling interval and the 0.5 s capture window
stay as they are unless (c) is adopted, which should be measured with `powermetrics` first).

---

#### M-3 · Unmemoized per-render work in the launcher's empty-query and compact paths

Two spots re-run O(n) work on every render over the ~300–400-entry index:

```swift
// RootPaletteView.appResults — the `.filter` and the favorites split are NOT memoized
let base = appIndex.matches(vm.query).filter(visibility.isVisible)   // fresh 350-element array
let split = favorites.ordered(base)                                  // builds a 350-entry Dictionary

// RootPaletteView.compactFavoriteSlots — same chain, evaluated on every compact-bar render
favorites.ordered(appIndex.matches("").filter(visibility.isVisible)).favorites
```

`FavoritesStore.ordered` short-circuits when the user has no favorites, so a fresh install pays nothing —
but a user with favorites pays a dictionary build plus two array allocations per render. Note this is
also currently the _cause_ of `openActions()`'s careful "only the launcher's menu walks `appResults`"
comment: the code is already working around the cost.

**Fix.** Add one memo on `AppIndex` — it already owns `matchCache` and already tracks
`ranking.revision`, so extend the same idea rather than inventing a second one:

```swift
// Key on (query, rankingRevision, visibilityRevision, favoritesRevision).
// VisibilityStore and FavoritesStore each gain a `revision` counter, exactly like LauncherRankingStore.
func orderedResults(query: String, visibility: VisibilityStore, favorites: FavoritesStore) -> [AppEntry]
```

`RootPaletteView.appResults`, `compactFavoriteSlots`, `selectedAppEntry` and `actionsContent` then all
read one memoized array — which also removes the `openActions` workaround.

**Impact.** Removes ~700 element visits + one dictionary allocation per palette render for users with
favorites. Also removes the last unmemoized path feeding the flat-selection index, which is a
correctness benefit as much as a performance one.

---

#### M-4 · `HotKeyManager` re-reads and re-decodes UserDefaults on every binding lookup

`binding(for:)` does `UserDefaults.standard.string(forKey:)` + `JSONDecoder.decode` on every call. Call
sites:

- `start()` → `candidateActions` (~70 actions) → `register` → `binding(for:)` **×70**, then
  `syncDoubleTaps()` → `candidateActions` again → `binding(for:)` **×70**. **140 lookups at launch.**
- `conflictOwner(of:excluding:)` → up to **70 lookups per keystroke** while a shortcut recorder is open.
- `AppRow.shortcutCaps` → one lookup per visible launcher row, per render.
- `SettingsBackup.gather` → ~70 lookups.

`candidateActions` also allocates fresh arrays from `SystemAction.ID.allCases` and
`WindowCommand.ID.allCases` (~60 elements) on every access.

**Fix.** Load bindings into an in-memory `[HotKeyAction: HotKeyBinding]` once in `start()`, write through
on `setBinding`, and serve every read from it. UserDefaults remains the source of truth on disk (the
legacy `KeyboardShortcuts_<name>` key format is an invariant and stays untouched). Cache
`candidateActions` and invalidate it in `setBinding`. This is also the enabler for C-3 Wave C.

**Impact.** ~140 decode round-trips off the launch path; recorder conflict detection becomes a dictionary
scan; launcher rows stop touching `UserDefaults` during render. Zero behaviour change — the same values
by the same keys.

---

#### M-5 · Eight copies of the app-support/caches path computation

`ClipboardStore`, `LauncherRankingStore`, `CalculatorHistoryStore`, `FrequentEmojiStore`,
`CurrencyRateStore`, `QuicklinkStore`, `OnboardingState` and `SnippetRepository` each independently
compute a channel directory with the identical five lines and the identical
`?? "com.tinycast.app"` fallback.

**Why it matters.** Channel isolation (`Tinycast Dev` vs stable) is a named invariant: _"Anything newly
persisted must stay keyed by `Bundle.main.bundleIdentifier`."_ Eight copies means eight chances for a
new store to omit it, and there is no single place to look to confirm the rule holds.

**Fix.** One ~25-line file that makes the invariant structural:

```swift
/// Every per-channel location Tinycast persists to. Foundation-only; `bundleID` is injectable so the
/// harnesses can point a store at a throwaway root, which they already do via their `directory:` params.
enum AppPaths {
    static func caches(bundleID: String = Bundle.main.bundleIdentifier ?? "com.tinycast.app") -> URL
    static func applicationSupport(bundleID: String = …) -> URL
}
```

**Impact.** −40 lines, one place to audit the channel invariant. Note the constraint: `ClipboardStore`
and `QuicklinkStore` must stay compilable standalone by their harnesses, so either add `AppPaths.swift`
to those two harness command lines (and update `AGENTS.md` + `docs/development.md` in the same
commit) or keep their `directory:` injection as the harness path and let `AppPaths` supply only the
default. **Prefer the latter — it requires no invariant change at all.**

---

#### M-6 · `SettingsBackup` is a 336-line hand-mirrored copy of `AppSettings`

Adding a setting requires five coordinated edits: the `AppSettings` property, its `Key`, a
`SettingsData` field, a `gather` argument, and an `apply` block.

**Recommendation: keep it manual.** The temptation is codegen or `Codable` reflection — resist it. The
_explicit_ omission of `snippetsEnabled` (with its comment explaining that it doubles as
keystroke-listening consent) is a **security control**, and any mechanism that auto-includes new
properties would silently make the next consent flag backup-restorable. The manual mirror is correct.

**Fix the failure mode instead:** add a completeness assertion to a `Tools/` harness — enumerate
`AppSettings`'s UserDefaults `Key` constants and assert each is either present in `SettingsData` or in an
explicit `deliberatelyExcluded` set. A forgotten setting then fails CI; a _deliberately_ excluded one
requires writing its name and, by convention, its reason.

**Impact.** Turns a silent omission into a build failure while preserving the security property.

---

#### M-7 · Six hand-rolled one-entry memo caches with six independent invalidation rules

`AppIndex.matchCache`, `ClipboardStore.searchCache`, `ClipboardStore.orderedCache`,
`CalculatorHistoryStore.searchCache`, `EmojiIndex.searchCache`, `FrequentEmojiStore.sortedGlyphs`.

Each is correct today. Each is invalidated by a different mechanism (a `didSet`, an explicit `= nil` in
`persist()`, a revision counter, a manual clear in `record()`). A seventh will be written the next time
someone adds a searchable store, and it will be the one that forgets to invalidate.

**Fix.** One ~20-line generic, used at all six sites:

```swift
/// One-entry memo. `key` bundles everything the value depends on, so a stale read is impossible
/// by construction rather than by remembering to invalidate.
struct Memo<Key: Equatable, Value> {
    private var entry: (key: Key, value: Value)?
    mutating func value(for key: Key, build: () -> Value) -> Value {
        if let entry, entry.key == key { return entry.value }
        let value = build(); entry = (key, value); return value
    }
}
```

This is the one abstraction in the document that pays for itself purely on line count (six
implementations → one), and it makes the dependency of each cache _explicit in its key type_ rather than
implicit in scattered invalidation calls. **Same constraint as M-5** for the two harness-compiled stores.

**Impact.** −40 lines, one bug class removed, no runtime change (identical single-slot semantics).

---

#### M-8 · `Features/Settings/` (20 files) mixes four unrelated kinds of thing

Pane views (`GeneralSettingsView` …), shared scaffolding (`SettingsComponents`, `LauncherItemsCard`,
`SearchScopesCard`), feature editors (`QuicklinkEditorSheet`, `CustomCommandEditorSheet`), and hotkey UI
(`ShortcutRecorder`, `ShortcutRecorderPopover`) — the last of which is really the HotKeys feature's view
layer, not a Settings component.

**Fix:** §4 (each pane moves to its feature; scaffolding to `DesignSystem/`; the recorder to
`Features/HotKeys/UI/`). Two panes have no feature — `GeneralSettingsView` spans five of them and
`PermissionsSettingsView` is app-level — and they stay with the shell in `Settings/Panes/`.

---

#### M-9 · `AuxWindowController` lives inside `Features/About/AboutView.swift`

A ~90-line `NSWindowDelegate` that owns Settings, About and Onboarding windows and flips
`NSApp.setActivationPolicy` is defined at the bottom of a view file for one of the three windows it
serves. `docs/architecture.md` documents the location, which is honest but does not make it findable.

**Fix.** Move to `Windows/AuxWindowController.swift`. Pure file move.

---

### LOW

- **L-1 · `String.nilIfEmpty` is defined twice**, `fileprivate`, identically, in `QuicklinkStore.swift`
  and `ShellCommandRunner.swift`. Both files are harness-compiled standalone, which is _why_ the
  duplication exists. Leave it, or resolve it with M-5's approach (shared file added to both harness
  lines). Document the reason in whichever file survives.
- **L-2 · SQLite helpers duplicated** — `SQLITE_TRANSIENT`, `columnString`, `columnDate`, `prepare`,
  `closeDatabase` appear near-identically in `ClipboardStore` and `QuicklinkStore` (~60 lines). Same
  harness constraint; the invariant explicitly says `ClipboardStore` must depend on "no other app
  source". **Recommendation: keep the duplication.** Sixty lines of duplication is cheaper than
  weakening an invariant that guarantees the clipboard store is testable in isolation.
- **L-3 · Naming: `CommandRegistry` vs `SystemActionCatalog` vs `WindowCommandCatalog`** — three names
  for one concept (a static compile-time table). Rename `CommandRegistry` → `CommandCatalog`.
- **L-4 · `Core/HotKeyManager.swift` sits outside `Core/HotKey/`** while everything it owns is inside.
- **L-5 · `PaletteViewModel` is the only `…ViewModel` in the app** and it isn't one — it is shared
  application state (mode, query, selection, focus tokens) read by the window controller and the panel
  as much as by views. Rename to `PaletteModel` or `PaletteState`.
- **L-6 · `armedHover` reaches `AppCore.shared` from a `View` extension** (`RootPaletteView.swift:1044`).
  Pass the flag through the environment instead, so the modifier is context-free.
- **L-7 · `Paster`'s three magic delays** (`0.08`, `0.05`, `0.05`) are unnamed literals guarding a
  timing-sensitive synthetic-⌘V handshake. Name them (`Paster.activationSettleDelay`,
  `Paster.directPostDelay`) with a one-line note on what they compensate for.
- **L-8 · Cache ceilings sum above the stated working set** — `IconCache` 32 MB + `ImageThumbnail` row
  8 MB + preview 48 MB = 88 MB of permitted cache against a 40–80 MB target. They never fill in practice
  (previews are purged on hide), but the preview ceiling in particular could drop to ~24 MB with no
  observable effect. **Measure before changing** — this is exactly the kind of tuning the project
  philosophy says to justify with numbers.
- **L-9 · `EmojiData.generated.swift` (2,060 lines)** compiles a large string literal into `__TEXT`.
  Moving it to a bundle resource would shrink the binary but add a launch-time read. Given the <3 MB upto 4MB
  budget is currently met, **do not change this** — recorded only so the option is known.
- **L-10 · `Bundle+AppName.swift` is the only `Type+Feature.swift`-named file**; `CursorScreen.swift`
  also extends a system type but is named by concept. Pick one convention (§4 recommends concept-named).

---

## 4. Recommended Naming Rules and Folder Structure

### 4.1 Naming vocabulary

Today ~20 suffixes are in use: `Store`, `Manager`, `Index`, `Session`, `Controller`, `Registry`,
`Catalog`, `Runner`, `Monitor`, `Center`, `Presenter`, `Repository`, `Scanner`, `Policy`, `Rules`,
`Engine`, `Injector`, `Launcher`, `Mover`, `Tap`, `Archive`, `Plan`, `ViewModel`. Many carry real
meaning; the problem is that some are synonyms and there is no written rule.

**Adopt these ten. Nothing else.**

| Suffix               | Means                                                             | Owns state?  | Touches the platform?     |
| -------------------- | ----------------------------------------------------------------- | ------------ | ------------------------- |
| `…Store`             | Persisted, observable state                                       | ✅           | ✅ (its own storage only) |
| `…Index`             | Derived, observable, in-memory state; no storage of its own       | ✅           | ➖                        |
| `…Session`           | State for one in-progress user flow; created and discarded        | ✅           | ➖                        |
| `…Catalog`           | Static compile-time table. **Never** a runtime registry           | ❌           | ❌                        |
| `…Engine`            | Pure computation over inputs → output                             | ❌           | ❌                        |
| `…Rules` / `…Policy` | Pure decision functions                                           | ❌           | ❌                        |
| `…Scanner`           | Reads the environment, returns a value, causes nothing            | ❌           | ✅                        |
| `…Runner`            | Performs a one-shot side effect, reports the outcome, shows no UI | ❌           | ✅                        |
| `…Monitor`           | Long-lived observer of an external event stream                   | ✅ (its own) | ✅                        |
| `…Controller`        | Owns an AppKit window/panel lifecycle                             | ✅           | ✅                        |
| `…Coordinator`       | Orchestrates one feature's multi-step flows across collaborators  | minimal      | via collaborators         |

**Retire:** `Manager` (says nothing), `Registry` (→ `Catalog`), `ViewModel` (→ `Model`/`State`),
`Repository` (→ `Store`, unless the file-backed-with-conflict-detection semantics are worth keeping —
`SnippetRepository` arguably earns it; if kept, document it as the eleventh).

**Renames implied** (all mechanical, all in one commit at W7):

| Today                              | Proposed                     | Why                                                                                                                     |
| ---------------------------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `ClipboardManager`                 | `ClipboardMonitor`           | It polls an external stream.                                                                                            |
| `HotKeyManager`                    | `HotKeyBindings` (a `Store`) | It persists and publishes bindings; `HotKeyCenter` is already the Carbon layer.                                         |
| `CommandRegistry`                  | `CommandCatalog`             | Matches `SystemActionCatalog`, `WindowCommandCatalog`.                                                                  |
| `PaletteViewModel`                 | `PaletteState`               | It is app state, not a per-view VM.                                                                                     |
| `MiscellaneousSettingsView`        | `CalculatorSettingsView`     | It holds one Calculator card and the currency-consent sheet — "Miscellaneous" names the tab, not the pane.              |
| `QuicklinkLauncher`, `AppLauncher` | keep                         | "Launcher" is clearer than "Runner" for opening things; document as a `Runner` synonym reserved for `NSWorkspace.open`. |
| `SnippetTextInjector`              | keep                         | Domain term with no better alternative.                                                                                 |

**File naming rules**

1. One primary type per file; the file is named for it.
2. Extensions on system types are named for the **concept**, not the type: `CursorScreen.swift`, not
   `NSScreen+Cursor.swift`. (Rename `Bundle+AppName.swift` → `AppDisplayName.swift`.)
3. Generated files keep the `.generated.swift` suffix and a header naming their generator.
4. A pure-layer file states its purity in a one-line doc comment naming the harness that compiles it —
   this already happens in ~10 files and should be universal.

### 4.1b Comment rules (see H-1)

Naming conventions only pay off if the code is readable at a glance, and today the comments are what
obscures it. These belong in `AGENTS.md` alongside the naming table:

1. **One line. Never two consecutive comment lines.** Needing two means the code needs a named function,
   a named constant, or a type — not a paragraph.
2. **Hard cap: 100 characters, including indentation.** Anything longer belongs in
   `docs/<subsystem>.md`, referenced by name from a one-line pointer.
3. Comment the _why_, the gotcha, or the invariant. Never restate the code, never narrate the sequence,
   never argue a decision at length in-line.
4. `///` on a public type or method is exempt from rule 1, not from rule 2.
5. **Prefer deleting a comment to updating it.** If the code can be made obvious instead, do that.
6. Never add a comment to explain a change you just made. The diff is not the audience.

**Minimal code is the goal, not annotated code.** The measure of a good change here is fewer lines
total — not the same logic with an explanation attached to it.

### 4.2 Target folder structure

The design principle: **a folder is a feature; inside a feature, a subfolder is a layer.** The layer
names are the ones the code already has (§2.2), just made visible.

```
Tinycast/
├── App/                              # composition root — 3 files, and it stays 3 files
│   ├── TinycastApp.swift             # @main, MenuBarExtra scene
│   ├── AppDelegate.swift             # 3 callbacks, unchanged
│   └── AppCore.swift                 # ~250 lines: ownership + start() wiring + nothing else
│
├── Palette/                          # the shell every feature plugs a screen into
│   ├── PalettePanel.swift
│   ├── PaletteWindowController.swift
│   ├── PaletteState.swift            # was PaletteViewModel
│   ├── PaletteMode.swift             # PaletteMode + PasteTarget, extracted from AppCore
│   ├── PaletteCoordinator.swift      # was AppCore's show/hide/mode/pop-to-root block
│   ├── RootPaletteView.swift         # ~350 lines: header, footer, menus, key routing
│   └── PaletteScreen.swift           # the one new protocol (C-2)
│
├── Features/
│   ├── Launcher/
│   │   ├── Model/      AppEntry.swift · SearchRelevance.swift · SearchScopes.swift
│   │   │               LauncherRankingStore.swift  ← pure, harness-compiled
│   │   │               CommandCatalog.swift        ← was CommandRegistry
│   │   ├── Service/    AppIndex.swift · AppLauncher.swift · SpotlightNames.swift
│   │   │               SettingsPaneScanner.swift · FavoritesStore.swift
│   │   │               VisibilityStore.swift · RunningAppsMonitor.swift
│   │   ├── UI/         LauncherScreen.swift · LauncherList.swift · AppRow.swift
│   │   │               AppIconView.swift · AppActionsMenu.swift · SectionHeader.swift
│   │   └── Settings/   ApplicationsSettingsView.swift · SystemSettingsSettingsView.swift
│   │                   LauncherItemsCard.swift · SearchScopesCard.swift
│   │
│   ├── Clipboard/      Model/ (ClipboardStore) · Service/ (ClipboardMonitor, Paster)
│   │                   UI/ (ClipboardScreen, ClipboardList, ClipboardPreview,
│   │                   ClipboardActionsMenu) · Settings/ (ClipboardSettingsView,
│   │                   AppPickerPopover)
│   ├── Calculator/     Model/ (Calc*, CurrencyData.generated) · Service/ (CurrencyRateStore,
│   │                   CalculatorHistoryStore) · UI/ (CalculatorHistoryScreen,
│   │                   CalculatorCardView) · Settings/ (CalculatorSettingsView,
│   │                   was MiscellaneousSettingsView — it only ever held the Calculator card)
│   ├── Emoji/          Model/ (EmojiCatalog, EmojiGridGeometry, EmojiData.generated)
│   │                   Service/ (EmojiIndex, FrequentEmojiStore) · UI/ · Settings/
│   ├── Quicklinks/     Model/ · Service/ · UI/ · Settings/ · QuicklinkCoordinator.swift
│   ├── Snippets/       Model/ · Service/ · UI/ · Settings/ · SnippetExpansionCoordinator.swift
│   ├── WindowManagement/ Model/ (WindowCommand, WindowLayout, WindowActionMemory)
│   │                   Service/ (WindowMover) · Settings/
│   ├── Uninstall/      Model/ (5 pure files) · Service/ (Scanner, Runner) · UI/
│   │                   UninstallCoordinator.swift
│   ├── SystemActions/  Model/ (SystemAction, VolumeLevel) · Service/ (SystemActionRunner,
│   │                   VolumeState) · Settings/ · SystemActionCoordinator.swift
│   ├── CustomCommands/ Model/ · Service/ (ShellCommandRunner) · Settings/ · Coordinator
│   ├── HotKeys/        Model/ (KeyShortcut, HotKeyBinding, HyperKey, DoubleTapModifier,
│   │                   DoubleTapDetector)
│   │                   Service/ (HotKeyCenter, HotKeyBindings, DoubleTapMonitor, HyperKeyTap,
│   │                   ShortcutCaptureSession) · UI/ (ShortcutRecorder, ShortcutRecorderPopover,
│   │                   CalloutShape, CalloutPlacement) · Settings/
│   ├── Backup/         Model/ (SettingsBackup, Raycast*) · Service/ (BackupActions, Scrypt,
│   │                   Gunzip) · Settings/ (BackupSettingsView, RaycastImportSelection)
│   └── Onboarding/     OnboardingState.swift · OnboardingView.swift
│
├── DesignSystem/                     # every shared visual primitive, one import away
│   ├── Theme.swift                   # the single token source (unchanged)
│   ├── KeyCapChip.swift · Tooltip.swift · SymbolImage.swift · VisualEffectView.swift
│   ├── PopoverMenu.swift · SettingsComponents.swift
│   ├── Scrolling/  EdgeDissolve.swift · ThinScrollbar.swift · ScrollIntent.swift
│   │               OverlayScroller.swift          ← ⚠ EdgeDissolve/ThinScrollbar: MOVE ONLY.
│   │                                                Their contents are off-limits (AGENTS.md).
│   └── Interaction/ RightClick.swift · PanelTransition.swift
│
├── Windows/                          # non-palette AppKit surfaces
│   ├── AuxWindowController.swift     # moved out of AboutView.swift (M-9)
│   ├── Dialog/  DialogController · DialogPanel · DialogRequest · DialogView · VolumeSlider
│   ├── HUD/     HUDPanel · HUDPresenter · MessageHUD* · VolumeHUD*
│   └── About/   AboutView.swift
│
├── Settings/                         # the shell, plus the panes that belong to no feature
│   ├── SettingsRootView.swift · SettingsTab.swift   # SettingsTab extracted from the root view
│   ├── AppSettings.swift
│   └── Panes/  GeneralSettingsView.swift · PermissionsSettingsView.swift
│
└── Platform/                         # thin, dependency-free system shims
    ├── Permissions.swift · LaunchAtLogin.swift · CursorScreen.swift
    ├── AppDisplayName.swift · NotificationToken.swift · AppPaths.swift
    ├── Signposts.swift · HealthTicker.swift · Memo.swift
    └── Images/  IconCache.swift · ImageThumbnail.swift   # IconCache extracted from AppIndex.swift
```

**Two rules make the tree decidable** — without them the same file has two plausible homes:

- **A Settings pane lives with its feature; a pane with no feature lives in `Settings/Panes/`.** Only
  two qualify: `GeneralSettingsView` (global shortcuts, search, Hyper key, appearance) and
  `PermissionsSettingsView`. Everything else has an owner — including `MiscellaneousSettingsView`,
  which contains one Calculator card and the currency-consent sheet and is therefore the Calculator
  pane under a misleading name.
- **One top-level `View` or namespace enum per file, named for it.** `LauncherView.swift` and
  `ClipboardView.swift` each declare five, which is why neither name appears above. Splitting them is
  verbatim extraction, not a rewrite — see phase 29's enumerated split list.

**Why this shape and not "Clean Architecture":**

- The three-way `Model/ Service/ UI/` split inside a feature is _not_ invented — it is exactly the
  pure / effect / view split the harnesses already enforce. It renames nothing conceptually; it makes
  the existing rule visible in the file browser and makes "is this file allowed to import AppKit?"
  answerable from its path.
- There is no `Protocols/`, no `UseCases/`, no `Repositories/` layer, no DI container, and no protocol
  introduced for testability — the harnesses test concrete types by compiling them, which is better.
- `Coordinator` appears only where `AppCore` currently exceeds ~60 lines for one feature (6 of 13
  features). The rest have none.
- It scales: a 50th feature is a new sibling under `Features/`, and no existing folder grows.

**Migration cost.** XcodeGen derives sources from `sources: - path: Tinycast`, so **every move is free at
the project level** — `xcodegen generate` and done. The only real cost is that the `Tools/` harness
command lines hard-code file paths, and those paths are written down in `docs/development.md` and
`AGENTS.md`. Update both in the same commit as each move — they are already the contract, and keeping
them accurate is the point.

---

## 5. Refactor Roadmap

Eight phases. Each is independently shippable, each preserves UI and behaviour exactly, and the ordering
is chosen so that later, riskier phases land on top of the safety net built by earlier ones.

**Conventions used below:** _Ships alone_ = mergeable and releasable on its own. _Conflict surface_ =
how likely it is to collide with feature work in flight. _UI risk_ = risk of a visible change.

---

### Week 0 — Baselines (½ day, do this before anything else)

| #   | Task                                                                                                                                                                                                           | Refs  |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| 0.1 | Add `os_signpost` intervals around `AppIndex.scan`, `AppIndex.rank`, `PaletteWindowController.show`, `UninstallScanner.scan` and `AppCore.start` — **baseline every number this document promises to improve** | §6    |
| 0.2 | Record baselines: cold-launch time, binary size, RSS after 10 palette opens, RSS after browsing 50 clipboard images, uninstall scan time on a heavyweight app                                                  | brief |
| 0.3 | Record the comment-density baseline (`grep`-based, four numbers from H-1) so W7.6 can be measured rather than asserted                                                                                         | H-1   |

_Ships alone: yes. Conflict surface: none. UI risk: none._
**Without 0.1, every later phase is a guess.** This is the highest-value half day in the plan — the
signposts stay in the code permanently and cost nothing when no Instruments session is attached.

---

### Week 1 — Zero-risk performance and hygiene

| #   | Task                                                                                                                                                           | Refs |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1.1 | `AppIconView` in `LauncherItemRow`; delete `AppEntry.icon`                                                                                                     | H-3  |
| 1.2 | Cache the Settings-pane scan by directory mtime, threaded through `AppIndex.refresh` like `alternateNameCache`                                                 | H-2  |
| 1.3 | In-memory binding cache + cached `candidateActions` in `HotKeyManager`                                                                                         | M-4  |
| 1.4 | Fully parallel uninstall scan — both root enumeration and directory sizing, uncapped, index-ordered writeback so display order is unchanged                    | H-4  |
| 1.5 | `AppPaths` + adopt in the 8 stores (default-argument form only — no harness changes)                                                                           | M-5  |
| 1.6 | `Memo<Key, Value>` + adopt at the 4 non-harness sites (`AppIndex`, `CalculatorHistoryStore`, `EmojiIndex`, `FrequentEmojiStore`); leave `ClipboardStore` alone | M-7  |
| 1.7 | `HealthTicker`; `tolerance` + session-suspend on the clipboard poll                                                                                            | M-2  |
| 1.8 | Name `Paster`'s three delay constants                                                                                                                          | L-7  |

_Ships alone: yes, each item individually. Conflict surface: low (small, scattered edits). UI risk: none._
**Re-measure against the W0 baseline and record the deltas in the PR body.** This week is also the
proof that the signposts work.

---

### Week 2 — Observation, wave A (leaf stores)

Migrate the 11 leaf `ObservableObject`s with no manual `objectWillChange` and no cross-store fan-out:
`FavoritesStore`, `VisibilityStore`, `CalculatorHistoryStore`, `FrequentEmojiStore`,
`RunningAppsMonitor`, `VolumeState`, `QuicklinkArgumentSession`, `UninstallSession`,
`ShortcutCaptureSession`, `EmojiIndex`, `CurrencyRateStore`.

Per type: `@Observable` on the class → delete `@Published` → `@EnvironmentObject` becomes
`@Environment(Type.self)` → `@ObservedObject` becomes a plain `let`. Drop `import Combine` where it
becomes unused.

\*Ships alone: yes, one type per PR. Conflict surface: medium (touches view files). UI risk: none —
but verify each store's view still updates, since a missing `@Environment` registration compiles fine
and fails at runtime. **Budget a 5-minute manual pass per store: open the surface that renders it,
mutate the store, confirm the view moves.\***

---

### Week 3 — Observation, wave B (the invalidation win) + wave C

| #   | Task                                                                                                                                                                                                     | Refs     |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 3.1 | `AppSettings` → `@Observable`; delete ~25 `didSet` blocks in favour of a small `stored(_:default:)` helper now that property wrappers compose cleanly                                                    | C-3, M-x |
| 3.2 | `AppIndex`, `ClipboardStore`, `QuicklinkStore`, `SnippetsStore`, `PaletteViewModel`, `AppCore`                                                                                                           | C-3      |
| 3.3 | Replace the 6 Combine sink blocks in `AppCore.start()` and the 1 in `AppIndex.start` with `withObservationTracking` — deleting 7 `MainActor.assumeIsolated` hazards and the deferral `Task`s they needed | C-3      |
| 3.4 | Wave C: `HotKeyManager` (now trivial — W1.3 already gave it a real stored property)                                                                                                                      | C-3, M-4 |

_Ships alone: 3.1 and 3.2 individually; 3.3 must follow 3.1. Conflict surface: high — schedule when no
feature branch is open. UI risk: none, but this is the phase that most needs the manual pass._

**Expected measurable outcome, and the headline result of the whole plan:** the palette body stops
re-evaluating on unrelated store changes. Verify with a temporary `let _ = Self._printChanges()` in
`RootPaletteView.body` — copy something to the clipboard while the palette is open in emoji mode and
confirm no change is logged.

---

### Week 4 — `PaletteScreen` extraction

| #   | Task                                                                                       |
| --- | ------------------------------------------------------------------------------------------ |
| 4.1 | Introduce `PaletteScreen`; migrate `.quicklinkArguments` first (smallest, no actions menu) |
| 4.2 | `.uninstall`, `.quicklinks`, `.emoji`                                                      |
| 4.3 | `.clipboard`, `.calculatorHistory`                                                         |
| 4.4 | `.launcher` last (largest, and the only one with the favorites/section logic)              |
| 4.5 | Delete the now-empty switch arms; collapse the eight `calcCount` offsets into one          |

\*Ships alone: yes, one mode per PR — `RootPaletteView` keeps its switch for un-migrated modes throughout.
Conflict surface: high on `RootPaletteView`, zero elsewhere. UI risk: **the highest in the plan.\***

**Mitigation, and this is not optional:** the flat-selection invariant is the thing most likely to break.
Before 4.1, add `Tools/palette-selection-test.swift` asserting — over the pure `rows` arrays alone — that
for every mode the flat index maps 1:1 onto the visible row order with the calculator card at index 0
when present. Migrate one mode, run it, ship, repeat.

---

### Week 5 — `AppCore` decomposition

| #   | Task                                                                                                                                                                                                                                                   | Lines moved |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------- |
| 5.1 | `QuicklinkCoordinator`                                                                                                                                                                                                                                 | ~185        |
| 5.2 | `SnippetExpansionCoordinator`                                                                                                                                                                                                                          | ~160        |
| 5.3 | `PaletteCoordinator` (show/hide/mode/pop-to-root/compact)                                                                                                                                                                                              | ~110        |
| 5.4 | `SystemActionCoordinator`                                                                                                                                                                                                                              | ~95         |
| 5.5 | `UninstallCoordinator`                                                                                                                                                                                                                                 | ~90         |
| 5.6 | `CustomCommandCoordinator`                                                                                                                                                                                                                             | ~75         |
| 5.7 | Fix the three dependency inversions (§2.3): inject what `HotKeyBindings.displayName` needs; move the ✦ preference to a parameter on `KeyShortcut.collapsedModifierSymbols`; give `SystemActionRunner` a failure _callback_ instead of `AppCore.shared` | ~15         |

_Ships alone: yes, one coordinator per PR. Conflict surface: high on `AppCore` only. UI risk: low —
these are pure moves with no logic change, and `AppCore` retains a thin forwarding method wherever a
view currently calls it (delete the forwarders in W7 once call sites are updated)._

**`AppCore` ends at ~250 lines.**

---

### Week 6 — Folder restructure

Mechanical. One PR per top-level destination, in this order (least to most disruptive):
`DesignSystem/` → `Platform/` → `Windows/` → `Palette/` → `Features/<name>/` ×13 → `App/`.

Every PR: `git mv` + `xcodegen generate` + update the harness paths written down in
`docs/development.md` and `AGENTS.md` in the same commit. Extract `IconCache` from `AppIndex.swift` into
`Platform/Images/` on the way past.

_Ships alone: yes. Conflict surface: **total but trivial** — `git` follows renames, so a rebase is
mechanical. UI risk: none. Do this after W4/W5 so the files being moved are already the right files._

⚠ **`EdgeDissolve.swift` and `ThinScrollbar.swift` move but are not opened.** `AGENTS.md` puts their
contents off-limits; a path change is not an edit, but nothing inside them may change in these PRs.

---

### Week 7 — Naming pass, exhaustiveness, feature template

| #   | Task                                                                                                                                                                                                                     | Refs                |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------- |
| 7.1 | Apply the §4.1 renames (`ClipboardMonitor`, `HotKeyBindings`, `CommandCatalog`, `PaletteState`, `AppDisplayName`) — one commit, IDE-driven                                                                               | L-3, L-4, L-5, L-10 |
| 7.2 | Make all nine `AppEntry.Kind` switches exhaustive; collapse per-kind metadata into `KindDescriptor`                                                                                                                      | H-6                 |
| 7.3 | Delete `AppCore`'s W5 forwarding methods; move the 21 view-side `AppCore.shared` references to `@Environment`                                                                                                            | §2.3                |
| 7.4 | `SettingsBackup` completeness harness                                                                                                                                                                                    | M-6                 |
| 7.5 | Write `docs/adding-a-feature.md` — the folder skeleton, the five files, the checklist. Fold §4.1's table into `AGENTS.md`                                                                                                | H-5                 |
| 7.6 | **Comment pass.** Rewrite the `AGENTS.md` comment clause to the H-1 budget, then triage all 181 stacked blocks and 572 over-120-char lines: delete, compress to one clause, or move to `docs/` behind a one-line pointer | H-1                 |

_Ships alone: yes. Conflict surface: high but mechanical. UI risk: none._
7.6 is best done **last in the week and in one commit per subsystem**, so a reviewer reads a pure
comment diff rather than comment changes tangled into renames.

---

### Week 8 — Measure, document, lock in

| #   | Task                                                                                                                                      |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 8.1 | Re-run every W0 baseline; publish the before/after table                                                                                  |
| 8.2 | Instruments: Allocations + Time Profiler over 20 palette opens; Energy Log over 10 idle minutes (validates M-2)                           |
| 8.3 | Re-run the comment-density numbers against the 0.3 baseline                                                                               |
| 8.4 | Update `docs/architecture.md` to describe the pure/effect/view layering as the named architecture, with the folder tree as its expression |
| 8.5 | Re-audit `AGENTS.md`: every invariant that moved a file, and the harness command lines                                                    |

_Ships alone: yes. UI risk: none._

### Roadmap summary

| Phase                | Ships alone        | Conflict surface | UI risk     | Primary payoff                       |
| -------------------- | ------------------ | ---------------- | ----------- | ------------------------------------ |
| W0 Baselines         | ✅                 | none             | none        | Makes every later claim measurable   |
| W1 Perf & hygiene    | ✅ per item        | low              | none        | Immediate, measurable wins           |
| W2 Observation A     | ✅ per type        | medium           | none        | Foundation for W3                    |
| W3 Observation B/C   | ✅ per type        | **high**         | none        | **Largest performance + memory win** |
| W4 PaletteScreen     | ✅ per mode        | high (1 file)    | **highest** | Largest maintainability win          |
| W5 AppCore split     | ✅ per coordinator | high (1 file)    | low         | Largest scalability win              |
| W6 Folders           | ✅ per folder      | total, trivial   | none        | Navigability                         |
| W7 Naming & template | ✅                 | high, mechanical | none        | Consistency, contributor onramp      |
| W8 Measure           | ✅                 | none             | none        | Proof + regression guard             |

If only three weeks are available: **W0, W1, W3.** They carry the entire measurable performance and
memory benefit with the lowest risk of any subset.

---

## 6. Performance & Concurrency Recommendations

### 6.1 Performance

| #   | Recommendation                                    | Complexity                  | Benefit                                                                      | Risk         | Notes                                                                                                                                                                                                                                                                                                        |
| --- | ------------------------------------------------- | --------------------------- | ---------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| P-1 | `@Observable` migration (C-3)                     | **High** (26 types, phased) | **Very high** — fewer body evaluations, less resident Combine machinery      | Low per type | The only change that improves CPU, RAM _and_ safety at once                                                                                                                                                                                                                                                  |
| P-2 | Cache Settings-pane scan (H-2)                    | Low                         | High — ~80 file reads + 80 plist parses off every launcher open              | Low          | Mirror `SpotlightNames.Cache` exactly                                                                                                                                                                                                                                                                        |
| P-3 | Async icons in Settings (H-3)                     | **Trivial**                 | High — removes main-thread rasterisation                                     | None         | 2 lines; best ratio in the doc                                                                                                                                                                                                                                                                               |
| P-4 | Fully parallel uninstall scan (H-4)               | Medium                      | **Very high — 6–12× on the app's longest operation**                         | Low          | Uncapped and by design: a short user-initiated CPU/RAM burst is the right trade here. Display order is preserved structurally by index-ordered writeback, not by completion order                                                                                                                            |
| P-5 | HotKey binding cache (M-4)                        | Low                         | Medium — 140 decodes off launch; recorder conflict scan becomes O(1) lookups | Low          | Prerequisite for C-3 wave C                                                                                                                                                                                                                                                                                  |
| P-6 | Memoize the visibility+favorites chain (M-3)      | Low                         | Medium — ~700 element visits/render for users with favorites                 | Low          | Also removes the `openActions` workaround                                                                                                                                                                                                                                                                    |
| P-7 | `HealthTicker` + poll tolerance (M-2)             | Low                         | Medium — idle energy                                                         | Low          | Validate with `powermetrics`, not intuition                                                                                                                                                                                                                                                                  |
| P-8 | Lazy-load the three JSON caches                   | Low                         | Low–Medium — startup                                                         | Low          | `LauncherRankingStore` (≤1000 records), `CalculatorHistoryStore` (≤200), `FrequentEmojiStore` (≤300) all decode **synchronously in `AppCore.init`** but are only read once the palette opens. Make each a `lazy` load behind first access. **Measure first (0.3)** — this may be under 5 ms and not worth it |
| P-9 | Lower `ImageThumbnail.previewCache` ceiling (L-8) | Trivial                     | Low                                                                          | Low          | **Only if 8.2 shows it matters**                                                                                                                                                                                                                                                                             |

**Explicitly not recommended:**

- Any change to `SearchRelevance` / `FuzzyMatch`. The band arithmetic is correct, fuzz-tested, and not
  a bottleneck.
- FTS or an index for the launcher. ~350 entries scored linearly with a 1-deep memo is already
  well inside frame budget; adding an index would cost RAM and startup for no perceptible gain.
- Any additional caching layer. The brief says cache what should be cached, and the app already does —
  P-2 and P-6 close the two genuine gaps; there is no third.
- Prefetching or warming the icon cache at launch. It would trade the one thing the app protects most
  (startup) for a benefit users already don't perceive (`AppIconView` seeds warm icons synchronously).

### 6.2 Concurrency

The concurrency audit found **no data races, no actor-isolation violations, and no missing `Sendable`
conformances.** Swift 6 complete mode with `SWIFT_STRICT_CONCURRENCY: complete` is doing its job. The
recommendations below are about _reducing the surface where a future mistake becomes possible_.

**Actor boundaries — keep exactly as they are.** The current model is right for this app:

- One actor (`@MainActor`) for everything with identity or UI coupling. **Do not introduce custom
  actors.** A second actor would add hops on the palette's hot path and buy nothing: the heavy work is
  already `nonisolated` + `Task.detached`, and the state it touches is main-actor-owned by nature
  (windows, pasteboard, event taps).
- `nonisolated static` pure functions for CPU/IO work (`AppIndex.scan`, `UninstallScanner.scan`,
  `SettingsPaneScanner.scan`, `EmojiCatalog.parse`, `ShellCommandRunner.execute`). This is the right
  boundary and it is consistently applied.
- `Task.detached` only where the work is genuinely detached from the caller's context (14 sites, all
  justified). Note the codebase correctly avoids `Task.detached` for anything that should inherit
  cancellation.

| #   | Recommendation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Complexity          | Benefit                                              | Risk                                                                 |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ---------------------------------------------------- | -------------------------------------------------------------------- |
| K-1 | **Delete ~30 `MainActor.assumeIsolated` blocks** by migrating off Combine (C-3). Each one is a runtime trap that fires if the assumption is ever violated — e.g. if a future `@Published` is set from a background context. Removing them is a strict safety improvement                                                                                                                                                                                                                                                                                                   | High (rides on C-3) | **High**                                             | Low                                                                  |
| K-2 | **Adopt structured concurrency where fan-out exists.** The codebase uses zero `TaskGroup`s. The uninstall scan (H-4) is the case that matters and both its phases should go parallel — root enumeration _and_ sizing. The rule to apply elsewhere: parallelise a burst the user is waiting on, never steady-state background work. On that rule `AppIndex.scan` stays serial (it runs on every palette open, so saturating cores there would cost more in contention than it saves)                                                                                        | Medium              | **Very high** (H-4)                                  | Low                                                                  |
| K-3 | **Cancellation.** `UninstallSession` and `SnippetsStore` handle it correctly (`scanTask?.cancel()`, generation counters, `Task.checkCancellation()`). `AppIndex.refresh` does _not_ cancel an in-flight scan — it uses a `refreshPending` trailing-collapse instead, which is the right call for a fast idempotent scan. **No change.** But `CurrencyRateStore.pump` should be re-verified after C-3 that its `while !Task.isCancelled, self.isEnabled` loop still holds                                                                                                   | Low                 | Medium                                               | Low                                                                  |
| K-4 | **Task priorities.** Currently `.utility` for background scans and `.userInitiated` for icon/thumbnail decode and uninstall — correct and deliberate. One inconsistency: `AppIndex.refresh` uses `.utility` even though it runs on the _user's launcher keypress_ and gates first paint of new results. Consider `.userInitiated` there                                                                                                                                                                                                                                    | Trivial             | Low–Medium                                           | Low — measure, since `.utility` also keeps it off the way of UI work |
| K-5 | **`Sendable`.** All cross-actor model types conform. The three `@unchecked Sendable` uses (`IconCache.Cache`, `ImageThumbnail.ImageCache`, `Decoded`, `SnippetRepository.Coordinator`, `ShellCommandRunner.StderrCapture`) are each justified in a comment and each is genuinely safe. **No change.** When C-3 lands, re-check that `@Observable` types crossing into detached tasks still do so by value                                                                                                                                                                  | Low                 | Low                                                  | Low                                                                  |
| K-6 | **Async API surface.** `AppCore`'s dialog façade is already `async` (no nested run loop — the single best concurrency decision in the app, since `NSAlert.runModal` would let a held Carbon hotkey stack dialogs). Extend the same discipline: `AppCore.setSnippetsEnabled` still uses `NSAlert.runModal` (`AppCore.swift:1203`) for its consent prompt — **the one remaining `NSAlert` in the app**, and it contradicts the documented "Tinycast presents its own dialogs, never `NSAlert`" invariant. Route it through `DialogController.confirm`                        | Low                 | **Medium — closes a documented invariant violation** | Low                                                                  |
| K-7 | **Task ownership.** Every long-lived `Task` is stored and cancelled in a `deinit` or `stop()` (`SnippetsStore.reloadTask`/`watcherRetryTask`, `CurrencyRateStore.pump`, `UninstallSession.scanTask`, `HUDPresenter.dismissal`, `ShortcutCaptureSession.conflictReset`). One gap: the fire-and-forget `Task { … }`s in `AppCore.start()` (clipboard load, index refresh, emoji load) are unowned. They are short and idempotent so this is benign, but if `AppCore` ever becomes non-singleton it would leak work. **Document the assumption rather than adding machinery** | Trivial             | Low                                                  | None                                                                 |

**K-6 is worth calling out separately** because it is a genuine invariant violation the review found
rather than a preference: `AGENTS.md` states _"Tinycast presents its own dialogs, never `NSAlert` /
`NSSlider` / system popovers"_ and explains why (`runModal`'s nested run loop lets Carbon hotkeys stack
dialogs). `AppCore.setSnippetsEnabled` uses `NSAlert().runModal()`. Because it is reached only from a
Settings click it cannot currently stack — but it is the exact pattern the invariant exists to prevent,
and it renders an Aqua alert on a forced-`.darkAqua` surface.

---

## Appendix A — Findings index

| ID       | Severity | Title                                                                      | Effort |
| -------- | -------- | -------------------------------------------------------------------------- | ------ |
| C-1      | Critical | `AppCore` god object (1,348 lines, 13 responsibilities)                    | W5     |
| C-2      | Critical | `RootPaletteView` god view (1,126 lines, 13 observed objects, 8 switches)  | W4     |
| C-3      | Critical | No Observation adoption on a macOS 26 target                               | W2–W3  |
| H-1      | High     | Comment volume has overtaken the code (181 stacked blocks, 51% >100 chars) | W7     |
| H-2      | High     | Settings-pane scan repeated on every palette open                          | W1     |
| H-3      | High     | Synchronous main-thread icon rasterisation in Settings                     | W1     |
| H-4      | High     | Uninstall scan is fully serial (roots + sizing)                            | W1     |
| H-5      | High     | A feature spans 14 files across 3 trees                                    | W4–W7  |
| H-6      | High     | `AppEntry` union + nine scattered switches, four non-exhaustive            | W7     |
| M-1      | Medium   | `Core/` is a 46-file flat namespace                                        | W6     |
| M-2      | Medium   | Five timers; three duplicate health checks                                 | W1     |
| M-3      | Medium   | Unmemoized visibility + favorites chain per render                         | W1     |
| M-4      | Medium   | `HotKeyManager` re-decodes UserDefaults per lookup                         | W1     |
| M-5      | Medium   | Eight copies of the channel-directory computation                          | W1     |
| M-6      | Medium   | `SettingsBackup` hand-mirror has no completeness check                     | W7     |
| M-7      | Medium   | Six hand-rolled memo caches                                                | W1     |
| M-8      | Medium   | `Features/Settings/` mixes four kinds of thing                             | W6     |
| M-9      | Medium   | `AuxWindowController` hidden inside `AboutView.swift`                      | W6     |
| L-1…L-10 | Low      | See §3                                                                     | W6–W7  |
| K-6      | —        | The one `NSAlert` violating a documented invariant                         | W1     |

## Appendix B — What deliberately stays unchanged

Recorded so a future reader knows these were examined and kept on purpose:

- `SearchRelevance` / `FuzzyMatch` band arithmetic and the learned-boost cap.
- `EdgeDissolve.swift`, `ThinScrollbar.swift` — off-limits by `AGENTS.md`; W6 moves the files, opens neither.
- `ClipboardStore`'s and `QuicklinkStore`'s SQLite helper duplication (L-2) — the isolation invariant is
  worth 60 duplicated lines.
- `SettingsBackup`'s manual mirror (M-6) — the explicit omission of `snippetsEnabled` is a security
  control, not an oversight.
- The single-`@MainActor` concurrency model — a second actor would cost hops and buy nothing.
- `HotKeyBinding`'s `Codable` compatibility seam and the legacy `KeyboardShortcuts_*` defaults keys.
- `AppIndex.refresh`'s trailing-collapse (rather than cancel-and-restart) semantics.
- The forced `.darkAqua` appearance and the whole Liquid Glass surface recipe.
- Zero third-party dependencies. Nothing in this document adds one.
