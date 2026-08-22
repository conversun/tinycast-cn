---
title: Import from Raycast
description: Read a .rayconfig export and bring your shortcuts, favorites, snippets and history across.
---

Tinycast reads Raycast's own export file directly. **Settings → Backup**.

Both generations are supported: **v1** (Raycast 1.x) and **v2** (Raycast X).

## Steps

1. In Raycast: **Settings → Advanced → Export**, and note the passphrase.
2. In Tinycast: **Settings → Backup → Raycast Export → Choose…**
3. Enter the passphrase, pick the categories you want, and import.

**The format is detected without the passphrase**, so as soon as you choose a file the row is
labelled and any categories that format cannot carry are disabled. You know what you are getting
before you type anything.

The two formats share no code path, so a wrong passphrase reports **a wrong passphrase** rather than
"not a Raycast file".

## About that passphrase

**Raycast encrypts the export even if you never chose a password.** It generates one and stores it in
your login keychain.

Find it at **Raycast → Settings → Extensions → Export Settings & Data**, or in Keychain Access under
service `Raycast`, account `export_passphrase`.

**Tinycast never reads your keychain.** You paste the passphrase in yourself.

## What comes across

| Category            | Notes                                                |
| ------------------- | ---------------------------------------------------- |
| Shortcuts           | App hotkeys, and the clipboard/emoji command hotkeys |
| Favorites           | From Raycast's pinned items                          |
| Clipboard history   |                                                      |
| Snippets            | Name, text and keyword                               |
| Aliases             | **v2 only**                                          |
| Emoji skin tone     | Raycast's `default` becomes none                     |
| Compact mode        | From Raycast's preferred window mode                 |
| Pop to root         | Exact matches only                                   |
| Launch at login     | **v2 only**                                          |
| Menu-bar visibility | From Raycast's status-bar setting                    |

Also carried: the list of apps excluded from clipboard capture.

## v1 limitations

Raycast 1.x exports do not contain everything, so these are simply absent:

- **No launch-at-login preference**
- **No global palette hotkey** — you record your own
- **No aliases**

An unrecognised modifier **rejects the whole shortcut** rather than importing a weaker version of it,
so you never end up with a chord that is subtly not what you had.

Only image clipboard records become image clips; a file record's label imports as text.

## Snippets

Snippets are a separately selectable category.

Valid entries are added **in source order without overwriting your existing library**. Invalid ones
are skipped. Duplicate names get a filename suffix, and duplicate keywords are preserved rather than
silently merged.

Imported snippets arrive **enabled and visible in the launcher, with confirmation off**.

**Importing never enables automatic keyword expansion.** That switch is yours alone — see
[Backup](/docs/reference/backup#a-backup-can-never-grant-a-capability).

A file-write failure is reported in the summary without aborting the settings and clipboard
categories.

## Afterwards

There is a **Quit Raycast** button in the pane, for when you are ready.

Nothing in Tinycast depends on Raycast being installed — except
[importing extensions from a local Raycast](/docs/extensions/installing#import-from-raycast), which
by definition reads its folder.
