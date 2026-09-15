---
title: Quicklinks
description: Turn a URL, search, file or deeplink into a real command, with values you fill in as you open it.
---

A quicklink is a saved destination that behaves like any other launcher entry. You can search for it,
give it a shortcut, and have it ask for a value, like a search term.

**Settings → Quicklinks** holds the switch. It ships **off**.

| Setting                       | Default    |
| ----------------------------- | ---------- |
| Enable quicklinks             | Off        |
| Show in launcher              | On         |
| Open in a new window          | Off        |
| When there's no selected text | Ask for it |
| Confirm before deleting       | On         |

While the feature is off there is no Quicklinks section, no quicklink commands, and nothing opens.
**Your shortcuts stay recorded**, so turning it back on brings every one of them back.

## Making one

**Add Quicklink** in Settings, or the **Create Quicklink** command, opens the editor.

| Field               | What it does                                         |
| ------------------- | ---------------------------------------------------- |
| Name                | What you search for                                  |
| Link                | Where it goes, with any placeholders                 |
| Open With           | A specific app, or the default app                   |
| Icon                | A symbol, or **Automatic** to match the kind of link |
| Pin to top          | Keeps it above your other quicklinks                 |
| Show in root search | Lists it alongside apps and commands                 |

The **Insert…** menu adds placeholders for you.

## Destinations

Tinycast works out what a link is from how it looks:

| You write                                           | It becomes                        |
| --------------------------------------------------- | --------------------------------- |
| `~/Notes`, `/Users/...`, `file://...`               | A file or folder                  |
| `https://...`, `http://...`                         | A web page                        |
| `smb:` `afp:` `nfs:` `ftp:` `sftp:` `ftps:`         | A network location                |
| `spotify://`, `slack://`, `shortcuts://`, `mailto:` | A deeplink into an app            |
| `github.com/user/repo`                              | A web page, with `https://` added |

Two shapes are read the way you almost certainly meant them: a single letter before a colon is a
**Windows drive letter**, and a name followed by a colon and only digits is a **host and port**.

## Placeholders

Quicklinks use the same placeholders as [snippets](/docs/features/snippets#placeholders):

```
https://google.com/search?q={argument}
https://github.com/search?q={argument name="Repository"}
https://translate.google.com/?text={selection}
https://chat.openai.com/?q={clipboard}
~/Notes/{date format="yyyy-MM-dd"}.md
```

`{cursor}` and `{snippet:…}` stay as written in a link, because there is no cursor to place in a URL.
Raycast's `{query}` is accepted as `{argument}`.

### Encoding

Values going into a web link or deeplink are **encoded automatically**, so a search term with a space
or an `&` cannot break the link. A file path is never encoded, so `%20` in a path stays `%20`.

`| raw` turns encoding off. It also lets the value decide what kind of link this is: a
`{clipboard | raw}` holding `file:///Users/me/notes.md` opens a file, not a web page. That is
powerful and sometimes surprising, which is why you have to ask for it.

## Filling in values

A quicklink that needs values shows **small fields right in the search bar**, after what you typed,
while its row is selected. The row stays in view the whole time.

- <kbd>tab</kbd> moves from the search field through each field and back.
- <kbd>return</kbd> opens the quicklink. If a required field is empty, it jumps there instead.
- A field with `options=` opens a menu to pick from.
- <kbd>esc</kbd> moves you from a field back to the search field.

A field only turns red after you have visited it and left it empty. A field you have not touched yet
is not something you owe.

Values like `{clipboard}`, `{selection}` and `{date}` are read **at the moment the link opens**.
Opened with a shortcut while the palette is closed, `{selection}` reads from the app you were
actually using.

A shortcut for a quicklink that still needs values opens **Search Quicklinks** on that quicklink,
with its first empty field ready to type in.

### When there is no selection

If a link uses `{selection}`, **When there's no selected text** decides what happens:

- **Ask for it** (default): a **Selected Text** field appears. Leave it empty and a real selection is
  still used; type something and it replaces it.
- **Use the clipboard**: the clipboard stands in for the selection.

## As a fallback

**A quicklink with an `{argument}` also shows under "Use … with"** at the bottom of every search.
What you typed fills its first argument. See [Fallbacks](/docs/launcher/fallbacks).

## Opening

**Open With** remembers a specific app. If that app is later uninstalled, you get a clear message with
an **Open with Default** button, not a silent switch to another app.

**Open in a new window** asks the browser for a new window. Chrome and Firefox listen; **Safari
ignores it**. With it off, the link opens the way macOS normally does, which usually reuses a tab.

A file or folder link is checked first, so a deleted folder tells you it is gone.

## Search Quicklinks

Quicklinks get their own launcher section. **Only the name is searchable**, plus any
[alias](/docs/launcher/aliases) you give it. The link itself is not.

Pinned quicklinks come first, in the order you pinned them, then the rest by name. Pinned means the
top of the Quicklinks section, not above your apps.

The **Search Quicklinks** command opens a screen with the list on the left and details on the right:
the link, the app it opens with, its shortcut and when you made it.

| Action                          | Shortcut                      |
| ------------------------------- | ----------------------------- |
| Open Quicklink                  | <kbd>return</kbd>             |
| Open With Default App           | <kbd>⌘</kbd><kbd>return</kbd> |
| Edit Quicklink                  |                               |
| Duplicate Quicklink             |                               |
| Pin / Unpin Quicklink           | <kbd>⌘</kbd><kbd>.</kbd>      |
| Hide from / Show in Root Search |                               |
| Show in Finder                  | <kbd>⌘</kbd><kbd>F</kbd>      |
| Delete Quicklink                | <kbd>⌘</kbd><kbd>delete</kbd> |

**Open With Default App** only appears when the quicklink has its own app, and **Show in Finder** only
for files and folders.

## Three ways to put one away

From widest to narrowest:

1. **Show in launcher** in Settings takes every quicklink and the quicklink commands out of search.
2. The **Enabled** checkbox on a quicklink's row in Settings makes that one quicklink do nothing,
   while keeping its shortcut and settings.
3. **Show in root search** off keeps a quicklink out of the main search, but you can still open it
   from Search Quicklinks or its shortcut.

Editing a quicklink keeps its shortcut, favorite, visibility and learned ranking. **Duplicating makes
a new quicklink**, so the copy does not take the original's shortcut.

## Import and export

**Import Quicklinks** and **Export Quicklinks** use a simple JSON file you can edit by hand. A bare
list works too, and only `name` and `link` are required.

```json
{
  "version": 1,
  "quicklinks": [
    {
      "name": "GitHub search",
      "link": "https://github.com/search?q={argument name=\"Query\"}"
    }
  ]
}
```

A quicklink is skipped as a duplicate if its **name or its link** matches one you already have, or
one earlier in the same file. The summary tells you how many were skipped.

You can also bring quicklinks across from a
[Raycast export](/docs/reference/import-from-raycast).

## Where they are kept

Quicklinks live in `quicklinks.sqlite3` in Tinycast's Application Support folder. If that file ever
cannot be opened, Tinycast **reports it and never deletes it**. Your links are something you made, not
something that can be rebuilt.
