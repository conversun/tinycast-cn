---
title: Import from Raycast
description: Read a Raycast export and bring your shortcuts, favorites, snippets, quicklinks and history across.
---

Tinycast reads Raycast's own export file directly, in **Settings → Backup → Raycast Export**, or in
the welcome screen the first time you open Tinycast.

It reads the `.rayconfig` file that current Raycast versions export. Older Raycast 1.x exports are no
longer supported.

## Steps

1. In Raycast, export your settings and data, and note the passphrase.
2. In Tinycast, go to **Settings → Backup → Raycast Export** and choose the file.
3. Type the passphrase, tick the things you want, and import.

Tinycast recognizes the file **before** you type the passphrase, so a wrong passphrase is reported as
a wrong passphrase, not as "this is not a Raycast file".

## About that passphrase

**Raycast encrypts the export even if you never set a password.** It makes one up and keeps it in
your login Keychain.

You can see it in **Raycast → Settings → Extensions → Export Settings & Data**, or in Keychain Access
under the service `Raycast` and account `export_passphrase`.

**Tinycast never reads your Keychain.** You paste the passphrase in yourself.

## What comes across

| Category            | Notes                                                      |
| ------------------- | ---------------------------------------------------------- |
| Shortcuts           | App shortcuts, command shortcuts, and your Hyper key setup |
| Favorites           | From Raycast's pinned items                                |
| Aliases             | App aliases                                                |
| Clipboard history   | Text, and images whose files still exist                   |
| Snippets            | Name, text and keyword                                     |
| Quicklinks          | Name, link and the app it opens with                       |
| Emoji skin tone     | Raycast's default becomes Tinycast's Default               |
| Compact mode        | From Raycast's window mode                                 |
| Pop to root         | Only when the timing matches one Tinycast offers           |
| Launch at login     |                                                            |
| Menu bar visibility | From Raycast's menu bar icon setting                       |

The list of apps kept out of clipboard history comes across with Clipboard history.

A shortcut with a modifier Tinycast does not recognize is **skipped whole**, rather than imported as
something slightly different from what you had.

## Clipboard history

Images come across only if their files still exist on this Mac. The summary tells you how many were
missing, rather than dropping them silently.

## Snippets

Snippets are added **in their original order, without overwriting anything you already have**. Ones
that cannot be read are skipped. A name you already use gets a number added, and repeated keywords are
kept as they are.

Imported snippets arrive **switched on and visible in the launcher, with confirmation off**.

**Importing never turns on keyword expansion.** That switch is yours alone; see
[Backup](/docs/reference/backup#a-backup-can-never-grant-a-capability). The summary says so, so a
keyword that does nothing yet does not look broken.

If the snippet files cannot be written, the summary says so, and the other categories still import.

## Quicklinks

Quicklinks are added to your library, never replacing it, and duplicates are skipped just like a
[quicklink import](/docs/launcher/quicklinks#import-and-export). Raycast's `{Query}` becomes
`{argument}`.

Importing at least one quicklink turns the Quicklinks feature on.

## What else you can bring

Two things are not in a `.rayconfig`, so they have their own importers:

- **Extensions.** **Settings → Extensions → Import from Raycast** copies the extensions you have
  installed. See [Installing extensions](/docs/extensions/installing#import-from-raycast).
- **Script commands.** **Settings → Commands → Import Raycast Scripts** turns a folder of scripts into
  custom commands. See [Commands](/docs/launcher/commands#importing-raycast-script-commands).

## Afterwards

There is a **Quit Raycast** button in the pane, for when you are ready.

Nothing in Tinycast needs Raycast to be installed, except importing extensions from it, which by
definition reads its folder.
