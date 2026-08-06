# Phase 31 kickoff — `AppEntry.Kind` exhaustiveness and `KindDescriptor`

Read `docs/refactor/phases/31-app-entry-kind-exhaustiveness.md` completely.

## Task

Make every `AppEntry.Kind` switch exhaustive so the compiler enforces the recipe `AGENTS.md` currently
enforces by prose, then collapse the per-kind metadata into one `KindDescriptor`.

## Hard gates

- **`AppEntry.Kind`'s cases and raw values do not change.** The raw values are persisted in
  `VisibilityStore.hiddenKinds` — changing one silently un-hides a category for every user.
- `KindDescriptor` is a **plain struct returned by one `switch`**. Not a protocol, not a registry, not
  generic. Members are exactly: `label`, `sectionTitle`, `openVerb`, `canRevealInFinder`, `isSymbolIcon`.
- **`symbolIconName` stays a separate switch.** It consults three catalogs and a per-entry override; it
  does not belong in a static table.
- **The section table stays a literal array in `LauncherList.rows`**, in the same order, with the same
  titles. It may read `sectionTitle` from the descriptor, but the _order_ stays hand-written — it must
  mirror `AppIndex.publishEntries`'s slice order, and that relationship is clearer stated once than
  derived.
- **Keep the explicit type annotation on the section array.** Inference times out on it; Release is the
  build that proves it.
- **Every string stays character-identical**: "Application", "System Setting", "Open Application",
  "Run Custom Command", every section title. A table refactor is exactly where a string quietly changes
  case or loses a word.
- Do not add or remove a `Kind` case. Do not touch `AppIndex.publishEntries()`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release CODE_SIGNING_ALLOWED=NO
```

**Then perform the scratch-case test — it is the only proof this phase achieved its goal:**

1. Add `case scratch = "scratch"` to `AppEntry.Kind`
2. Build
3. Count and record the resulting compile errors
4. `git checkout` the file to revert

Every site the `AGENTS.md` recipe names must appear as an error. If any site compiles happily, it still
has a `default:` and the phase is incomplete.

Run `fuzz-test`, `ranking-test`, `palette-selection-test`.

## Summarise

Use the system-prompt format. **Report the scratch-case error count and list the files that errored.**
Then list all eight kinds with their three strings, before and after, so the reviewer can diff them.
