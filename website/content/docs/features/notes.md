---
title: Notes
description: Plain Markdown files in one floating editor. No database, no frontmatter, no sidecar files.
---

Notes is a collection of plain Markdown files, as many as you like, edited in one floating window.

**Settings → Notes** holds the switch. It ships **off**, and turning it on does not create the folder
or write anything until you make a note.

## Commands

Three commands, each with its own optional global shortcut in **Settings → Notes**:

| Command          | Does                                                     |
| ---------------- | -------------------------------------------------------- |
| **Show Notes**   | Opens your last note. Press it again to hide the window. |
| **Create Note**  | Makes a new Untitled note and opens it                   |
| **Search Notes** | Opens the window with the note switcher ready to type in |

## In the window

The title bar holds three buttons: **Create**, **Browse** and **Open Folder**.

| Key                           | Does                                        |
| ----------------------------- | ------------------------------------------- |
| <kbd>⌘</kbd><kbd>N</kbd>      | Create a note                               |
| <kbd>⌘</kbd><kbd>P</kbd>      | Open the switcher, or jump back into it     |
| <kbd>⌘</kbd><kbd>O</kbd>      | Open the Notes folder in Finder             |
| <kbd>⌘</kbd><kbd>W</kbd>      | Hide the window                             |
| <kbd>esc</kbd>                | Close the switcher, then hide the window    |
| <kbd>⌘</kbd><kbd>delete</kbd> | Move the selected switcher row to the Trash |

<kbd>⌘</kbd><kbd>Q</kbd> does nothing here, so **no key press over Notes can quit Tinycast** by
accident.

## Files

Notes live in Tinycast's Application Support folder:

```
~/Library/Application Support/com.tinycast.app/Notes/
```

**One `.md` file is one note, and its file name is its title.** There is no frontmatter, no hidden
ID, no database and no sidecar file. What you see is the file.

Only files directly in that folder count. Subfolders, hidden files and links are ignored. Notes are
sorted by when they changed, newest first.

New notes are named `Untitled.md`, then `Untitled 2.md`, and so on. **Until you rename one, it shows
its first line as the title**, so a list of Untitled notes is still easy to scan. Heading marks like
`#` are dropped from that title.

Names are compared without case or accents, so `plán` next to `Plan` becomes `plán 2.md`. A note
never clashes with itself, so you can rename one just to change its case or accents.

## The editor

One plain text view. **Markdown marks stay visible.** There is no syntax coloring, no rendered
preview and no clickable links. The text on screen, in search and in the file is exactly the same.

Typing, selection, copy and paste, Find, emoji, input methods and undo all behave like any Mac text
field. An empty note shows **Start writing…**, and the footer counts characters.

[Snippets](/docs/features/snippets) expand right into the editor, and undo takes them back.

## The switcher

The switcher drops down from the title bar. With nothing typed, it lists notes by recency. Type and
it searches titles and note text, after a 120 ms pause, showing up to **200** results.

Each row offers VoiceOver actions to open, rename and move that note to the Trash.

## Saving, and the one real caveat

Changes save automatically 300 ms after you stop typing.

**A save overwrites whatever is on disk.** Tinycast does not watch the folder. If you edit the note
that is _open in Tinycast_ in another app, that edit is lost at the next autosave.

<kbd>⌘</kbd><kbd>O</kbd> invites exactly this, and it is the trade for having no database.

Every _other_ change from outside is picked up, because showing the window reads the folder again
first. A note you add or edit elsewhere shows up as expected.

Quitting waits for the last save, but never blocks the quit.

## The window

You choose the size, and macOS remembers it. You can delete every note; the window shows an empty
state and Create Note still works.

Hiding the window takes you back to the app you came from, but only if that app is still in front.
If you already moved on, you stay where you are.
