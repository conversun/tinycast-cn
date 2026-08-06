# Phase 18 — Observation: palette, `AppCore`, and retiring the Combine sinks

---

## Status

| Field                         | Value                                                     |
| ----------------------------- | --------------------------------------------------------- |
| **Status**                    | Complete                                                  |
| **Started**                   | 2026-08-05                                                |
| **Completed**                 | 2026-08-05                                                |
| **Operator**                  | abue-ammar                                                |
| **Branch**                    | `refactor/18-observation-palette-core-and-combine`         |
| **Commit**                    | single commit on the branch                               |
| **Claude conversations used** | 1                                                         |
| **Actual effort**             | ~40 min vs. estimate of L (4–8 h)                         |

---

## Completed tasks

- [x] Objective 1 — `PaletteViewModel` and `AppCore` are `@Observable`; the last two
      `ObservableObject` conformances in `Core/` outside the leaf managers are gone
- [x] Objective 2 — **already delivered by phase 16.** All eight `settings.$…` sinks were converted to
      `withObservationTracking` there; nothing remained to convert
- [~] Objective 3 — the three surviving `MainActor.assumeIsolated` bridges are deleted. The deferral
      `Task`s are **kept**, deliberately: the phase document's premise for removing them is false.
      See *Deviations*
- [x] Objective 4 — `import Combine` dropped from `AppCore.swift`; `cancellables` was already gone

## Acceptance criteria

- [x] AC1 — both types `@Observable` — verified by: `grep "@Published\|ObservableObject" AppCore.swift`
      returns nothing; Debug build green
- [x] AC2 — `hoverHighlightArmed` and `menuOpen` are `@ObservationIgnored` — verified by: the diff.
      `onMenuOpenChanged` took it too (recipe §4, "retained callback handle"), and `menuOpen`'s `didSet`
      was confirmed to still fire under `@ObservationIgnored` by a scratch harness before editing
- [x] AC3 — `import Combine` survives only where genuinely needed — verified by: the five remaining files
      each audited. `CustomCommand`, `SnippetKeywordListener`, `HyperKeyTap` declare
      `ObservableObject`/`@Published`; `OnboardingView` declares `OnboardingModel`;
      `PermissionsSettingsView` uses `Timer.publish(…).autoconnect()`, which **is** Combine — an initial
      grep missed it and it was nearly deleted
- [x] AC4 — `grep -rn "cancellables" Tinycast` returns nothing — verified by: the grep, though this was
      already true on arrival (phase 16)
- [ ] AC5 — `assumeIsolated` drops by exactly 8 — **NOT MET as written; it drops by 3** (36 → 33).
      Unachievable by arithmetic, not by omission: phase 16 had already converted all eight sinks and
      folded `AppCore`'s six into one `track` helper, leaving three bridging blocks in the tree. All
      three are gone (`AppCore` 1→0, `AppIndex` 1→0, `HyperKeyTap` 6→5) and **no** Carbon, CGEvent,
      `DispatchSource`, `Timer` or `NotificationCenter` bridge was touched — the per-file counts confirm
      it
- [~] AC6 — the six feature switches reconcile, toggled **twice** — **mechanism proven, app not driven.**
      See *The re-arming proof* below
- [~] AC7 — search scopes re-index twice in a row — same: same helper shape, same proof, not exercised
      in the running app
- [~] AC8 — Hyper Key reconfigures twice in a row — same
- [x] AC9 — mouse movement does not re-render the palette body — verified by construction:
      `hoverHighlightArmed` is `@ObservationIgnored`, so its two readers
      (`RootPaletteView:1042`, `EmojiGridView:199`) register no dependency. `_printChanges` **not run**
- [ ] AC10 — the quicklink editor sheet still opens from "Create Quicklink" — **not verified
      interactively.** `$core.pendingQuicklinkEdit` survives intact through the `@ObservedObject` →
      `@Bindable` swap, which is a compile-checked conversion

### The re-arming proof

The phase calls this "the single most likely bug" and says nothing but toggling a switch twice catches
it. The app was not driven, so it was settled with a harness that reproduces `track`'s **exact** shape —
same `@Sendable @MainActor` closure pair, same weak self, same recursive re-registration — and writes
the tracked property four times in a row:

```
wrote     [true, false, true, false]
projected [true, false, true, false]   PASS re-arms and reads post-write
```

Four consecutive changes, four reprojections, each reading the post-write value. That covers the
mechanism behind AC6, AC7 and AC8 — all three sites are the same helper. What it does **not** cover is
the wiring: that `applyCustomCommandsPresence` and friends are still reached from the right switches.
That is what the interactive sweep would have shown.

### Why the deferral `Task` had to stay

The phase document's Objective 3 rests on: "`@Published` emits *before* the write … `@Observable` emits
*after*, so both disappear." **The second half is false**, and acting on it would have been the worst
possible outcome for this phase — silent, and green in every automated check.

`withObservationTracking`'s `onChange` is a **willSet** hook. This SDK
(`MacOSX26.5.sdk/usr/lib/swift/Observation.swiftmodule`) declares exactly one overload and it has no
`didChange:` companion:

```swift
public func withObservationTracking<T>(_ apply: () -> T, onChange: @autoclosure () -> @Sendable () -> Swift.Void) -> T
```

Directly observed — inside `onChange`, the property still holds its old value:

```
onChange sees flag = false
after write flag  = true
```

The counterfactual was then run on the real `track` shape with the `Task` removed and everything else
identical:

| variant           | writes                     | reprojections read         |
| ----------------- | -------------------------- | -------------------------- |
| **with `Task`**   | `[true, false, true, false]` | `[true, false, true, false]` |
| **without `Task`** | `[true, false, true, false]` | `[false, true, false, true]` |

Every reconciliation would have been reprojected from the **previous** value — the launcher would show
custom commands when the switch is off and hide them when it is on, off-by-one on every toggle. So the
`Task` is load-bearing and only the `assumeIsolated` around it was removed:

```swift
onChange: { [weak self] in
    Task { @MainActor in
        guard let self else { return }
        self.track(reads, reproject: reproject)
        reproject(self)
    }
}
```

`Task { @MainActor in }` reaches the main actor by *hopping* rather than by *asserting* it, which is the
whole point of deleting an `assumeIsolated` — the old form trapped at runtime if the assumption were
ever wrong. The enqueue is identical: the previous code created its `Task` inside the `assumeIsolated`
block, which was already `@MainActor`. Phase 16's progress note anticipated exactly this, having kept
"`assumeIsolated` + the deferral `Task` for 18".

### `@ObservationIgnored`, and the rule used

| Field(s)                                          | Why                                                                                                              |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `hoverHighlightArmed`, `menuOpen`                 | The phase's own boundary: read at event time from `PalettePanel.sendEvent`; tracking them re-renders the palette on every mouse move |
| `onMenuOpenChanged`                               | Recipe §4's "retained callback handle" — assigned once by `PalettePanel`'s `didSet`, never a view dependency        |
| `windowController`, `messageHUD`                  | **Compiler-forced.** `lazy` under `@Observable` is a hard error: the macro rewrites the property into a computed one, and *"'lazy' cannot be used on a computed property"*. Confirmed on a scratch file before editing |

`pendingQuicklinkForcesDefaultApp` was left **tracked**: it is neither a handle nor a cache, no view
reads it, and ignoring it would have been churn for nothing.

### Injection and consumption

| Site                                    | Change                                                              |
| --------------------------------------- | ------------------------------------------------------------------- |
| `PaletteWindowController.ensurePanel()` | 2 × `.environmentObject` → `.environment` (`core`, `core.palette`)   |
| `AppCore.showSettings()`                | 1 × `.environmentObject(self)` → `.environment(self)`                |
| `RootPaletteView`                       | 2 × `@EnvironmentObject` → `@Environment(T.self)`, no type annotation |
| `SnippetsSettingsView`                  | 1 × `@EnvironmentObject` → `@Environment(AppCore.self)`               |
| `QuicklinksSettingsView`                | `@ObservedObject` → `@Bindable`, keeping `$core.pendingQuicklinkEdit` |
| `RootPaletteView.searchField`           | local `@Bindable var vm = vm`, the only two-way bind on the palette  |

`PalettePanel` needed **no change**: a `weak var` to an `@Observable` class and the `didSet` that
installs the caret hook both work unchanged.

Phase 11's "the compiler cannot see a missed injection" hazard does not apply in this direction —
`.environmentObject(x)` requires `ObservableObject`, so every site was compiler-found.

---

## Verification

| Checklist                  | Result  | Notes                                                                                                                                                                                                                                                                       |
| -------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS    | **Pre-phase baseline captured on this branch before any edit**: `BUILD SUCCEEDED`, 0 source warnings. After: `BUILD SUCCEEDED`, 0 source warnings — a measured delta. (The one `warning:` in both logs is `appintentsmetadataprocessor`, not a source warning.) `xcodegen generate` clean, no new file so no `.xcodeproj` churn. **Startup timing not measured**; release build and binary size not measured |
| `checklists/testing.md`    | PASS    | **All 16 harnesses green**, first run: fuzz, ranking, calc, clipboard, scopes, raycast, emoji, custom-command, snippets, hotkey, callout, system-action, volume, window-command, uninstall, quicklink. The phase document says 17; 16 exist until phase 19 lands `palette-selection-test`. No harness compiles `AppCore.swift`, so none could regress — they gate the files this phase left alone |
| `checklists/regression.md` | NOT RUN | **Waived by the operator** ("no need more tests"). AC6, AC7, AC8 and AC10 rest on it. The re-arming mechanism was proven by harness instead; the *wiring* from each switch to its reconciler was not exercised. No clean-install run — none is required, this phase changes no persisted key, path or format |
| `checklists/review.md`     | PASS    | Self-check. §1 scope: 7 files, all on the phase's expected list, **none from the must-NOT-change list** — `SnippetKeywordListener.swift`, `DoubleTapMonitor.swift`, `HotKeyCenter.swift`, `RunningApps.swift`, `SnippetsStore.swift` and every store from phases 11–17 are absent from `git diff --name-only`; +38/−42 against an expected +100/−140. §2 no condition, comparison, default, method signature, `UserDefaults` key or user-visible string changed. §3 isolation unchanged — still `@MainActor`, no `@unchecked`, no `nonisolated(unsafe)`; three `assumeIsolated` **removed**, none added, and the hop replacing them is strictly safer. §4 nothing newly retained; eleven `@Published` subjects replaced by two registrars. §5 comments +0 / −0. §6 `import Combine` deleted from `AppCore.swift` as orphaned; nothing else orphaned. §7 `EdgeDissolve`/`ThinScrollbar` untouched |

### Measurements

| Metric                                   | Before | After | Δ                                                                        |
| ---------------------------------------- | ------ | ----- | -------------------------------------------------------------------------- |
| `MainActor.assumeIsolated` blocks, tree-wide | 36     | 33    | −3, all three Combine-era bridges; every C/notification/timer bridge intact |
| `ObservableObject` conformances in `Core/`  | 5      | 3     | `PaletteViewModel`, `AppCore` gone                                        |
| Compiler warnings                        | 0      | 0     | measured on this branch, before and after                                  |
| Binary size (Release)                    | —      | —     | not measured                                                               |
| Cold launch, median of 3                 | —      | —     | no phase-01 baseline exists; nothing added to `init` or `start()`           |
| Palette body re-evaluation per mouse move | none   | none  | `hoverHighlightArmed` was never `@Published` and is now `@ObservationIgnored` — preserved, not improved |

---

## Failed tasks

none

---

## Issues encountered

- **The phase document's central premise for Objective 3 is wrong.** Documented in full above. Caught
  because the existing code comments and phase 16's progress note both said the opposite of the phase
  document, which was worth two minutes of harness time to settle.
- **`import Combine` was nearly deleted from `PermissionsSettingsView.swift`.** An audit grep for
  `Combine|Cancellable|Publisher|publisher|sink|Published|ObservableObject` missed `Timer.publish(` —
  "publish" is not "publisher". The operator had already approved the removal; reading the file before
  editing it is what stopped a broken build.
- **`lazy` is incompatible with `@Observable` without `@ObservationIgnored`**, with an error that names
  a compiler-generated `_lazily` symbol rather than the real cause. Settled on a scratch file first.

---

## Deviations from the phase document

- **The deferral `Task`s were kept**, against Objective 3 and the kickoff's summary instruction. The
  phase's stated reason for removing them does not hold for `withObservationTracking`; removing them
  inverts every feature reconciliation. Evidence above. This is the one place where the phase document
  is wrong on **behaviour**, not on structure — the precedence ladder makes the behavioural invariant
  win.
- **AC5's "delta of exactly 8" is arithmetically unreachable** after phase 16. Recorded as NOT MET
  rather than reinterpreted: the *intent* (every Combine-era bridge gone, every C bridge kept) is fully
  satisfied at −3.
- **Objectives 2 and 4 were already complete on arrival.** Phase 16 converted the sinks and removed
  `cancellables`; only `AppCore.swift`'s now-orphaned `import Combine` remained.
- **7 files, not the ~10 the document expects, and +38/−42 against +100/−140.** Same cause.
- **`Features/Settings/*` came to two files, not "various"** — `SnippetsSettingsView` and
  `QuicklinksSettingsView`. Every other pane reaches `AppCore` through plain `let` properties or
  already-migrated stores.
- **`@Observable` widens tracking beyond what `@Published` covered**, as in phases 12 and 17:
  `AppCore.pendingQuicklinkForcesDefaultApp` and `PaletteViewModel`'s properties are all tracked now. No
  view reads the private ones.
- **`checklists/regression.md` was not run at all**, on the operator's instruction, and the phase is
  recorded `Complete` without it — the disposition of phases 13–16. Recorded here rather than silently
  marked PASS.

---

## Follow-up work

| Observation                                                                                                                                                                              | Where                                          | Suggested phase |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | --------------- |
| **The toggle-twice sweep was never run.** AC6/7/8 are proven at the mechanism level only; the switch → reconciler wiring is unexercised. Steps: toggle custom commands, snippets, window management, quicklinks and each "show in launcher" companion **twice**, add two search scopes, change the Hyper Key twice | Settings panes                                 | before merge    |
| **AC10 unverified**: "Create Quicklink" from the palette → Settings opens on the Quicklinks pane with the editor showing                                                                   | `Features/Settings/QuicklinksSettingsView.swift` | before merge    |
| **`_printChanges` still never run** — inherited from 11, 13–17 and now 18. M2 closes with its headline claim correct by construction and unmeasured                                        | `Features/RootPaletteView.swift`               | 34              |
| **M2 closes with Combine still in the tree.** Seven types remain `ObservableObject`: `CustomCommandStore`, `LauncherRankingStore`, `HyperKeyTap`, `DoubleTapMonitor`, `SnippetKeywordListener`, `OnboardingModel`, `ArgumentValues`. C-3 scoped all 26; phases 11–18 enumerated a subset. **Now scheduled as phase 18b**, added after this phase shipped | `Core/`, `Features/Onboarding/`, `Features/Snippets/` | 18b             |
| `AppCore.swift:167` comment still says clipboard `items` is `@Published`; it became `@Observable` in phase 17                                                                              | `Core/AppCore.swift`                           | 34              |
| Phase doc errors: Objective 3's `@Observable`-emits-after premise; AC5's count of 8; "~10 files"; "all 17 harnesses"                                                                       | `phases/18-…md`, `prompts/phase-18.md`         | 35              |
| No phase-01 Instruments baseline exists, so no M1/M2 phase has before-numbers                                                                                                             | `progress/01`                                   | 34              |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes. In-memory observation mechanism only — no persisted key, path,
  schema or format is touched in either direction.
- **Dependent phases that must also be reverted:** none yet, but **all of M3 (19–23) assumes the palette
  is `@Observable`**. Per the phase document's rollback strategy, if this is reverted, phases 19+ must
  not proceed and that must be recorded in `ROADMAP.md`.
- **Data risk on revert:** none.

---

## Sign-off

- [x] AC1–AC4 and AC9 met; AC5 not met (arithmetically unreachable, intent satisfied); AC6–AC8 proven at
      the mechanism level but not in the running app; AC10 not verified
- [ ] All four checklists passed — three passed, `regression.md` **not run**, waived by the operator
- [x] The re-arming mechanism proven, and the phase's one wrong instruction documented with evidence
- [x] All 16 existing harnesses green
- [x] `assumeIsolated` delta confirmed per-file: −3, no C/notification/timer bridge touched
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [x] **Does not block phase 19.** 19 depends on 18 alone, and the thing it needs — `PaletteViewModel`
      and `AppCore` reachable as `@Observable` through `@Environment`, with `selection` a tracked
      property — is in place and compiling. What 19 inherits unfinished is *verification*, not
      structure: the toggle-twice sweep, AC10 and the `_printChanges` measurement.
