# Development

How to build, test, package, and release Tinycast.

## Requirements

- macOS 26 or later (Liquid Glass).
- Xcode 26 installed — it provides the SwiftUI macro plugin and SDK used to build.

## First-time setup

Create the `Tinycast Self-Signed` code-signing identity once — builds sign with it, which keeps the
macOS Accessibility grant from being forgotten every rebuild. Follow **[signing.md](signing.md) §1**
(a few `openssl`/`security` commands).

## Build & run

Open the project in Xcode and run it:

```sh
open Tinycast.xcodeproj    # then press ⌘R
```

Or from the command line:

```sh
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug build
```

`xcodebuild` uses whatever `xcode-select` points at; if that's the Command Line Tools rather than
Xcode, prefix with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (the SwiftUI
`@State`/`@FocusState` macros need Xcode's macOS platform).

`Tinycast.xcodeproj` is committed and generated from `project.yml` via
[XcodeGen](https://github.com/yonaskolb/XcodeGen) — after changing project settings in `project.yml`,
run `xcodegen generate` and commit the result.

### The dev channel

Debug builds are a separate channel: **`Tinycast Dev.app`**, bundle id `com.tinycast.app.dev`. Since
every persisted thing is keyed by bundle
id — `~/Library/Preferences/<id>.plist` (settings + hotkey bindings),
`~/Library/Caches/<id>/` (clipboard history, calculator history, exchange rates, frequent emoji),
`~/Library/Application Support/<id>/` (the onboarding marker and snippets), the `SMAppService` login
item, and the Accessibility / Input Monitoring (TCC) grants — a build you run locally can't read or
clobber the installed app's state, and both can run side-by-side.

Consequences worth knowing:

- The dev build asks for Accessibility on its own the first time, and starts with **no** hotkeys bound
  and onboarding unseen. Grant + bind once; it persists across rebuilds (the fixed build path and the
  `Tinycast Self-Signed` identity keep the TCC grant alive).
- Don't bind the same global hotkey in both — whichever registered first wins.
- The Hyper Key's Caps Lock remap is `hidutil` state, which is **system-wide, not per-bundle**:
  quitting one build clears the remap for the other, which then needs a rebind (or relaunch) to
  restore it.

### Editor (VS Code) code-intelligence

Autocomplete / go-to-definition come from SourceKit-LSP driven by a `buildServer.json`. Generate it
once (it's machine-specific and git-ignored):

```sh
brew install xcode-build-server
xcode-build-server config -project Tinycast.xcodeproj -scheme Tinycast \
    --build_root "$PWD/build/DerivedData"
```

`--build_root` matches the fixed path the VS Code build task / F5 use, so the editor indexes what you
actually build. Do a build once (⌘⇧B or F5) to populate it. In VS Code, **F5** builds and launches the
app; changes always apply (fixed build path — no need to delete `build/`).

## Tests

There's no XCTest target. Standalone harnesses:

```sh
swiftc -swift-version 6 Tinycast/Core/SearchRelevance.swift Tinycast/Core/Pinyin.swift \
    Tools/fuzz-test.swift -o /tmp/fuzz-test && /tmp/fuzz-test        # launcher matcher + field priority + pinyin
swiftc -swift-version 6 Tinycast/Core/SearchRelevance.swift \
    Tinycast/Core/LauncherRankingStore.swift Tools/ranking-test.swift \
    -o /tmp/ranking-test && /tmp/ranking-test                      # learned launcher ranking
swiftc Tinycast/Core/Calculator/*.swift Tools/calc-test.swift \
    -o /tmp/calc-test && /tmp/calc-test                           # calculator engine
swiftc -swift-version 6 Tinycast/Core/ClipboardStore.swift Tools/clipboard-test.swift \
    -o /tmp/clipboard-test && /tmp/clipboard-test                 # clipboard store
swiftc -swift-version 6 Tinycast/Core/SearchScopes.swift Tools/scopes-test.swift \
    -o /tmp/scopes-test && /tmp/scopes-test                       # launcher search scopes
swiftc -swift-version 6 Tinycast/Core/Backup/RaycastFormat.swift \
    Tinycast/Core/Backup/RaycastV1Decoder.swift Tinycast/Core/Backup/Gunzip.swift \
    Tinycast/Core/ClipboardStore.swift Tools/raycast-test.swift \
    -o /tmp/raycast-test && /tmp/raycast-test                     # raycast format detect + v1 decode
swiftc Tinycast/Core/Emoji/EmojiCatalog.swift Tinycast/Core/Emoji/EmojiGridGeometry.swift \
    Tinycast/Core/Emoji/EmojiData.generated.swift Tools/emoji-test.swift \
    -o /tmp/emoji-test && /tmp/emoji-test                         # emoji catalog + geometry
swiftc -swift-version 6 Tinycast/Core/CustomCommand.swift \
    Tinycast/Core/ShellCommandRunner.swift Tools/custom-command-test.swift \
    -o /tmp/custom-command-test && /tmp/custom-command-test        # custom command store + runner
swiftc -swift-version 6 Tinycast/Core/NotificationToken.swift \
    Tinycast/Core/Snippets/*.swift \
    Tools/snippets-test.swift -o /tmp/snippets-test && /tmp/snippets-test  # snippets
swiftc -swift-version 6 Tinycast/Core/HotKey/DoubleTapModifier.swift \
    Tinycast/Core/HotKey/DoubleTapDetector.swift Tools/hotkey-test.swift \
    -o /tmp/hotkey-test && /tmp/hotkey-test                        # double-tap modifier recognizer
swiftc -swift-version 6 Tinycast/Core/Theme.swift \
    Tinycast/Core/CalloutPlacement.swift Tools/callout-test.swift \
    -o /tmp/callout-test && /tmp/callout-test                      # shortcut-recorder callout placement
swiftc -swift-version 6 Tinycast/Core/SystemAction.swift Tools/system-action-test.swift \
    -o /tmp/system-action-test && /tmp/system-action-test        # system action metadata + safety
swiftc -swift-version 6 Tinycast/Core/VolumeLevel.swift Tools/volume-test.swift \
    -o /tmp/volume-test && /tmp/volume-test                        # volume step grid + percentage
swiftc -swift-version 6 Tinycast/Core/WindowManagement/WindowCommand.swift \
    Tinycast/Core/WindowManagement/WindowLayout.swift \
    Tinycast/Core/WindowManagement/WindowActionMemory.swift Tools/window-command-test.swift \
    -o /tmp/window-command-test && /tmp/window-command-test        # window geometry + action memory
swiftc -swift-version 6 Tinycast/Core/Uninstall/UninstallTarget.swift \
    Tinycast/Core/Uninstall/UninstallSearchRoot.swift Tinycast/Core/Uninstall/UninstallRules.swift \
    Tinycast/Core/Uninstall/UninstallProtection.swift Tinycast/Core/Uninstall/UninstallPlan.swift \
    Tools/uninstall-test.swift -o /tmp/uninstall-test && /tmp/uninstall-test  # uninstall attribution + locking
swiftc -swift-version 6 Tinycast/Core/Quicklinks/Quicklink.swift \
    Tinycast/Core/Quicklinks/QuicklinkDestination.swift \
    Tinycast/Core/Quicklinks/QuicklinkStore.swift Tinycast/Core/Quicklinks/QuicklinkArchive.swift \
    Tools/quicklink-test.swift -o /tmp/quicklink-test && /tmp/quicklink-test  # quicklink destinations + store
```

`Tools/fuzz-test.swift` compiles the real `Tinycast/Core/SearchRelevance.swift` and the real
`Tinycast/Core/Pinyin.swift`, which is why both files must stay Foundation-only and pure. Alongside
the fixed cases it runs a seeded randomized loop
(~100k queries) asserting that every score stays inside its field band, that the learned boost cap
can never lift one out, and that scoring is deterministic. The calc harness compiles the real engine
sources, which is why `Tinycast/Core/Calculator/` must stay Foundation-only. The system-action harness
similarly keeps `SystemAction.swift` independent from AppKit and all command side effects. The
uninstall harness is the same idea taken furthest: it touches no filesystem at all, because
`UninstallScanner` hands the rules directory *names* and the protection classifier takes its
environment facts as parameters.

The clipboard harness likewise compiles the real `ClipboardStore.swift`, so that file must keep to
Foundation + SQLite3 and depend on no other app source. Each case drives a store rooted in a
throwaway temp directory (`ClipboardStore(directory:)`), so a run can never reach a real history.

The custom-command harness spawns **real `/bin/zsh`** processes. Its shell-environment cases point
`ZDOTDIR` at a throwaway fixture directory (and unset `TERM_PROGRAM`), so a run can never read or write
the developer's own dotfiles. `/etc/zshrc` is still sourced for interactive shells, so the assertions
are relative — the fixture's alias resolves with `-i` and not without — rather than absolute.

The snippets harness compiles the real model, codec, template engine, Foundation-only repository,
keyword/event/lifecycle policies, AppKit delivery primitives and main-actor store. Injected temporary
roots and named pasteboards cover identity, per-channel isolation, malformed files, revision
conflicts, watcher rearming, template determinism, delivery serialization and pasteboard restoration without touching a real snippets library or clipboard. The
complete subsystem contract is in [snippets.md](snippets.md).

The Raycast harness compiles the real format detector and v1 decoder, so both must stay Foundation +
CommonCrypto + Carbon (no AppKit). It builds its own v1 files in-process — a small embedded gzip blob
encrypted with `CCCrypt` — and feeds the mapper hand-written JSON, so no real `.rayconfig` is ever
committed. Turning payload values into Tinycast's own types lives in `RaycastImportV1`, which needs
AppKit and is covered by the app build instead. The format contract is in
[raycast-import.md](raycast-import.md).

The quicklink harness compiles the real model, destination detector, SQLite store and JSON archive,
so those four must stay Foundation-only (plus SQLite3). Each store is rooted in a throwaway temp
directory and every path rule is asked against an injected home, so a run can never reach a real
library. One case deliberately corrupts a database file and asserts the store reports itself
unavailable **and leaves the file byte-for-byte intact** — quicklinks are authored data, so unlike
`ClipboardStore` this one never deletes and recreates.

The window-command harness compiles the real catalog, geometry and action memory (Foundation +
CoreGraphics — `CGRect`'s `Equatable` conformance lives in the CoreGraphics overlay, not Foundation).
It covers tiling, gaps, cycling, restore, display moves and the memory's reset rules against synthetic
`WindowLayout.Screen` values, plus a fuzz sweep over every command × gap × screen × degenerate window
frame. All of it runs headless because the layer is pure: `WindowMover` owns every `AXUIElement` call
and is deliberately not compiled in. The full contract is in
[window-management.md](window-management.md).

## Formatting

Formatting is whatever Xcode's own reindent does — there's no formatter and no linter. The bar is
CONTRIBUTING.md's "builds clean": no new compiler warnings.

## Generated data

Two Swift files are emitted by scripts and must never be hand-edited. Both download their source, so
run them online, then commit the result:

```sh
node Tools/gen-emoji.js            # -> Tinycast/Core/Emoji/EmojiData.generated.swift
node Tools/gen-currencies.js       # -> Tinycast/Core/Calculator/CurrencyData.generated.swift
```

`gen-currencies.js` joins two sources on the ISO code: **Frankfurter**'s currency list (the same feed
`CurrencyRateStore` fetches rates from, so the table and the rate source can't drift apart) and
**Unicode CLDR**'s `en` currency data, which supplies display names, signs and the singular/plural
noun. It reads the pinned `cldr-json` checkout rather than the host's `Intl`, whose output shifts
with the local ICU version and would make the file unreproducible.

Only unambiguous data is emitted. Anything two currencies claim — `dollars`, `pounds`, `krona` — is
left out and decided by hand in `CalcCurrency.contested`, the one currency table still written by
hand. Re-run the script when a currency is added or retired; nothing breaks in the meantime, since
an unquoted code just reports "no exchange rate".

## Packaging a DMG

For a local signed DMG:

```sh
./build-dmg.sh            # -> build/Tinycast-<version>.dmg (version from project.yml)
./build-dmg.sh 0.5.7      # -> build/Tinycast-0.5.7.dmg
```

It builds a Release `Tinycast.app` signed with `Tinycast Self-Signed` and packs it (with an
`/Applications` symlink). Official per-channel releases (beta/stable) are built by CI — see
below and [`.github/workflows/release.yml`](../.github/workflows/release.yml).

## Signing & Gatekeeper

Both local builds and CI releases sign with the same stable `Tinycast Self-Signed` identity (not an
Apple Developer ID), so macOS quarantines a directly-downloaded DMG — the Homebrew cask strips that
automatically, and direct downloaders run `xattr -dr com.apple.quarantine "…/Tinycast.app"` once.
Full details in [signing.md](signing.md).

## Continuous integration

`.github/workflows/ci.yml` runs on every PR and every push to `main`, on a `macos-26` runner with
Xcode 26 (same selection step as the release workflow). It has one job, a merge gate; a new push
cancels the in-flight run for the same ref:

- **`test`** — every `Tools/*.swift` harness from [Tests](#tests) above, in order.

There is **no `xcodebuild` step**: a Debug build costs minutes on every run and the release workflow
builds before it ships anyway, so CI keeps to the one check that finishes in about a minute. A change
that compiles nowhere still turns the PR green — **build locally before you open one** (`xcodebuild
-project Tinycast.xcodeproj -scheme Tinycast -configuration Debug build`, or just ⌘B in Xcode).

Same commands locally: the harness block from [Tests](#tests).

## CI releases

`.github/workflows/release.yml` builds and publishes a DMG from GitHub Actions — no local machine
needed. Run it from the **Actions** tab (`Release` → **Run workflow**) and pick:

- **channel** — `beta` or `stable`. Each builds a distinct app
  (`Tinycast Beta.app` / `Tinycast.app`) with its own bundle id, alongside the local
  `Tinycast Dev.app` (above).
  Beta gets an auto-incrementing `-beta.N` suffix (`N` = the Actions run number)
  so re-running never collides; stable ships the version as-is.
- **version** — base semver, e.g. `0.2.0`.

It builds on a `macos-26` runner with Xcode 26 and publishes a GitHub Release tagged
`v<full-version>` with a versioned DMG asset (`Tinycast-<full-version>.dmg`), marked prerelease
for beta. On success it also bumps the matching cask in the tap (below).

### Homebrew tap automation

The release job's final step rewrites the `version` + `sha256` of the channel's cask (`tinycast`
or `tinycast@beta`) in the
[`homebrew-tinycast`](https://github.com/abue-ammar/homebrew-tinycast) tap and pushes. It needs a
`HOMEBREW_TAP_TOKEN` repo secret — a fine-grained PAT with **Contents: read/write** on the tap
repo. Without the secret the step logs a warning and skips (the release still publishes).

## Website

`.github/workflows/website.yml` builds `website/` (Vite + React + TS) and deploys it to GitHub
Pages at `https://abue-ammar.github.io/tinycast/` on every push to `main` that touches
`website/`. Enable it once via **Settings → Pages → Source = GitHub Actions**.

```sh
cd website && npm install && npm run dev     # local preview
```
