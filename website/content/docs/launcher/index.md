---
title: App launcher
description: One search across everything Tinycast knows about, and how it decides what comes first.
---

The launcher is the root screen. One search covers your apps, System Settings panes, commands,
quicklinks, snippets, system actions, window commands and layouts, custom commands, Quick Actions,
extension commands and upcoming meetings.

<kbd>return</kbd> opens what is selected. <kbd>⌘</kbd><kbd>K</kbd> shows everything else you can do with it.

## With nothing typed

[Favorites](/docs/launcher/favorites) come first, then each section in this order:

Meetings → Applications → System Settings → Extensions → Quicklinks → Snippets → System Actions →
Window Layouts → Window Management → Custom Commands → Quick Actions → Commands

Each section is in alphabetical order, and stays that way. A list that reorders itself as you use it
is hard to scan.

When a meeting is about to start, a [join card](/docs/features/calendar#the-join-card) sits above
everything.

## When you type

The sections fold into one **Results** list, ordered by how well each entry matches. A few things can
appear around it:

- **A calculator card** at the top when your text is a
  [calculation](/docs/features/calculator), like `12% of 80` or `time in Tokyo`.
- **A color card** when you paste a color like `#FF5733`.
- **Open in Browser** at the top when you type a web address or a bare domain, like `github.com`.
- **"Use … with"** rows at the bottom, which send your text somewhere else. See
  [Fallbacks](/docs/launcher/fallbacks).

### Listing a whole category

Type a section's exact name, like `Snippets`, `Snippet` or `Window Management`, and you get that
whole category under its own heading.

It has to be the exact name. An app whose name is exactly your text still shows too, which is why
typing `System Settings` lists both the app and its panes.

## How matching works

Tinycast looks at several names for each entry, and trusts some more than others:

| Name                                  | Example                                 |
| ------------------------------------- | --------------------------------------- |
| Your [alias](/docs/launcher/aliases)  | `ps` for Photoshop                      |
| The display name                      | `Visual Studio Code`                    |
| Other names the app is known by       | `iCal` for Calendar, `微信` as `weixin` |
| The extension a command comes from    | `lucide` for Lucide's Search Icons      |
| The bundle identifier or program name | `apple.Photos`                          |

How the letters match matters too: an exact match beats one at the start, which beats one at the
start of a word, which beats one in the middle, which beats scattered letters.

**One rule never bends: typing a name or alias exactly always wins**, however often you picked
something else. Everything below that can move with [learned ranking](#learned-ranking).

A few details keep results sensible:

- **Bundle identifiers only match as typed**, never by scattered letters. Otherwise almost any short
  search would hit almost every app. They also match without the leading `com.`, so `apple.Photos`
  works, while pasting the full `com.apple.Photos` still finds it.
- **An extension's name ranks low.** An extension called `Safari` can never take that search from the
  real Safari.

### Names in your language

Apps are shown the way Finder shows them, in your Mac's language. The English name still works, so
on a Portuguese Mac both `Find My` and `Buscar` find the same app.

Apps also match the other names macOS knows them by: `Address Book` finds Contacts,
`System Preferences` finds System Settings, and `browser`, `浏览器` or `사파리` all find Safari.

Names in other scripts get a Latin spelling too: `微信` answers to `weixin` and `wx`, `メモ帳` to
`memo`, and `Яндекс` to `yandeks`.

If you renamed an app in Finder, both the old and the new name find it.

## Learned ranking

Tinycast learns which result you pick for a search, on your Mac, and moves it up next time.

Pick WhatsApp after typing `wha`, and it also comes up sooner for `w` and `wh`. The more often and
more recently you pick something, the stronger the boost.

These do not teach it, because none of them is a search: opening something with its own shortcut,
launching a favorite with <kbd>⌘</kbd> and a number, listing a category, and Open in Browser.

**Resetting.** For one entry: <kbd>⌘</kbd><kbd>K</kbd> → **Reset Ranking**, shown only when that entry
has learned something. For everything: **Settings → General → Learned ranking → Reset**.

What it learns stays in `launcher-ranking.json` in Tinycast's own folder and goes nowhere else.

## Search scopes

**Settings → Applications → Search Scopes** decides which folders are searched for apps. A scope can
be a folder or a single `.app`.

The defaults cover `/Applications`, `/System/Applications`, both `Utilities` folders,
`/System/Library/CoreServices/Applications`, the hidden system folder where Safari really lives,
`~/Applications`, and Finder on its own.

Tinycast looks **one folder deep**, so `/Applications/Blackmagic Design/DaVinci Resolve.app` is found
without its own scope. Anything deeper needs a scope of its own. It never looks inside an app bundle.

Scopes are saved with `~` shortened, so a backup still makes sense on another Mac. Changing them
searches again straight away.

## Actions on an app

Open <kbd>⌘</kbd><kbd>K</kbd> with an app selected:

| Action                                            | Shortcut                                            |
| ------------------------------------------------- | --------------------------------------------------- |
| Open Application                                  | <kbd>return</kbd>                                   |
| Show in Finder                                    | <kbd>⌘</kbd><kbd>return</kbd>                       |
| Add to / Remove from Favorites                    | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>F</kbd>                |
| Move Favorite Up / Down                           | <kbd>⌥</kbd><kbd>⌘</kbd><kbd>↑</kbd> / <kbd>↓</kbd> |
| Reset Ranking                                     |                                                     |
| Hide from Search                                  | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>H</kbd>                |
| Restart Application                               | <kbd>⌘</kbd><kbd>R</kbd>                            |
| Quit Application                                  | <kbd>⌃</kbd><kbd>⇧</kbd><kbd>Q</kbd>                |
| [Uninstall Application](/docs/launcher/uninstall) |                                                     |

**Restart Application** and **Quit Application** only appear while the app is running. Both quit
politely, so an app with unsaved work still asks you to save. Restart waits up to five seconds for
the app to quit, then opens it again. If the app refuses to quit, nothing is reopened.

To quit everything at once, use the **Quit All Applications**
[system action](/docs/launcher/system-actions). It leaves Finder and Tinycast running.

## Hiding a result

<kbd>⇧</kbd><kbd>⌘</kbd><kbd>H</kbd> (**Hide from Search**) takes the selected entry out of search
results. The palette stays open on the same search.

It works for apps, System Settings panes, commands, Quick Actions, system actions, window commands
and window layouts. To bring one back, tick its checkbox again in that Settings pane.

Hiding only changes what search shows. The app stays installed, and its favorite, alias, learned
ranking and shortcut all keep working.

## Per-app shortcuts

Any app can have its own global shortcut, set in **Settings → Applications**. Press it to bring the
app to the front; press it again while the app is in front to hide it.

See [Hotkeys](/docs/reference/hotkeys) for recording shortcuts and the double-tap option.

## Switching a whole section off

**Settings → Applications** has **Enable Applications**, plus a checkbox per app.

- **Enable Applications** off takes every app out of search **and** turns off every per-app shortcut.
- A single app's checkbox only hides that one row. Its shortcut keeps working.

System Settings, System Actions and Commands each have the same kind of switch in their own pane.
