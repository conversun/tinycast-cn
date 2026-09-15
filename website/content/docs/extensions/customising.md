---
title: Configuring an extension
description: Preferences, launcher icons, aliases, background refresh, and making an extension feel at home.
---

Open **Settings → Extensions**, find the extension under installed extensions, and choose
**Configure**. From the launcher, <kbd>⌘</kbd><kbd>K</kbd> → **Configure Extension** on any of its
commands goes to the same place.

## Preferences

Whatever settings the extension declares, shown as native controls: checkbox, dropdown, text field,
password field, file picker, folder picker or app picker.

They are saved per extension in Tinycast's own folder, and removed when you uninstall it.

## Launcher icon

Swap an extension's own artwork for an **SF Symbol on a colored tile**, with 18 colors to choose
from, or pick **Use Original** to go back.

The choice applies to **every command** the extension has.

The symbol picker opens on about 85 suggestions, but **search reaches the whole catalog** of roughly
6,500 symbols. It understands Apple's extra search words, so "coffee" finds `cup.and.saucer`.

Symbols Apple reserves for its own products, like iCloud, iPhone and AirPlay, are never offered.

Icon choices **are** included in [backups](/docs/reference/backup).

## Command alias

Each command has an alias field beside its shortcut recorder. Type `si` there, and that command comes
first when you search `si`, just like an [app alias](/docs/launcher/aliases).

The field dims when the command is hidden from launcher search.

## Background refresh

A `no-view` command that declares an `interval`, like `1m` or `12h`, can run on that schedule in the
background. Whatever subtitle it sets shows beside its name in the launcher. Coffee's
**Caffeinate Status**, for example, updates itself every minute.

It is **off** for each command until you run that command once yourself, or turn it on in its
settings. There you can also see when it last refreshed and any error.

In the launcher, a small dot on the row shows refresh is on, and a warning shows if the last run
failed. <kbd>⌘</kbd><kbd>K</kbd> offers **Enable Background Refresh** or
**Disable Background Refresh**, and **Refresh Now**.

To keep it cheap:

- The shortest interval is one minute. Failures wait longer each time, up to a day.
- A background run never interrupts a command you are using.
- A background run shows no toasts, dialogs or windows.

## Uninstalling

Removes the extension and everything attached to it: storage, cache, preferences, its support folder,
Keychain sign-ins, the icon choice, command shortcuts, favorites, hidden items, aliases and learned
ranking.

<kbd>⌘</kbd><kbd>K</kbd> → **Uninstall Extension** in the launcher does the same.
