# Phase 02 — Async icons in the Settings launcher list

---

## Status

| Field                         | Value                                 |
| ----------------------------- | ------------------------------------- |
| **Status**                    | Complete                              |
| **Started**                   | 2026-08-05                            |
| **Completed**                 | 2026-08-05                            |
| **Operator**                  | abue-ammar                            |
| **Branch**                    | `refactor/02-async-icons-in-settings` |
| **Commit**                    | `40bab1f` (#158)                      |
| **Claude conversations used** | 1                                     |
| **Actual effort**             | ~0.5h vs. estimate of S               |

---

## Completed tasks

- [x] Objective 1 — replace the synchronous icon render in `LauncherItemRow` with `AppIconView`
- [ ] Objective 2 — delete `AppEntry.icon` (**not done**; two live callers remain — see Deviations)
- [x] Objective 3 — confirm no other synchronous icon path remains in a list context (one does, in
      `AppPickerPopover`; recorded as follow-up rather than fixed here)

## Acceptance criteria

- [x] AC1 — `LauncherItemRow` renders through `AppIconView`, no synchronous `IconCache` call remains in
      it — verified by: the diff is the row body itself; `grep -rn "\.icon\b" Tinycast` no longer matches
      `LauncherItemsCard.swift`
- [x] AC2 — warm icons paint on the first frame with no placeholder flash — verified by: `AppIconView` is
      untouched, so its `init` still seeds `_image` from `IconCache.cached…`/`cachedSymbol` synchronously.
      Visual confirmation is part of the outstanding regression sweep
- [x] AC3 — `AppEntry.icon` deleted **or its remaining caller named** — verified by: satisfied via the
      documented-caller branch; both callers named under Deviations
- [x] AC4 — icon size, corner radius and row layout pixel-identical — verified by: the `22 × 22` frame is
      unchanged and `AppIconView` applies `.resizable()` internally. Screenshot comparison is part of the
      outstanding regression sweep
- [ ] AC5 — `grep -rn "IconCache.icon(forFile" Tinycast` returns only the internal call — **NOT MET**;
      three hits remain (`AppIndex.swift:95`, `AppPickerPopover.swift:80`, `ClipboardView.swift:441`).
      The criterion presupposes the AC3 deletion the codebase does not permit inside this phase's
      boundaries. See Deviations
- [x] AC6 — no behaviour change beyond decode timing — verified by: `git diff -U0 | grep '^[-+].*"'` is
      empty (no string changed); no condition, default, optional-handling or ordering in the diff

---

## Verification

| Checklist                  | Result | Notes                                                                         |
| -------------------------- | ------ | ----------------------------------------------------------------------------- |
| `checklists/build.md`      | PASS   | §1–4. Debug + Release `BUILD SUCCEEDED`, zero new warnings; binary +0 B       |
| `checklists/testing.md`    | PASS   | Harnesses run: **none** — the one touched file is in no row of the source map |
| `checklists/regression.md` | PASS   | Core sweep + **Launcher & icons** run by the operator before merge            |
| `checklists/review.md`     | PASS   | §1–8 mechanically clean; 1 file, +1/−2, under the expected commit size        |

### Measurements

| Metric                     | Before    | After     | Δ                       |
| -------------------------- | --------- | --------- | ----------------------- |
| Binary size (Release)      | 3,473,448 | 3,473,448 | +0 B (0 %)              |
| Clean install verified?    | —         | n-a       | phase persists nothing  |
| Cold launch, median of 3   | —         | —         | n-a, not a startup path |
| RSS after 10 palette opens | —         | —         | n-a, Settings-only      |
| Phase-specific signpost    | —         | —         | no signpost covers this |

The performance claim here is main-thread work removed from a scroll path, which no existing signpost
measures. Confirmation is the regression sweep's "scrolls smoothly with no hitch on first paint".

---

## Failed tasks

| What                     | Why it failed                                                 | Decision                      |
| ------------------------ | ------------------------------------------------------------- | ----------------------------- |
| Deleting `AppEntry.icon` | Two live callers that cannot move inside the phase boundaries | Deferred — see Follow-up work |

---

## Issues encountered

- **`AppEntry.icon` cannot be deleted as objective 2 assumes.** The phase document anticipated one
  possible blocker (`AppPresentation`) and there are two, both in `AppPickerPopover.swift`. The deciding
  one is `AppPresentation.resolve`, which returns a synchronous non-optional `(name, icon)` tuple:
  `QuicklinkEditorSheet.swift:175` renders it directly, and `ClipboardView.swift:408` folds the `NSImage`
  into an `InfoRow` **value**. Neither can accept a `View` without restructuring, and `ClipboardView` is
  not in the phase's file list at all. The phase's own escape hatch covers this, but AC5 does not — it
  was written assuming the deletion would land.
- The Core sweep and the **Launcher & icons** section of `checklists/regression.md` were run by the
  operator before merge, after this file was first written — including the two checks that matter here:
  no placeholder flash on reopen, and first-paint scroll smoothness.

---

## Deviations from the phase document

- **`AppEntry.icon` is retained**, against objective 2 and AC5, under the phase's stated escape hatch
  ("If a caller exists you cannot safely convert, leave the property and name the caller"). Remaining
  callers: `AppPickerPopover.swift:35` (the picker's own `LazyVStack` row) and
  `AppPickerPopover.swift:77` (`AppPresentation.resolve`). A half-deleted property would be worse.
- **`AppPickerPopover.swift` was not modified**, though the phase lists it as a conditional target. Its
  row has the same synchronous rasterise, but converting it would not enable the deletion — `resolve`
  blocks that regardless — so it was left alone rather than widening the diff for no acceptance-criteria
  gain.
- The diff came in **under** the expected commit size (1 file, +1/−2 against 2–3 files, +5/−15), which is
  the deletion not landing rather than work skipped.

---

## Follow-up work

| Observation                                                                                                                             | Where                                                         | Suggested phase   |
| --------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ----------------- |
| The app picker's own `LazyVStack` row still rasterises synchronously — same bug class as this phase fixed                               | `AppPickerPopover.swift:35`                                   | new small phase   |
| Retiring `AppEntry.icon` needs `AppPresentation.resolve` to stop returning an `NSImage`, which reaches into `ClipboardView`'s `InfoRow` | `AppPickerPopover.swift:75-83`, `ClipboardView.swift:389-441` | new small phase   |
| AC5 as written is unsatisfiable alongside AC3's escape hatch — the two criteria contradict                                              | `phases/02-async-icons-in-settings.md`                        | doc fix, no phase |

---

## Rollback notes

- **Revert command:** `git revert <sha>`
- **Is a plain revert sufficient?** Yes — one view body, no persistence, no migration, no new file.
- **Dependent phases that must also be reverted:** none
- **Data risk on revert:** none

---

## Sign-off

- [x] All acceptance criteria met — except AC5, accepted as a recorded deviation (it contradicts AC3's
      own escape hatch, which this phase took)
- [x] All four checklists passed
- [x] `ROADMAP.md` status table updated
- [x] Follow-ups recorded above, not fixed in this phase
- [x] Merged to `main` — `40bab1f` (#158)
- [x] **Stopped.** Next phase is a separate session.
