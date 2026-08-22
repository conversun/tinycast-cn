---
title: Uninstall an app
description: Remove an application and the caches, preferences and containers it leaves behind.
---

Dragging an app to the Trash leaves its support files scattered across your Library. Tinycast's
uninstaller finds them and moves them out together.

**Everything goes to the Trash. Nothing is ever deleted.** That single guarantee is what makes the
rest of the design acceptable — a wrong guess costs you a drag back, not your data.

## Using it

Select any application in the launcher, press <kbd>⌘</kbd><kbd>K</kbd> and choose
**Uninstall Application**. There is no keyboard shortcut for it; this is a menu action on purpose.

A screen opens listing the app and everything attributed to it, each with a checkbox.

| Action                     | Shortcut                             |
| -------------------------- | ------------------------------------ |
| Uninstall                  | <kbd>↵</kbd>                         |
| Toggle the highlighted row | <kbd>⌘</kbd><kbd>↵</kbd>             |
| Copy Path                  | <kbd>⌥</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Show in Finder             | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>O</kbd> |
| Show Info in Finder        | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>I</kbd> |

Clicking a checkbox toggles it, and so does double-clicking a row. The search field filters by name
or location. **Copy Path stays on the screen** — losing a whole scan to copy one path would be a bad
trade.

<kbd>↵</kbd> always goes through the confirmation. Neither the key nor the menu row can skip it.

## How files are attributed

Four rules, in descending order of confidence.

**Bundle identifier** — exact, or a descendant of the namespace.
`com.apple.iBooksX.CacheDelete` belongs to `com.apple.iBooksX`; `com.apple.iBooksXtra` does not.
Both `.` and `-` count as separators, so `dev.zed.Zed-Preview.plist` belongs to Zed — unless Zed
Preview is itself installed, in which case that sibling owns it. A two-component vendor namespace
like `com.adobe` never prefix-matches.

**Group container** — strips a leading `group.` and a 10-character Team ID, then applies the bundle
rule.

**Display name** — the weak one. Rows matched this way are labelled **"matched by name"** so you can
see the weaker evidence before confirming. It requires exact, case- and diacritic-folded equality —
never a prefix or substring, so "Books" and "Books Reader" cannot claim each other. It also needs at
least 3 characters, must not be a standard Library folder name like `Preferences` or `Caches`, and
must not be shared with another installed app. It is only used in Application Support, Caches, Logs
and the plug-in folders.

**Command-line launchers** in `/usr/local/bin`, `/opt/homebrew/bin`, `~/.local/bin` and `~/bin` are
attributed **by symlink target**, never by name.

## What it will not touch

- **Your home folder is never a root.** Nothing sitting directly in `~` is ever a candidate. VS
  Code's bundle is literally named `Code`, and `~/Code` is a source tree on a great many Macs.
- `/private/var/db/receipts`, `~/Library/Keychains`, `/Library/Extensions`
- Every user-document location
- Anything more than one level deep in a scanned folder
- Tinycast itself, including the Dev channel refusing itself

## Locked rows

A locked row can never be checked. In order of precedence: missing → system-protected → locked by you
(clearable in Get Info) → **needs Full Disk Access** → parent folder not writable → not owned by you.

Concretely, without Full Disk Access, `~/Library/Containers`, `~/Library/Group Containers` and
`~/Library/Cookies` refuse — while `~/Library/Application Scripts` and
`~/Library/Autosave Information` beside them do not.

Tinycast **detects** Full Disk Access and **never asks for it**. See
[Permissions](/docs/permissions#full-disk-access).

`/usr/local/bin/code` stays locked because the folder is root-owned. Removing it would need an
administrator password, and this feature never asks for one.

## Sizes

The list appears immediately and sizes fill in behind it. A row still being measured shows a blank
size slot rather than a dash or a spinner.

**If you confirm within the first second, the total shown is lower than what actually gets trashed.**
Everything you selected is still trashed — only the number was early.

A `≥` prefix means the size walk hit its budget. Sizes are logical bytes, matching what Finder
reports: Xcode reads 9.45 GB, not the 4.19 GB that allocated blocks would show.

## Running it

The app is quit first if it is running, then everything selected is trashed, bundle last so a partial
failure can be retried.

The app's hotkey, favorite, visibility and learned ranking are cleared **only if the bundle itself
went**. A leftovers-only cleanup leaves the app, and its settings, installed.
