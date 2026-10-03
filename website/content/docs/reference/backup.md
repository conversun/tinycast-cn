---
title: Backup & restore
description: Save your setup to one file, choose what to export and what to import, and what a backup never does.
---

**Settings → Backup**

A backup is a single `.tinycast` file. You choose what goes into it when you export, and separately
choose what to restore when you import. So a backup that contains everything can still restore only
your snippets.

| Category             | What's included                                                                                |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| Settings & Shortcuts | Shortcuts, custom commands, quicklinks, window layouts, rooms, favorites, aliases, preferences |
| Clipboard History    | Text and image clips with their images, and references to copied files                         |
| Snippets             | Your snippet Markdown files                                                                    |
| Notes                | Your note Markdown files                                                                       |
| Launcher Learning    | Your learned launcher ranking, plus emoji and calculator history                               |

The launcher also has **Export Backup** and **Import Backup** commands. They always include
everything, because there's no room for checkboxes in the launcher.

## Read this before relying on it

**The backup format can change between versions of Tinycast. A backup is only guaranteed to import
into the same version that created it.**

The file records which version created it. If your version of Tinycast doesn't recognize the
format, it tells you instead of importing part of the file. Use backups to move your setup to
another Mac or to restore after reinstalling, not as a long-term archive.

## Imports always show what they did

Every import shows a summary of what changed, by category.

If the file contains custom commands, **Tinycast warns you before adding them**, because a file that
adds shell commands without telling you is a security risk.

Imports add to what you have instead of overwriting it. Snippets and notes are added next to your
existing ones, and a note with a name that's already taken gets a number added instead of replacing
yours. Importing the same file twice doesn't create duplicates.

Launcher Learning is the exception. It replaces your existing data, because combining the habits of
two Macs wouldn't match either one.

Copied files in clipboard history are backed up as paths, not file contents. When you import, entries
for files that don't exist on the new Mac are skipped.

## A backup can never turn on a capability

Some switches are never included in a backup, because turning them on means agreeing to something,
not just setting a preference:

- **Snippets**: agreeing to keyword matching
- **Extensions**: agreeing to run third-party code
- **Calendar**: agreeing to let Tinycast read your calendar
- **Auto Join Meetings** and **Camera Preview**: agreeing to open links and turn on the camera
- **Quick Actions**: agreeing to let Tinycast type into other apps
- **AI** and **MCP servers**: agreeing to send text to a model and run server code
- **Search text in images and PDFs**: agreeing to text recognition in the background
- **Fallback order and checkboxes**: these could add a shell command runner to your launcher

This means a backup someone sends you can't turn on keystroke listening, run third-party code, read
your calendar or contact an AI provider. You turn those features on yourself, in the app, after
reading what they do. Importing snippets doesn't turn snippets on.

## Other things that aren't included

| Not included                                                    | Why                                                              |
| --------------------------------------------------------------- | ---------------------------------------------------------------- |
| Extensions: their code, data and sign-ins                       | They're third-party code, and their sign-ins are in the Keychain |
| AI chats, API keys, and all AI and MCP settings                 | Conversations and keys stay on the Mac where they were created   |
| Quick Actions model, prompts, language and custom actions       | An import should never change what a shortcut does to your text  |
| Extension registries, package manager, custom search paths      | They're specific to this Mac, not part of your setup             |
| Palette position, auto-switch input source, calendar checkboxes | They depend on this Mac's displays and hardware                  |
| Cached data, like currency rates and update checks              | Tinycast downloads it again as needed                            |

Clipboard images are stored inside the backup by name, not by their location on your Mac. The only
paths a backup includes are the locations of copied files, because that location is what the entry
records.

**Launch at login** and **Show in menu bar** are read from their current state, so they're restored
the way you had them.

## Where your data is stored

Everything a backup includes is also a regular file in
`~/Library/Application Support/com.tinycast.app/`:

| What                                          | Where                                          |
| --------------------------------------------- | ---------------------------------------------- |
| [Snippets](/docs/features/snippets)           | `Snippets/`                                    |
| [Notes](/docs/features/notes)                 | `Notes/`                                       |
| [Quicklinks](/docs/launcher/quicklinks)       | `quicklinks.sqlite3`, with its own JSON export |
| [Clipboard history](/docs/features/clipboard) | `clipboard.sqlite3`, with images next to it    |
| [AI chats](/docs/ai)                          | `ai-chats.sqlite3`, never included in a backup |

Snippets and notes are plain Markdown files. Copying those folders works as a backup, and you can
read the files without Tinycast.
