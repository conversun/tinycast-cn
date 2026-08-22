---
title: Notes
description: Plain Markdown files in one floating editor — no database, no frontmatter, no sidecar.
---

Notes is an unlimited local collection of Markdown files in a single floating window.

**Settings → Notes** holds the feature switch. It ships **off**, and enabling it alone does not
create the folder or write anything.

## Commands

Three commands, each with its own optional global shortcut:

| Command          | Does                                                         |
| ---------------- | ------------------------------------------------------------ |
| **Show Notes**   | Selects the last active note and shows or focuses the window |
| **Create Note**  | Creates and selects one new Untitled note                    |
| **Search Notes** | Shows the window with the switcher open and focused          |

**Show Notes does not toggle the window closed.** Show means show.

## In the window

| Key                      | Does                                    |
| ------------------------ | --------------------------------------- |
| <kbd>⌘</kbd><kbd>N</kbd> | Create a note                           |
| <kbd>⌘</kbd><kbd>P</kbd> | Open or refocus the switcher            |
| <kbd>⌘</kbd><kbd>O</kbd> | Open the Notes folder in Finder         |
| <kbd>⌘</kbd><kbd>W</kbd> | Hide the window                         |
| <kbd>⎋</kbd>             | Close the switcher, then hide           |
| <kbd>⌘</kbd><kbd>⌫</kbd> | Move the selected switcher row to Trash |

<kbd>⌘</kbd><kbd>Q</kbd> is bound to nothing app-wide, so **no chord over Notes can quit Tinycast**.

## Files

Notes live in Tinycast's Application Support folder, one per note:

```
~/Library/Application Support/com.tinycast.app/Notes/
```

**One regular `.md` file is one note, and its filename without the extension is its title.** There is
no frontmatter, no embedded ID, no database and no sidecar file. What you see is the file.

Immediate children only — subfolders, hidden files and symlinks are ignored. Sorted by modification
date, then title.

New notes are `Untitled.md`, then `Untitled 2.md`, and so on. Name collisions are case- and
diacritic-insensitive, so `plán` beside `Plan` becomes `plán 2.md` — but a note never collides with
itself, so you can rename one to change only its case or accents.

Renaming a note changes its identity, since the filename _is_ the identity. There are no per-note
hotkeys or favorites that could point at the old one.

## The editor

One plain text view. **Markdown markers stay visible — there is no syntax highlighting, no rendered
preview and no link behaviour.** The string on screen, in search, and in the file are identical.

AppKit owns typing, selection, cut/copy/paste, Find, marked text, emoji, combining characters and
undo. An empty note shows a `Start writing…` placeholder, and the footer counts characters.

## The switcher

An empty query lists notes by recency, reading metadata only. A query searches titles and literal
bodies after a 120 ms pause, capped at **200** results.

Rows expose VoiceOver actions to activate, rename and trash by the real note title.

## Saving, and the one real caveat

Edits save automatically after a 300 ms pause.

**A save overwrites whatever is on disk.** There is no file watcher and no revision check, so if you
edit the _currently active_ note in another app while Tinycast has it open, that edit is lost on the
next autosave.

<kbd>⌘</kbd><kbd>O</kbd> invites exactly this, and it is the accepted trade for having no database.

Every _other_ external change is picked up fine, because showing the window re-lists the folder
first — a note added or edited outside Tinycast appears as expected.

Quitting waits for the save to flush, but never blocks the quit.

## The window

You own the size; macOS remembers it. The collection may be empty — deleting the last note is
allowed, and Create Note still works from the empty state.

Hiding the window restores the app you came from, but only while that app is still frontmost. Closing
a window you already walked away from leaves you where you are.
