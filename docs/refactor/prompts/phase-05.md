# Phase 05 kickoff — `AppPaths`

Read `docs/refactor/phases/05-app-paths.md` completely before editing. The boundaries section is the
whole phase.

## Task

Add `Tinycast/Core/AppPaths.swift` with `caches(bundleID:)` and `applicationSupport(bundleID:)`, and
adopt it in the **four** non-harness-compiled types.

## Hard gates

**Adopt in exactly these four:**
`CalculatorHistoryStore`, `FrequentEmojiStore`, `CurrencyRateStore`, `OnboardingState`.

**Do NOT touch these four — they are compiled standalone by `Tools/` harnesses and `AGENTS.md` says each
must depend on no other app source:**
`ClipboardStore`, `QuicklinkStore`, `LauncherRankingStore`, `SnippetRepository`.

- **Channel isolation is non-negotiable**: every path stays keyed by `Bundle.main.bundleIdentifier`, so
  a Dev build never shares a directory with a stable one. Paths themselves _may_ change under
  `docs/refactor/POLICY.md` — but there is no reason to change them here, so don't.
- `AppPaths` creates the directory (`createDirectory(withIntermediateDirectories: true)`) exactly as the
  current call sites do.
- `AppPaths` is Foundation-only and depends on no other app type.
- **Do not add `AppPaths.swift` to any harness command line.** If you think you need to, stop and say
  so — that requires an `AGENTS.md` invariant change and it is not this phase.
- `docs/development.md`, `AGENTS.md` and `ci.yml` must not change.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only    # must NOT list ClipboardStore, QuicklinkStore, LauncherRankingStore, SnippetRepository
```

Then wipe the Dev channel and launch — under `POLICY.md` a **clean install** is the storage test now:

```
rm -rf ~/Library/Caches/com.tinycast.app.dev
rm -rf "$HOME/Library/Application Support/com.tinycast.app.dev"
```

Every store must initialise from nothing without crashing.

Run **all** harnesses from `docs/development.md`, unmodified.

## Summarise

Use the system-prompt format. **List every resolved path**, so the reviewer can confirm each is keyed by
the bundle identifier without launching the app. Confirm the clean-install run.
