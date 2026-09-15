---
title: File search
description: Find files and folders through the Spotlight index, with a preview and no file permission.
---

Search file and folder names in the folders you choose, using the index macOS already keeps.

**Settings → File Search** holds the switch. It ships **off**. While it is off there is no command
and no Spotlight work at all.

Open it with the **Search Files** command, its own global shortcut, or the **Search Files** row under
"Use … with" at the bottom of any launcher search. That last one opens with your text already typed.

## It asks for nothing

Tinycast requests **no file permission** for this. Hidden files and the insides of app bundles are
always left out, and no setting can bring them back. That is exactly what keeps the feature
permission-free.

If Spotlight has not indexed something, you get fewer results rather than a Full Disk Access prompt.

## The screen

With nothing typed, the list shows **Recently Used**: files you opened in the last 30 days or changed
in the last 3 days, inside your search scopes. This comes from macOS's own records. Tinycast keeps no
history of its own.

Type and it becomes **Results**. Each row shows the file's icon and name. A folder also shows its
parent folder's name, dimmed, because half the folders on a developer's Mac are called `src`.

The right side previews the selected file: the file itself, then its name, location, type, size and
dates. Videos and audio can be played there. Nothing plays until you press play.

### Filtering by type

<kbd>⌘</kbd><kbd>P</kbd>, or the **All Types** button, narrows the search:

**All Types** · **Folders** · **Documents** · **Images** · **Audio** · **Videos** · **Archives**

The filter changes what Spotlight is asked for, so narrowing never hides matches that were already
cut off. It resets each time you open the palette.

## Actions

| Action                  | Shortcut                             |
| ----------------------- | ------------------------------------ |
| Open File / Open Folder | <kbd>return</kbd>                    |
| Show in Finder          | <kbd>⌘</kbd><kbd>return</kbd>        |
| Quick Look              | <kbd>⌘</kbd><kbd>Y</kbd>             |
| Copy File               | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Paste File to …         | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>V</kbd> |
| Copy Name               | <kbd>⌥</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Copy Path               | <kbd>⌃</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Move to Trash           | <kbd>⌃</kbd><kbd>X</kbd>             |

- **Quick Look** opens a large preview inside the palette, and it plays media straight away.
  <kbd>esc</kbd> or **Close** puts it away.
- **Copy File** puts the file itself on the clipboard, ready to paste into Finder or Mail.
- **Paste File to …** pastes it into the app you opened the palette over.
- **Copy Name** and **Copy Path** keep the palette open, so you can copy several in a row.
- **Move to Trash** does not ask first. Things in the Trash can always come back.

Copies from here land in your [clipboard history](/docs/features/clipboard) like any other copy.

## Search scopes

**Settings → File Search → Search Scopes**, set to your home folder by default.

Your home folder means its **visible** folders, plus `Library/CloudStorage` and your iCloud Drive.
**Tinycast never adds `~/Library` on its own.** If you add a folder inside it yourself, you get what
you asked for.

**An empty scope list searches nothing**, rather than quietly falling back to home.

Scopes are saved with `~` shortened, so a backup still points somewhere sensible on another Mac.

## Ignore patterns

**Settings → File Search → Ignore Patterns**. Three kinds:

| Pattern          | Checked against    | Example          |
| ---------------- | ------------------ | ---------------- |
| Plain word       | Any folder or name | `node_modules`   |
| With `*` `?` `[` | Any folder or name | `*.tmp`          |
| Containing `/`   | The whole path     | `**/[Cc]ache/**` |

Matching ignores case, and `*` also matches `/`, so a `**/…/**` pattern works as written.

The list only holds what you add. Six sensible rules are built in and always apply.

## How search works

All the words you type must be in the file name, in any order. `annual report` finds
"Report – annual 2025.pdf".

Spotlight returns at most **1,000** candidates, and at most **200** rows are shown after filtering.
Typing waits 120 ms before searching, so a fast typist does not start a search per letter.

## Messages you might see

| You see                          | It means                            |
| -------------------------------- | ----------------------------------- |
| Type to search files and folders | Nothing recent in your scopes       |
| No files found                   | The search finished with no match   |
| No images found                  | The same, with the Images filter on |
| File search is unavailable       | Spotlight could not be asked        |
