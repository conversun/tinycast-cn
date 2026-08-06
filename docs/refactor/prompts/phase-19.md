# Phase 19 kickoff — `PaletteScreen` scaffold and the selection harness

Read `docs/refactor/phases/19-palette-screen-scaffold.md` completely.

## Task

Two things, and **no screen migration**:

1. Declare the `PaletteScreen` protocol.
2. Add `Tools/palette-selection-test.swift`, the harness that protects the flat-selection invariant
   through phases 20–23.

## Hard gates

- **`RootPaletteView.swift` must not change by one line.** If it appears in `git diff --name-only`, the
  phase has failed. No screen migrates here.
- **Nothing conforms to the protocol yet.**
- Five members, `@MainActor`, **no default implementations**: `rows`, `primaryActionTitle`,
  `actions(for:)`, `activate(_:)`, `body(selection:scroll:)`.
- **No type erasure, no `AnyPaletteScreen`, no existential wrapper.** Phase 20 is the first adopter and
  will show what is actually needed. Do not pre-solve it.
- The harness must be **Foundation-only** — it cannot import SwiftUI, so it cannot test a `body`. It
  tests the **row-order contract**: given section counts and an optional leading calculator card, index
  _n_ resolves to the element the view would highlight.
- Model that contract as a small pure type (e.g. `PaletteRowIndex`) in a Foundation-only file, under
  ~40 lines, that both the harness and the future screens can use. **Do not build a general-purpose list
  abstraction.**
- Cover at minimum: no calc card; calc card present; empty list; single section; multiple sections;
  selection clamped at both ends.
- Register the harness in `docs/development.md`, `AGENTS.md` and
  `docs/refactor/checklists/testing.md`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only | grep RootPaletteView    # must be empty
```

Run all 17 harnesses including the new one.

**Then prove the harness can fail:** deliberately break the pure index type, run it, confirm it fails,
and revert the break. A test that cannot fail is not a test, and phases 20–23 will be relying on it.

## Summarise

Use the system-prompt format. Quote the assertions the harness makes, and confirm you performed the
deliberate-break check and what it reported.
