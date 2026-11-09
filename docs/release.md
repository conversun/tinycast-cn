# Release

How a build reaches a user. The local development loop is in [development.md](development.md);
the signing identity itself is in [signing.md](signing.md).

## Packaging a DMG locally

```sh
./Scripts/build-dmg.sh            # -> build/Tinycast-<version>.dmg (version from project.yml)
./Scripts/build-dmg.sh 0.5.7      # -> build/Tinycast-0.5.7.dmg
```

It builds a Release `Tinycast.app` signed with `Tinycast Self-Signed` and packs it with an
`/Applications` symlink. Official per-channel releases are built by CI, below.

## Signing & Gatekeeper

Upstream CI releases are signed with the team's Developer ID, notarized and stapled, so a downloaded DMG
opens without a Gatekeeper warning. Local builds, `build-dmg.sh` included, keep signing with
`Tinycast Self-Signed` and are never notarized. Full details in [signing.md](signing.md).

CN releases keep the existing `Tinycast Self-Signed` identity and are not notarized. Homebrew clears
quarantine during installation; direct DMG downloads need the quarantine command below.

## How the in-app updater consumes a release

This section describes upstream packaging and version rules. The CN fork's separate feed,
bundle identifiers and fork revisions are described under [Chinese fork](#chinese-fork).

Every release publishes three assets from one build: `Tinycast-<version>.dmg`, which people download
by hand and which the cask installs, `Tinycast-<version>.zip`, which the in-app updater installs, and
`Tinycast-<version>.zip.sig`, the zip's signature by the release key. The zip is produced with
`ditto -c -k --keepParent --sequesterRsrc` — the only zip that leaves the code signature verifiable,
which matters because the updater refuses any bundle it cannot prove is ours.

A stable release publishes two more from the `universal` job, `Tinycast-Universal-<version>.dmg` and
`.zip`, built from the same commit at the same version and bundle id but with both slices. They are
uploaded _after_ the thin pair, which keeps the thin zip first in the asset list so builds predating
architecture-aware selection keep choosing it.

Three things a release must keep true, or the updater skips it:

- **It carries a `.zip` asset this Mac can run.** A DMG-only release is not installable and is not
  offered, and an Intel build is offered nothing rather than a thin arm64 zip.
- **The tag parses as `vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH-beta.N`,** and agrees with the
  `prerelease` flag. A tag of any other shape is treated as mis-published and skipped.
- **It is not a draft.**

**Every cask declares `auto_updates true`.** That is Homebrew's flag for an app that manages its own
version, and it is what keeps `brew update && brew upgrade` from fighting an app that updated itself:
brew never reports Tinycast outdated, never re-downloads it, and never rolls a self-updated copy back.
Removing that line would reintroduce exactly those three problems. See
[features/updates.md](features/updates.md).

## Pull request review

There is no CI workflow and no automated reviewer, so the whole bar in
[testing.md](testing.md#definition-of-done) is run locally before a PR is opened.

## Releasing

### Chinese fork

`conversun/tinycast-cn` publishes through `release-cn.yml`, not the upstream workflow.
The intended next stable release is `v0.12.11-cn.1`, based on `v0.12.11`.
Dispatch it with `version=0.12.11-cn.1`, `upstream_tag=v0.12.11`,
an exact verified source commit, `prerelease=false`, and a Chinese `release_notes` changelog.
Supply a fresh Chinese changelog for each release, including any changes pulled from upstream
after the named stable tag.
The source may include newer upstream `main` commits; the release tag always points to the
verified fork commit.

The workflow runs on `macos-26` with Xcode 26, checks localization and runs the harnesses,
builds a signed Universal app,
checks both architectures in the app and its three helpers, and verifies signatures. From that
same signed app it packages both `Tinycast-CN-<version>.dmg` for manual/Homebrew installation
and `Tinycast-CN-Universal-<version>.zip` for the updater, using
`ditto -c -k --keepParent --sequesterRsrc`. Before either asset is uploaded or published,
the ZIP is expanded into scratch storage, its signature is verified again, and both `arm64`
and `x86_64` slices are checked in all four binaries.

Use the Apple silicon runner even though it also builds Intel slices. The `macos-26-intel`
hosted image can hang in IconServices while rasterizing system icons; its tests must not be skipped.

CN versions are `<triple>-cn.N` for stable builds or `<triple>-beta.N-cn.N` for beta builds.
The final `cn.N` is a fork revision, not a prerelease indicator: `0.11.19-cn.2` is a stable
successor to `0.11.19-cn.1`. The upstream version and beta sequence sort first, then the numeric
CN revision. Stable releases use `prerelease=false` and `com.conversun.tinycast-cn`; beta releases
use `prerelease=true` and `com.conversun.tinycast-cn.beta`. Each Dictation helper derives its
`.dictation` identifier through `TINYCAST_BUNDLE_IDENTIFIER`. The CN-only updater uses the fork's
release feed and does not update upstream bundle identifiers.

The release body puts the supplied Chinese changelog and GitHub-generated merge records
(compared with the previous non-draft release in the same stable/beta channel) above
`<!-- tinycast:install -->`. Homebrew and quarantine instructions remain below it, so the
update window shows changes rather than installation commands. Both dispatch and reusable
workflow callers must supply `release_notes`.

After ZIP validation and release publication, stable runs update `conversun/homebrew-tinycast-cn`
when `HOMEBREW_TAP_DEPLOY_KEY` is available; prereleases never bump the cask. The deploy key
still grants access only to the tap. The cask's version and SHA-256 match the **DMG**, not the
ZIP, and the bump sets `auto_updates true` so ordinary Homebrew upgrades do not overwrite a
self-updated app. Without the key, the workflow warns and leaves the tap unchanged.

An older CN installation that does not recognize the CN channel/version format cannot bootstrap
this updater by itself. Install the updater-capable DMG manually, or use
`brew update && brew upgrade --cask --greedy tinycast-cn` for that initial upgrade, including
a cask marked `auto_updates true`. Subsequent CN updates use the validated ZIP in-app;
beta users must install the beta DMG initially because the tap tracks only stable releases.

### Upstream channels

`.github/workflows/release.yml` builds and publishes a DMG from GitHub Actions, no local machine
needed. Run it from the **Actions** tab (`Release` → **Run workflow**) and pick:

- **channel** — `beta` or `stable`. Each builds a distinct app (`Tinycast Beta.app` / `Tinycast.app`)
  with its own bundle id, alongside the local `Tinycast Dev.app`. Beta gets an auto-incrementing
  `-beta.N` suffix (`N` = the Actions run number) so re-running never collides; stable ships the
  version as-is.
- **version** — base semver, e.g. `0.2.0`.

Its first step is `Scripts/check-migrations.sh`: a migration that a stable release already shipped
stops the run until it is deleted ([migrations.md](migrations.md)). The check reads tags and history,
so the checkout fetches every commit without blobs.

It builds on an `xcode-27` runner with the newest released Xcode 27 and publishes a GitHub Release
tagged `v<full-version>` with a versioned DMG and zip asset, marked prerelease for beta. On success
it also announces the release on Discord. A stable run also dispatches the Website workflow, because
the site reads the latest version and the [changelog](https://tinycast.dev/changelog/) from GitHub at
build time.

A stable run then fans out to a second job, `universal`, which rebuilds the same commit with
`ARCHS="arm64 x86_64"` and attaches `Tinycast-Universal-<version>.dmg` / `.zip` to the release the
first job created, then bumps `tinycast-universal`. macOS 26 is the last release that boots on Intel,
and those Macs need both slices. Both jobs pin `ARCHS` explicitly and assert the slices on _every_
shipping binary — the app, `ClipboardTextHelper`, `FileIndexHelper` and `Tinycast Dictation`:
trusting `ARCHS_STANDARD` is what shipped a thin arm64 build to Intel users once already, and it
also keeps the Apple silicon download from silently gaining a slice it never needs. A thin helper
inside a universal app is the quiet form of the same bug: the app boots on Intel and only clipboard
OCR or dictation stops working.

Both jobs run in the `release` environment, which holds the signing and notary secrets and deploys
from `main` only ([signing.md](signing.md#2-the-release-secrets)). After `verify-signature.sh`,
`Scripts/package-release.sh` packs and signs the DMG, submits it once with `notarytool --wait`, and
staples the ticket to the DMG and to the app before zipping it, so the updater's zip is stapled too.
Any status but `Accepted` prints Apple's log and stops the run before anything is published.
`Scripts/sign-update.swift` then signs the zip, and fails the run if the built app trusts a different
update key. `Scripts/check-update-path.sh` runs just before notarizing, and fails the run unless the
last release on the channel would install this build ([signing.md](signing.md#update-trust)).

Channel builds override `TINYCAST_BUNDLE_IDENTIFIER`, not the target-wide `PRODUCT_BUNDLE_IDENTIFIER`.
The Dictation helper derives its own identifier with a `.dictation` suffix; signature verification
checks that its bundle and signing identifiers agree and remain distinct from the main app.

### Release notes

For upstream releases, `Scripts/release-notes.sh` composes the release body, and CI runs it just
before `gh release create`.
It is safe to run by hand against any tag — it only reads:

```sh
CHANNEL=beta TAG=v0.9.13-beta.61 ./Scripts/release-notes.sh /tmp/body.md /tmp/discord.md
```

The changelog itself comes from GitHub's own release-notes API, which lists every merged PR with its
author and number — so contributors are credited without anyone maintaining a `CHANGELOG.md`, and
without Conventional Commits. **Nothing is ever committed to this repo**: the tag is created
server-side by `gh release create`, and no release, bot or version-bump commit exists.

Two details the script exists for:

- **The previous tag is picked per channel.** Beta and stable tags interleave on `main` — the same
  commit can carry both — so "the previous release" is only ever right within one channel. A stable
  release therefore spans every beta since the last stable.
- **The body is split by `<!-- tinycast:install -->`.** Everything above it is the changelog;
  everything below is the install text, which only a download page needs. The website's changelog
  cuts at that marker in `website/src/lib/changelog.ts`. Full PR URLs are shortened to `#304`, which
  still autolinks on the web.

The Discord announcement carries the same changelog, truncated to fit Discord's component limit, and
pings `@everyone`.

### Homebrew casks

`tinycast` and `tinycast@beta` are in [homebrew/cask](https://github.com/Homebrew/homebrew-cask),
where Homebrew's autobump bot bumps each one after a release.

`tinycast-universal` is the only cask left in the
[`homebrew-tinycast`](https://github.com/abue-ammar/homebrew-tinycast) tap, and the `universal` job
is the only job that touches it: its last step rewrites the cask's `version` + `sha256` and pushes.
The tap's `tap_migrations.json` hands anyone who installed `tinycast` or `tinycast@beta` from the tap
to homebrew/cask on `brew update`.

The step needs a `HOMEBREW_TAP_TOKEN` repo secret — a fine-grained PAT with **Contents: read/write**
on the tap repo. Without the secret the step logs a warning and skips; the release still publishes.
The `sed` is anchored to `^  version` / `^  sha256`, so a cask's two-space indent on those lines is
load-bearing.

Both stable casks install `Tinycast.app` under `com.tinycast.app`, so `tinycast-universal` declares
`conflicts_with cask: "tinycast"`. `tinycast` requires `arch: :arm64`; `tinycast-universal` installs
on any Mac.
