---
title: App launcher
description: Fuzzy search across everything Tinycast knows about, and how results are ranked.
---

The launcher is the root screen. It searches applications, System Settings panes, quicklinks,
snippets, system actions, window commands, custom commands and built-in commands at once.

<kbd>↵</kbd> opens the selection. <kbd>⌘</kbd><kbd>K</kbd> shows everything else you can do with it.

## What an empty query shows

Favorites first, then each category in a fixed order:

Applications → System Settings → Quicklinks → Snippets → System Actions → Window Management →
Custom Commands → Commands

Once you type, that structure collapses into a single **Results** list ordered by relevance.

## How matching works

Tinycast scores each field it knows about, in bands. A hit in a higher band always beats a hit in a
lower one — this is why a two-letter query lands on the app you meant rather than something with
those letters buried in it.

| Band | Field                                           | Matches on                           |
| ---- | ----------------------------------------------- | ------------------------------------ |
| 6    | Your [alias](/docs/launcher/aliases)            | Exact or prefix only                 |
| 5    | Display name, and a snippet's keyword           | Exact, prefix, word-start, substring |
| 4    | Spotlight alternate names; alias substring hits | Literal                              |
| 3    | Display name                                    | Subsequence                          |
| 2    | Spotlight alternate names                       | Subsequence                          |
| 1    | Bundle identifier                               | Literal only                         |
| 0    | Executable name                                 | Literal only                         |

Two rules are worth knowing:

- **Identifier fields never subsequence-match.** Otherwise almost every query would hit almost every
  bundle id.
- **Bundle ids match with the leading component stripped**, so `apple.Photos` works. Pasting the
  full `com.apple.Photos` still matches exactly.

### Spotlight alternate names

Apps also match the names macOS itself knows them by, which is why `iCal` finds Calendar,
`Address Book` finds Contacts, `System Preferences` finds System Settings, and `browser`, `浏览器`
or `사파리` all find Safari.

## Learned ranking

Tinycast learns which result you pick for each query, on device, and floats it up next time.

Selecting a result records **every prefix of what you typed** — choosing WhatsApp for `wha` also
teaches `w` and `wh`, so the app arrives faster each time.

Two things deliberately do not teach it: activating something by its own global hotkey, and picking a
favorite from an empty query. Neither is a search.

The boost reorders within a relevance band. It can never make a weaker match kind beat a stronger
one, so learning cannot make search feel unpredictable.

**Resetting.** One entry: <kbd>⌘</kbd><kbd>K</kbd> → **Reset Ranking**, shown only when that entry
has learned data. Everything: **Settings → General → Search → Reset**.

Learned data stays in `launcher-ranking.json` in Tinycast's own folder and goes nowhere else.

## Search scopes

**Settings → General → Search Scopes** controls which folders are indexed for applications. A scope
is a folder or a single `.app`.

Defaults cover `/Applications`, `/System/Applications`, both `Utilities` folders,
`/System/Library/CoreServices/Applications`, the Cryptex path where Safari actually lives,
`~/Applications`, and Finder as an individual bundle.

Enumeration goes **one subfolder deep**, so
`/Applications/Blackmagic Design/DaVinci Resolve.app` is found without a scope of its own. Anything
nested deeper needs its own scope. `.app` bundles are treated as leaves, never descended into.

Scopes are stored with `~` abbreviated, so a backup taken on one Mac still points somewhere sensible
on another. Editing them re-indexes immediately.

## Actions on an app

Open <kbd>⌘</kbd><kbd>K</kbd> with an application selected:

| Action                                            | Shortcut                             |
| ------------------------------------------------- | ------------------------------------ |
| Open Application                                  | <kbd>↵</kbd>                         |
| Show in Finder                                    | <kbd>⌘</kbd><kbd>↵</kbd>             |
| Add to / Remove from Favorites                    |                                      |
| Quit Application                                  | <kbd>⌃</kbd><kbd>⇧</kbd><kbd>Q</kbd> |
| Reset Ranking                                     |                                      |
| [Uninstall Application](/docs/launcher/uninstall) |                                      |

**Quit Application** appears only while that app is running, and quits it gracefully — an app with
unsaved work still shows you its save sheet. The menu samples "is running" once when it opens, so
the row cannot appear or disappear underneath your cursor.

To quit everything at once, use the **Quit All Applications**
[system action](/docs/launcher/system-actions), which skips Finder and Tinycast itself.

## Per-app hotkeys

Any application can take its own global shortcut, recorded in **Settings → Applications**. Pressing
it toggles that app: focus it if it is not frontmost, hide it if it is.

See [Hotkeys](/docs/reference/hotkeys) for the recorder and the double-tap option.

## Hiding things

**Settings → Applications** has a master **Show in launcher** toggle plus a checkbox per app, so you
can hide the ones you never launch by name without hiding the section.

A hidden row still keeps its shortcut. Hiding changes what search shows, not what works.
