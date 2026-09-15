---
title: Installing extensions
description: Three ways in, the registries behind them, and when you need a toolchain.
---

**Settings → Extensions → Install** offers three ways in.

## Search Registries

Searches every enabled registry, and installs from any of them. This is the usual way.

## Import from Raycast

Copies extensions you already have out of Raycast on this Mac.

**Nothing is built. No Node, no package manager and no network are needed**, because the extensions
are already built.

Tinycast looks in both `~/.config/raycast` and `~/.config/raycast-x`, and an extension found in both
is offered once. There is an **Import All** button. The pane checks again whenever you open it, and
tells you when Raycast has something Tinycast does not.

## Add from folder

Point at any folder with a manifest and built command files, like a project you just built yourself.

Only `package.json`, the built commands and `assets/` are copied. Never `node_modules`, and never
source maps.

## Registries

Two come switched on, and you can add your own.

|           | Raycast Store              | A GitHub repository        |
| --------- | -------------------------- | -------------------------- |
| Gives you | An extension already built | Source code                |
| You need  | Nothing                    | Node and a package manager |

**The store is why most people need no toolchain at all.** It hands over what was already built.

A GitHub registry is any repository with one folder per extension, like `raycast/extensions`. Add one
with `owner/repo` or a link to the folder. Only the extension's own folder is downloaded, never the
whole repository.

Installing from source runs `<package manager> install --ignore-scripts`, then builds the extension.
**Install scripts are skipped on purpose**, because that is code nobody asked to run. An extension
that does not build fails at the build step, instead of installing half-broken.

## Package managers

**Settings → Extensions → Package manager**

**Automatic** (default) uses the first of **pnpm → Bun → Yarn → npm** that you have. The fastest and
most disk-friendly come first, and npm, which is nearly always there, comes last.

An app opened from the Dock does not see your terminal's `PATH`, so Tinycast looks in the usual places
itself: Homebrew, Volta, asdf, mise, fnm, nvm and Yarn. The pane shows what it found, like
"Found pnpm at /opt/homebrew/bin/pnpm", or tells you nothing is installed.

### Custom search paths

For anything outside that list, like Nix, the Registries sheet has **Custom search paths**: a list of
folders separated by colons, like `PATH`, checked **before** the usual places.

```
~/.local/share/mise/shims
```

```
/etc/profiles/per-user/you/home-path/bin
```

Set it once and every future install uses it.

## What is not backed up

Three things are left out of [backups](/docs/reference/backup) on purpose, because they describe
_this Mac_:

- The registry list
- The package manager choice
- Custom search paths

## Storage

Everything lives in Tinycast's Application Support folder, and **uninstalling an extension removes
all of it**: the extension, its storage and cache, its preferences, its support folder, its sign-ins
in the Keychain, its icon choice, its command shortcuts, favorites, aliases and learned ranking.

**Settings → Extensions → Storage** measures leftover build folders, the kind a crashed install can
leave behind, and offers to clean them up. It works even while extensions are off, and it is empty in
normal use.

Nothing ever touches your own `~/Library/pnpm` or `~/.npm`.
