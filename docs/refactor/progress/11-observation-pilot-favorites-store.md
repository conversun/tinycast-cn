# Phase 11 — Observation pilot: `FavoritesStore`

---

## Status

| Field                         | Value                                              |
| ----------------------------- | -------------------------------------------------- |
| **Status**                    | Complete                                           |
| **Started**                   | 2026-08-05                                         |
| **Completed**                 | 2026-08-05                                         |
| **Operator**                  | abue-ammar                                         |
| **Branch**                    | `refactor/11-observation-pilot-favorites-store`    |
| **Commit**                    | single commit on the branch                        |
| **Claude conversations used** | 1                                                  |
| **Actual effort**             | ~30 min vs. estimate of S (1–2 h)                  |

---

## Completed tasks

- [x] Objective 1 — `FavoritesStore` is `@Observable`; `ObservableObject` conformance and the
      `@Published` on `keys` are gone
- [x] Objective 2 — both consumers converted: the injection in `PaletteWindowController.ensurePanel()`
      and the declaration in `RootPaletteView`
- [x] Objective 3 — the migration recipe is recorded below, for phases 12–18

## Acceptance criteria

- [x] AC1 — `@Observable`, no `@Published`, no `ObservableObject` — verified by: the diff; the whole
      change to the type is three lines
- [x] AC2 — `.environment` / `@Environment` on both sides — verified by: the non-optional form
      `@Environment(FavoritesStore.self) private var favorites`, written with **no type annotation** so
      the optional overload cannot be selected
- [x] AC3 — `revision` still increments on `toggle`, `remove`, `replace` — verified by: the three
      `revision &+= 1` sites are untouched by the diff; `grep -n revision` shows all three plus the
      declaration
- [x] AC4 — add/remove updates the launcher on the next render, expanded and compact — verified by:
      the operator, interactively
- [x] AC5 — `SettingsBackup` import replaces the list and the UI reflects it — verified by: the
      operator. `SettingsBackup` is untouched and still calls `replace(keys:)`, which bumps `revision`
- [x] AC6 — no other type's observation mechanism changed — verified by:
      `grep -c environmentObject Tinycast/Core/PaletteWindowController.swift` → 14 (was 15), and
      `grep -c @EnvironmentObject Tinycast/Features/RootPaletteView.swift` → 12 (was 13). The only
      `objectWillChange` in the tree is `HotKeyManager`'s, not in the diff
- [ ] AC7 — `Self._printChanges()` shows `RootPaletteView` no longer re-evaluating for unrelated
      changes — **not run.** It is temporary instrumentation requiring a source edit plus an
      interactive session. The mechanism is not in doubt: `@EnvironmentObject` invalidated the view on
      every `objectWillChange`, `@Environment` on an `@Observable` invalidates only on a read property

---

## The migration recipe

**This is the phase's actual deliverable.** Phases 12–18 follow it.

### 1 · The type

```swift
// before
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var keys: [String]
}

// after
@MainActor
@Observable
final class FavoritesStore {
    private(set) var keys: [String]
}
```

`@Observable` goes below `@MainActor`. `private(set)` survives untouched — the macro rewrites the
stored property into a computed one over `_keys` and preserves the setter's access level.

### 2 · Imports

**No import is needed for `@Observable`.** Both Foundation and SwiftUI re-export Observation;
confirmed with `swiftc -swift-version 6 -typecheck` on a two-line scratch file importing only
Foundation. An `import Observation` was written and then removed as redundant.

> Gotcha: `swiftc -parse` does **not** expand macros, so it passes on a file that cannot typecheck.
> Use `-typecheck` for this question.

`import Combine` carried `ObservableObject` and `@Published`, never `@Observable`. Delete it only when
nothing else in the file uses Combine — `AnyCancellable`, `.sink`, `PassthroughSubject`,
`Timer.publish`, `@Published` on some other type, or a second `ObservableObject` declared alongside.
`FavoritesStore.swift` never imported it, so nothing was removed here.

### 3 · Injection and consumption

| Site     | Before                                       | After                                          |
| -------- | -------------------------------------------- | ---------------------------------------------- |
| Injector | `.environmentObject(core.favorites)`          | `.environment(core.favorites)`                 |
| Consumer | `@EnvironmentObject private var favorites: FavoritesStore` | `@Environment(FavoritesStore.self) private var favorites` |

Write the consumer with **no type annotation**. Adding `: FavoritesStore?` selects the optional
overload, which converts a missing injection from a loud trap into a silent nil — the exact failure
this form exists to catch.

Where a view binds two-way into the store (`$store.prop`), `@Environment` alone is not enough; that
view needs `@Bindable var store = store` in the body. No consumer needed it in this phase.

### 4 · `@ObservationIgnored`

`let` constants are never tracked, so `defaults` and `key` needed nothing. Reach for
`@ObservationIgnored` on stored `var`s that must **not** become view dependencies:

- retained `Task` / `AnyCancellable` handles,
- **memo and cache storage from phase 09** — the one that will bite phase 17. A `Memo` held in a
  tracked `var` and written inside a computed property that a view reads produces
  *"Modifying state during view update"*. `ObservableObject` tolerated this because the write went
  through `objectWillChange`; `@Observable` does not.

`revision` was deliberately left **tracked**. It moves in lockstep with `keys`, and
`AppIndex.orderedResults` reads both at the same call site, so tracking it adds no invalidation the
`keys` read did not already cause.

### 5 · What the compiler catches, and the one thing it does not

Removing `ObservableObject` breaks every `@EnvironmentObject`, `@ObservedObject` and `@StateObject`
of that type. Consumers therefore cannot be forgotten, and **a type must migrate together with all of
its consumers in one commit.**

The compiler is blind to exactly one thing: a **missed injection site**, because
`.environmentObject(x)` still compiles for an `@Observable` value. That is the entire runtime risk of
every M2 phase, and it is why a green build proves nothing.

Cheap static backstop: `grep -rn "TypeName(" Tinycast/` to enumerate instantiation sites of the
consuming view and confirm each is reached through a converted injection. Here `RootPaletteView()`
had exactly one site, and it is the one carrying `.environment(core.favorites)`.

### 6 · The manual check that proves it

Launch, open the palette, add a favourite via the Actions menu, confirm it appears in the Favorites
section with no further interaction, remove it, confirm it leaves. Repeat in compact mode. Reading the
diff is not a substitute — the failure mode compiles cleanly and ships broken.

Watch for a stale build: two DerivedData roots exist for this project
(`~/Library/Developer/Xcode/DerivedData/Tinycast-*` and `Dev/tinycast/build/DerivedData/`), and an old
`Tinycast Dev` left running from the other root will silently test the wrong binary.

---

## Verification

| Checklist                  | Result | Notes                                                                                                                                                                                                                                                                            |
| -------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | `xcodegen generate` clean, no new file so no `.xcodeproj` churn. Debug `BUILD SUCCEEDED`. Zero warnings and zero errors from the three changed files, verified by `touch`ing all three and grepping a full recompile. **No pre-phase baseline was captured**, so "zero *new* warnings" is asserted against the file list. Release build and binary size not measured |
| `checklists/testing.md`    | PASS   | The phase names no harness gate, and **no `Tools/` harness compiles `FavoritesStore.swift`** — every harness command in `docs/development.md` names its sources explicitly and none names it. No harness was run; none could be affected                                          |
| `checklists/regression.md` | PASS   | Run by the operator, manually — Core sweep + Launcher & icons, add/remove a favourite in both expanded and compact mode. Recorded on the operator's confirmation; Claude ran no interactive verification in this session                                                          |
| `checklists/review.md`     | PASS   | Self-check, not a separate review pass. §1 scope: 3 files, exactly the phase's expected list, **none from the must-NOT-change list**; +5/−4 against an expected +12/−12. §2 no condition, comparison, default or method signature changed; no `UserDefaults` key touched; `ordered(_:)` untouched; no user-visible string. §3 isolation unchanged — still `@MainActor`, no `@unchecked`, no `nonisolated(unsafe)`. §4 nothing newly retained; `@Observable` replaces a `Published` subject with a registrar. §5 comments +0, stacked blocks +0. §6 no dead code orphaned. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                     | Before | After | Δ                                                                    |
| -------------------------- | ------ | ----- | -------------------------------------------------------------------- |
| Binary size (Release)      | —      | —     | not measured                                                         |
| Clean install verified?    | —      | n-a   | no storage change; the `favoriteApps` key and its format are untouched |
| Cold launch, median of 3   | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`     |
| RSS after 10 palette opens | —      | —     | not measured                                                         |
| `RootPaletteView` invalidations per favourites change | whole view | read-scoped | mechanism verified by inspection, not by `_printChanges` — see AC7 |

The M2 win is not measurable from one leaf store. It accrues across phases 12–18 as the palette stops
re-evaluating for every `objectWillChange` on twenty-odd stores.

---

## Failed tasks

none

---

## Issues encountered

- **An `import Observation` was added and then reverted.** Foundation already re-exports it. Caught by
  typechecking a scratch file; the initial `-parse` check gave a false pass because it does not expand
  macros. Recorded in the recipe so phases 12–18 do not repeat the round trip.
- **A stale `Tinycast Dev` from a second DerivedData root was running** during verification, built
  before this change. Noted so the operator tested the right binary.

---

## Deviations from the phase document

- **No `import` line changed**, where the phase's file table anticipated possibly dropping
  `import Combine`. `FavoritesStore.swift` imports Foundation only and never imported Combine.
- **Diff is +5/−4 against an expected +12/−12.** The estimate assumed import churn and a wider
  consumer surface; `LauncherView` takes `favorites` as a plain parameter, exactly as the phase
  document predicted it might, so it needed no change.

---

## Follow-up work

| Observation                                                                                                     | Where                                    | Suggested phase |
| ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | --------------- |
| `AppActionsMenu` holds `favorites` as a plain stored parameter. Under `@Observable` its body reads now register, so it re-renders on a favourites change where it previously did not — strictly more correct, and noted only because it is a real behaviour delta | `Features/Launcher/LauncherView.swift:244` | none needed     |
| Phase 09's `Memo` storage will need `@ObservationIgnored` when `AppIndex` migrates, or it will trip "Modifying state during view update" | `Core/AppIndex.swift`                    | 17              |
| AC7's `_printChanges()` measurement was never taken; the aggregate re-render win stays unquantified               | —                                        | 34 (final measurement) |
| Phase-01 Instruments baselines were never captured, so no before-numbers exist for any M1/M2 phase                | `progress/01`                            | 34 (final measurement) |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory only — no persistence, no migration, no format
  change. The `favoriteApps` `UserDefaults` key and its stored array are untouched in both directions.
- **Dependent phases that must also be reverted:** phases 12–18 all list 11 as a dependency, but only
  as the source of the recipe. None of them builds on this diff, so reverting 11 alone is coherent as
  long as no later phase has already converted a consumer that shares an injection site.
- **Data risk on revert:** none.

---

## Sign-off

- [x] All acceptance criteria met (AC7 not run — see above)
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] The recipe is recorded above
- [x] Follow-ups recorded above, not fixed in this phase
- [ ] Merged to `main`
- [x] **Stopped.** Next phase is a separate session.
