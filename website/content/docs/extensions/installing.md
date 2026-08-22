---
title: Installing extensions
description: Three routes in, the registries behind them, and when you need a toolchain.
---

**Settings → Extensions → Install** offers three routes.

## Search Registries

Searches every enabled registry and installs from any of them. This is the normal route.

## Import from Raycast

Copies extensions you already have out of a local Raycast install.

**Nothing is compiled. No Node, no package manager and no network are involved** — the bundles are
already built.

Both channels are scanned (`~/.config/raycast` and `~/.config/raycast-x`), and an extension present
in both is offered once. There is an **Import All**, and the pane rescans whenever you open it and
tells you when Raycast has something Tinycast does not.

## Add Folder

Point at any directory containing a manifest and built command files — a project you have just built
locally, for instance.

Only `package.json`, the built commands and `assets/` are copied. Never `node_modules`, never source
maps.

## Registries

Two ship enabled, and you can add your own.

|        | Raycast Store           | A GitHub repository         |
| ------ | ----------------------- | --------------------------- |
| Serves | An already-built bundle | Source                      |
| Needs  | Nothing                 | Node, and a package manager |

**The store is the reason most people need no toolchain at all.** It serves what was already built.

A GitHub registry is any repo laid out with one folder per extension. Add one with `owner/repo` or a
link to the folder. Only the extension's own folder is ever fetched, never the whole repo.

Source installs run `<package manager> install --ignore-scripts` and then build.
**Lifecycle scripts are skipped on purpose.** An extension that does not compile fails at the build
step rather than silently installing broken.

## Package managers

**Settings → Extensions → Package manager**

**Automatic** (default) takes the first of **pnpm → Bun → Yarn → npm** that is installed. The order
puts the fastest and most disk-frugal first, with npm last as the one that is always there.

Because a GUI app inherits no login-shell `PATH`, Tinycast looks in known locations itself: Homebrew,
Volta, asdf, mise, fnm, nvm and Yarn. The pane shows what it found — "Found pnpm at
/opt/homebrew/bin/pnpm" — or tells you nothing is installed.

### Custom search paths

For anything outside that list — Nix, in particular — the Registries sheet has **Custom search
paths**: a colon-separated list, like `PATH`, checked **before** the built-in locations.

```
~/.local/share/mise/shims
```

```
/etc/profiles/per-user/you/home-path/bin
```

Set once, applied to every future install.

## What is not backed up

Three things are deliberately excluded from
[settings backups](/docs/reference/backup), because they describe _this machine_:

- The registry list
- The package manager choice
- Custom search paths

## Storage

Everything lives under Tinycast's Application Support folder, and **uninstalling an extension removes
all of it**: the extension itself, its local storage and cache, its preferences, its support folder,
its icon override, its command shortcuts, favorites and learned ranking.

**Settings → Extensions → Storage** measures leftover build workspaces — the kind a crashed install
can leave — and offers to clean them up. It sits outside the enabled group deliberately, and is empty
in normal use.

Nothing ever touches your own `~/Library/pnpm` or `~/.npm`.
