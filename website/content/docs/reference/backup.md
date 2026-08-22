---
title: Backup & restore
description: Export your setup to a file, restore it on another Mac, and what a backup deliberately cannot do.
---

**Settings → Backup**

| Action          | Does                                                                     |
| --------------- | ------------------------------------------------------------------------ |
| Export Settings | Saves shortcuts, custom commands, favorites and preferences to JSON      |
| Import Settings | Restores from a Tinycast backup — only values present in the file change |

## Read this before relying on it

**The format is internal and may change between releases. The only guarantee is that export → import
round-trips within one build.**

There is no version field and no migration path. A backup is for moving your setup to another Mac
today, or for restoring after a reinstall — it is not a long-term archive.

## Imports are never silent

An import always reports a summary of what it applied.

A settings file that quietly rewrote your hotkeys would be hostile, so it does not. If the file
contains custom commands, the import **warns before accepting executable content**, because that is
a genuinely different category of risk.

## A backup can never grant a capability

This is the important one.

Two flags are excluded from every export **on purpose**, because each is a consent decision rather
than a preference:

- **`snippetsEnabled`** — enabling snippets is consent to keystroke matching
- **`extensionsEnabled`** — enabling extensions is consent to run third-party code

So importing a backup someone sent you cannot switch on keystroke listening or third-party code
execution. You have to do that yourself, in the app, having read what it says.

## Other deliberate exclusions

| Excluded                                                      | Why                                   |
| ------------------------------------------------------------- | ------------------------------------- |
| Extension registry list, package manager, custom search paths | Describe this machine, not your setup |
| Palette position                                              | Machine-local window geometry         |
| Per-snippet confirmation flags                                | —                                     |

Two values come from outside Tinycast's own settings — **Launch at login** is owned by the system
login item, and **Show in menu bar** is read from the live state — but both are handled correctly.

## Where your data actually lives

Settings backups cover _preferences_. Your content lives as ordinary files:

| What                                          | Where                                                      |
| --------------------------------------------- | ---------------------------------------------------------- |
| [Snippets](/docs/features/snippets)           | `~/Library/Application Support/com.tinycast.app/Snippets/` |
| [Notes](/docs/features/notes)                 | `.../Notes/`                                               |
| [Quicklinks](/docs/launcher/quicklinks)       | `.../quicklinks.sqlite3` — and it has its own JSON export  |
| [Clipboard history](/docs/features/clipboard) | `~/Library/Caches/com.tinycast.app/`                       |

Snippets and notes are plain Markdown. Copying those folders is a perfectly good backup, and they
are readable without Tinycast — which is the point of storing them that way.
