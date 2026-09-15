---
title: Clipboard history
description: Text, images, files and colors you copied, searchable and pasted back where you came from.
---

Tinycast keeps what you copy, so you can find it again and paste it back into the app you were
using.

Clipboard history is the one feature that ships **on**. **Settings → Clipboard → Enable Clipboard
History** turns it off. Off means off: nothing is recorded, the history file closes, and the
Clipboard History command and its shortcut go away. What you already saved stays, and
**Clear history** still works while it is off.

## Opening it

- <kbd>tab</kbd> from the launcher (after AI Chat, if AI is on).
- The **Clipboard History** command, or its global shortcut in **Settings → Clipboard**.
- **Clipboard History** in the Tinycast menu bar menu.

The footer names where a paste will land, like "Paste to Notes", so you always know the target.

## Actions

| Action                     | Shortcut                                            |
| -------------------------- | --------------------------------------------------- |
| Paste                      | <kbd>return</kbd>                                   |
| Copy to Clipboard          | <kbd>⌘</kbd><kbd>return</kbd>                       |
| Paste and Keep Window Open | <kbd>⌥</kbd><kbd>return</kbd>                       |
| Filter by type             | <kbd>⌘</kbd><kbd>P</kbd>                            |
| Pin / Unpin Entry          | <kbd>⌘</kbd><kbd>.</kbd>                            |
| Paste a pinned entry       | <kbd>⌘</kbd><kbd>1</kbd> … <kbd>⌘</kbd><kbd>0</kbd> |
| Delete Entry               | <kbd>⌃</kbd><kbd>X</kbd>                            |
| Delete All Entries         | <kbd>⌃</kbd><kbd>⇧</kbd><kbd>X</kbd>                |

**Default action** in Settings swaps <kbd>return</kbd> and <kbd>⌘</kbd><kbd>return</kbd>. Set it to
**Copy to Clipboard** and <kbd>return</kbd> copies while <kbd>⌘</kbd><kbd>return</kbd> pastes. Double-click and
the number shortcuts follow the same choice. <kbd>⌥</kbd><kbd>return</kbd> always pastes.

Pasting needs the [Accessibility permission](/docs/permissions).

**Drag any row out** into another app. It is always a copy, so the entry stays in your history. When
the drop lands, the palette closes, just like a paste.

## What it keeps

- **Text**, with a preview.
- **Images**, like screenshots, stored as PNG files.
- **Files you copy in Finder.** Tinycast saves a reference to the file where it is, never a copy. Up
  to 32 files per copy are recorded. Pasting gives apps the file itself, and gives text fields its
  path.
- **Colors.** A copied `#FF5733`, `rgb(…)` or `hsl(…)` shows as a swatch.

A file that has since been moved or deleted stays in history, because where it was is still useful.
Pasting it shows a message instead of failing silently. For a file entry, <kbd>⌘</kbd><kbd>K</kbd>
also offers **Show in Finder**, **Open** and **Copy Path**.

Video and audio files can be played in the preview. Nothing plays until you press play.

## Filtering by type

<kbd>⌘</kbd><kbd>P</kbd> opens a filter at the right of the search field. Seven choices, and each
entry belongs to exactly one:

**All Types** · **Text Only** · **Images Only** · **Files Only** · **Colors Only** · **Links Only** ·
**Emails Only**

A copied URL is a link, not a kind of text, so _Text Only_ means prose. A color is not text either.

Each filter has its own empty message, so "Clipboard history is empty" never shows over a history
that only looks empty because of a filter. The filter stays available on an empty list, so you can
always switch back.

Links and emails are worked out from the text each time, never stored. Anything over 2,048 bytes, or
with a space in it, counts as plain text. A bare domain must be lower case and end in a common
ending, so `Safari.app`, `report.pdf` and `index.html` stay text.

## Pinning

<kbd>⌘</kbd><kbd>.</kbd> pins the selected entry.

- Pinned entries sit in one **Pinned** section at the top, in the order you pinned them.
- They lead both the full list and your search results.
- <kbd>⌘</kbd><kbd>1</kbd> to <kbd>⌘</kbd><kbd>9</kbd>, then <kbd>⌘</kbd><kbd>0</kbd>, act on the
  first ten visible pins.
- **Pins survive the retention limit.** **Clear history** still removes everything.
- Pasting a pinned entry does not move it.
- **Unpinning makes it the newest entry**, instead of dropping it back into an old date group.

## Searching text inside images and PDFs

**Search text in images and PDFs** is **off** by default. Turn it on and Tinycast reads the text in
your copied images, image files and PDFs, so a search for a word in a screenshot finds it.

- It happens **on your Mac**, while you are not typing or moving the mouse, one item at a time.
- It runs in a separate helper process, so Tinycast itself stays light.
- It covers files up to 32 MB and the first 64 pages of a PDF.
- The recognized text is only used for search. Pasting still gives you the original.
- Turning it off stops the work. Text already recognized is kept and reused if you turn it back on.

This setting is not included in [backups](/docs/reference/backup).

## Settings

**Settings → Clipboard**

| Setting                        | Options                                                           | Default                    |
| ------------------------------ | ----------------------------------------------------------------- | -------------------------- |
| Enable Clipboard History       | On · Off                                                          | **On**                     |
| Clipboard History shortcut     | Any shortcut                                                      | None                       |
| Keep history for               | 1 Day · 1 Week · 1 Month · 3 Months · 6 Months · 1 Year · Forever | **3 Months**               |
| Search text in images and PDFs | On · Off                                                          | **Off**                    |
| Default action                 | Paste · Copy to Clipboard                                         | **Paste**                  |
| Disabled Applications          | A list of apps                                                    | Keychain Access, Passwords |
| Clear history                  | Removes every saved clip and image                                | —                          |

**Disabled Applications** starts with Keychain Access and Passwords, so Tinycast never records what
you copy out of a password manager. Add your own. Copies that apps mark as secret are skipped too.

## Limits worth knowing

History lives in `clipboard.sqlite3`, with images beside it, in Tinycast's Application Support folder.
It is there, not in Caches, so Time Machine backs it up and macOS never clears it behind your back.

- Tinycast checks the clipboard twice a second. Its own pastes are marked and skipped, so pasting
  from Tinycast never adds a new entry.
- The newest **1,000** entries are kept ready in memory. Search reaches further back.
- **Search needs at least three characters** to use the full index. Shorter searches look through
  the recent entries in memory.
- A search returns at most 200 matches before the type filter applies, so a narrow filter on a broad
  search can show fewer rows than your history holds.
