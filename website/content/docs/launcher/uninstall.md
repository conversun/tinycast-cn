---
title: Uninstall an app
description: Remove an app along with the caches, preferences and containers it leaves behind.
---

When you drag an app to the Trash, its support files stay behind in your Library folder. Tinycast's
uninstaller finds those files and removes them along with the app.

**Everything is moved to the Trash, and nothing is deleted permanently.** If the uninstaller picks
the wrong file, you can drag it back.

## Using it

Select an app in the launcher, press <kbd>⌘</kbd><kbd>K</kbd> and choose **Uninstall Application**.
There's no keyboard shortcut for it, so you can't start it by accident.

A screen opens listing the app and every file that belongs to it, each with a checkbox.

| Action                 | Shortcut                             |
| ---------------------- | ------------------------------------ |
| Uninstall Application  | <kbd>return</kbd>                    |
| Select / Unselect File | <kbd>⌘</kbd><kbd>return</kbd>        |
| Copy Path              | <kbd>⌥</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Show in Finder         | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>O</kbd> |
| Show Info in Finder    | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>I</kbd> |

Click a checkbox or double-click a row to select or deselect it. The search field filters by name or
location. **Copy Path keeps the screen open**, so you don't have to scan again.

<kbd>return</kbd> always asks you to confirm first, whether you use the key or the menu.

## How files are matched to the app

Tinycast uses four rules, from most to least certain.

**Bundle identifier.** An exact match, or a name inside the app's own namespace.
`com.apple.iBooksX.CacheDelete` belongs to `com.apple.iBooksX`, but `com.apple.iBooksXtra` doesn't.
A dash also counts as a separator, so `dev.zed.Zed-Preview.plist` belongs to Zed, unless Zed Preview
is also installed, in which case it belongs to Zed Preview. A short vendor prefix like `com.adobe`
never claims everything under it.

**Group container.** Tinycast removes the `group.` prefix and the 10-character team ID, then applies
the rule above.

**Display name.** This is the weakest rule, so rows matched this way are labeled
**"matched by name"** and you can check them before you confirm. The name must match exactly,
ignoring case and accents, and never as a prefix or part of a word, so "Books" and "Books Reader"
can't claim each other's folders. The name also needs at least 3 characters, can't be a standard
Library folder name like `Preferences` or `Caches`, and can't be shared with another installed app.
This rule only applies in Application Support, Caches, Logs and plug-in folders.

**Command-line tools** in `/usr/local/bin`, `/opt/homebrew/bin`, `~/.local/bin` and `~/bin` belong
to the app **only if they link into the app bundle**, never because of their name.

## What it never touches

- **Anything directly in your home folder.** For example, VS Code's bundle is named `Code`, and
  many people keep their source code in `~/Code`.
- `/private/var/db/receipts`, `~/Library/Keychains` and `/Library/Extensions`
- Any of your document folders
- Anything more than one level deep in a folder it scans
- Tinycast itself

## Locked rows

You can't select a locked row. From most to least important, a row is locked when the file is
missing, protected by the system, locked by you in Get Info, **only accessible with Full Disk
Access**, in a folder you can't write to, or owned by another user.

For example, without Full Disk Access, `~/Library/Containers`, `~/Library/Group Containers` and
`~/Library/Cookies` are locked, but `~/Library/Application Scripts` next to them isn't.

Tinycast **checks** whether it has Full Disk Access but **never asks** for it. See
[Permissions](/docs/permissions#full-disk-access).

`/usr/local/bin/code` stays locked because that folder belongs to the system. Removing it would
require an administrator password, and the uninstaller never asks for one.

## Sizes

The list appears right away, and sizes fill in afterward. A row that's still being measured shows a
blank size.

**If you confirm within the first second, the total shown can be lower than what actually moves to
the Trash.** Everything you selected is still moved; the number just wasn't finished yet.

A `≥` before a size means measuring stopped at its limit. Sizes match what Finder shows, so Xcode
shows 9.45 GB, not the 4.19 GB its compressed files use on disk.

## Running it

If the app is running, Tinycast quits it first. Then everything you selected moves to the Trash, with
the app itself last, so if something fails you can run the uninstaller again.

The app's shortcut, favorite, visibility and learned ranking are removed **only if the app itself
was removed**. If you only cleaned up leftover files, the app and its settings stay.
