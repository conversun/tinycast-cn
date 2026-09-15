---
title: Uninstall an app
description: Remove an app along with the caches, preferences and containers it leaves behind.
---

Dragging an app to the Trash leaves its support files scattered around your Library. Tinycast's
uninstaller finds them and moves them out together.

**Everything goes to the Trash. Nothing is ever deleted.** That one promise is what makes the rest
safe: a wrong guess costs you a drag back, not your data.

## Using it

Select any app in the launcher, press <kbd>⌘</kbd><kbd>K</kbd> and choose **Uninstall Application**.
There is no keyboard shortcut for it. That is on purpose.

A screen opens listing the app and everything that belongs to it, each with a checkbox.

| Action                 | Shortcut                             |
| ---------------------- | ------------------------------------ |
| Uninstall Application  | <kbd>return</kbd>                    |
| Select / Unselect File | <kbd>⌘</kbd><kbd>return</kbd>        |
| Copy Path              | <kbd>⌥</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Show in Finder         | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>O</kbd> |
| Show Info in Finder    | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>I</kbd> |

Click a checkbox or double-click a row to toggle it. The search field filters by name or location.
**Copy Path keeps the screen open**, because losing a whole scan to copy one path would be a bad
trade.

<kbd>return</kbd> always asks for confirmation first. Neither the key nor the menu can skip it.

## How files are matched to the app

Four rules, from most to least certain.

**Bundle identifier.** An exact match, or something inside the app's own name space.
`com.apple.iBooksX.CacheDelete` belongs to `com.apple.iBooksX`, but `com.apple.iBooksXtra` does not.
A dash counts as a separator too, so `dev.zed.Zed-Preview.plist` belongs to Zed, unless Zed Preview
is itself installed, in which case it belongs to Zed Preview. A short vendor name like `com.adobe`
never claims everything under it.

**Group container.** The `group.` prefix and the 10-character team ID are removed, then the rule
above applies.

**Display name.** The weak one. Rows matched this way say **"matched by name"**, so you can see the
weaker evidence before you confirm. The name must match exactly, ignoring case and accents, never as
a prefix or part of a word, so "Books" and "Books Reader" cannot claim each other's folders. It also
needs at least 3 characters, cannot be a standard Library folder name like `Preferences` or
`Caches`, and cannot be shared with another installed app. It is only used in Application Support,
Caches, Logs and plug-in folders.

**Command-line tools** in `/usr/local/bin`, `/opt/homebrew/bin`, `~/.local/bin` and `~/bin` belong to
the app **only if they link into it**, never because of their name.

## What it will not touch

- **Anything sitting directly in your home folder.** VS Code's bundle is literally named `Code`, and
  `~/Code` is someone's source folder on a great many Macs.
- `/private/var/db/receipts`, `~/Library/Keychains` and `/Library/Extensions`
- Any of your document folders
- Anything more than one level deep in a folder it scans
- Tinycast itself

## Locked rows

A locked row can never be checked. From most to least important, a row is locked when it is: missing,
protected by the system, locked by you in Get Info, **in need of Full Disk Access**, in a folder you
cannot write to, or owned by someone else.

Without Full Disk Access, for example, `~/Library/Containers`, `~/Library/Group Containers` and
`~/Library/Cookies` are locked, while `~/Library/Application Scripts` right next to them is not.

Tinycast **checks** for Full Disk Access and **never asks** for it. See
[Permissions](/docs/permissions#full-disk-access).

`/usr/local/bin/code` stays locked because that folder belongs to the system. Removing it would need
an administrator password, and the uninstaller never asks for one.

## Sizes

The list shows up straight away, and sizes fill in afterwards. A row still being measured shows a
blank size rather than a dash or a spinner.

**If you confirm within the first second, the total shown can be lower than what actually goes to the
Trash.** Everything you selected is still moved; only the number was early.

A `≥` in front of a size means measuring stopped at its limit. Sizes match what Finder shows: Xcode
reads 9.45 GB, not the 4.19 GB its compressed files take on disk.

## Running it

If the app is running, it is quit first. Then everything you selected goes to the Trash, with the app
itself last, so if something fails you can run the uninstall again.

The app's shortcut, favorite, visibility and learned ranking are removed **only if the app itself was
removed**. A cleanup of leftovers alone leaves the app and its settings in place.
