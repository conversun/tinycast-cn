# Phase 21 kickoff — Screens: `quicklinks` and `emoji`

Read `docs/refactor/phases/21-screens-quicklinks-and-emoji.md` completely.

## Task

Add `QuicklinkListScreen` and `EmojiScreen`. The emoji grid is the first screen with two-dimensional
navigation, so this is where `PaletteScreen` likely needs one navigation hook.

## Hard gates

- **If the protocol needs a navigation hook, add exactly ONE member** — e.g.
  `func move(_ delta: Int, axis: PaletteAxis, from: Int) -> Int?` returning nil to mean "use the default
  linear move". Do not build a navigation subsystem.
- **Do not touch `EmojiGridGeometry.swift`.** It is pure, harness-compiled and already correct. The
  screen _calls_ `up(from:)` / `down(from:)`; it does not reimplement grid maths.
- The emoji flat selection indexes `sections.flatMap(\.entries)`. That mapping is the invariant.
- **Chords that move into their screens:**
  - quicklinks: ⌘P (pin), ⌘⌫ (delete), ⌘↵ (open with default — **only when `openWithBundleID != nil`**)
  - emoji: ⌘↵ (copy), ⌥↵ (paste keeping the window open), ← and →
- **⌘K, Escape, Tab and the menu-navigation keys stay in `RootPaletteView`.** They are palette-level.
- **← and → must still reach the field editor in every non-emoji screen.** Only the emoji screen consumes
  them. Getting this wrong breaks caret movement in the search field everywhere.
- Empty-state strings unchanged: "No quicklinks yet", "No matching quicklinks", "Loading emoji…",
  "No emoji found", with the same conditions choosing between them.
- Skin tone still applies at **both** points — at render and at copy time — via `settings.emojiSkinTone`.
- Do not touch `Core/Quicklinks/*`, `EmojiCatalog.swift`, `EmojiData.generated.swift` or `AppCore.swift`.
- Do not migrate the three remaining modes.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only | grep EmojiGridGeometry    # must be empty
```

Extend the selection harness with grid row movement; run it plus `emoji-test` and `quicklink-test`.

**Then run the app**: press ↓ from the last row of an emoji section and confirm it lands in the **same
column** of the next section. Then go to the launcher and confirm ← / → still move the text caret.

## Summarise

Use the system-prompt format. If you added a protocol member, quote it and justify it.
