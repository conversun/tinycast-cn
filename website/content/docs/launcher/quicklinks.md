---
title: Quicklinks
description: Turn a URL, search, file or deeplink into a real command, with arguments it prompts for.
---

A quicklink is a saved destination that behaves like any other launcher entry: searchable,
bindable to a shortcut, and able to take input.

**Settings → Quicklinks** holds the feature switch. It ships **off**.

| Setting                       | Default    |
| ----------------------------- | ---------- |
| Enable quicklinks             | Off        |
| Show in launcher              | On         |
| Open in a new window          | Off        |
| When there's no selected text | Ask for it |
| Confirm before deleting       | On         |

While the feature is off there is no section, no Create/Search/Import/Export commands, and nothing
opens — but **bindings stay registered**, so re-enabling restores every shortcut you had.

## Destinations

Tinycast works out what a link is from its shape alone:

| You write                                           | It becomes                 |
| --------------------------------------------------- | -------------------------- |
| `~/Notes`, `/Users/...`, `file://...`               | A local path               |
| `https://...`, `http://...`                         | Web                        |
| `smb:` `afp:` `nfs:` `ftp:` `sftp:` `ftps:`         | Network                    |
| `spotify://`, `slack://`, `shortcuts://`, `mailto:` | A deeplink                 |
| `github.com/user/repo`                              | Web, with `https://` added |

Two shapes are read the way you almost certainly meant: a single-letter "scheme" is a **Windows
drive letter**, and a `scheme:` followed only by digits is a **host:port**.

## Placeholders

Quicklinks use the same token set as [snippets](/docs/features/snippets#placeholders):

```
https://google.com/search?q={argument}
https://github.com/search?q={argument name="Repository"}
https://translate.google.com/?text={selection}
https://chat.openai.com/?q={clipboard}
~/Notes/{date format="yyyy-MM-dd"}.md
```

`{cursor}` and `{snippet:…}` are left literal in a destination — there is no caret to place in a URL.

### Encoding

Values going into a URL or deeplink are **percent-encoded automatically**, after any modifiers run.
A local path is never encoded, so `%20` in a path stays a literal `%20`.

`| raw` opts out of encoding, and also lets the substituted value change what kind of destination
this is — a `{clipboard | raw}` holding `file:///Users/me/notes.md` resolves to a local path. That is
powerful and occasionally surprising, which is why it has to be asked for explicitly.

## The argument prompt

A quicklink that needs values collects them in the palette, **one at a time**. The search field is
the current argument's input, and the screen above lists every argument with what you have answered
so far.

- <kbd>↵</kbd> commits and moves to the next one; on the last, it opens.
- <kbd>⌫</kbd> on an empty field steps back and restores what you typed there.
- An argument declaring `options=` shows its choices as selectable rows.

The context is captured **once, before the first prompt**, so `{clipboard}`, `{selection}` and
`{date}` cannot drift while the form is open. Triggered by a shortcut with the palette closed, the
frontmost app is recorded first, so `{selection}` reads from the window you were actually in.

### When there is no selection

If a template reads `{selection}` and the front app exposes nothing readable,
**When there's no selected text** decides what happens:

- **Ask for it** (default) — a "Selected Text" prompt appears
- **Use the clipboard** — substitutes the clipboard instead

## Opening

**Open With** stores a specific app. If that app has been uninstalled, you get a clear failure with
an **Open with Default** button rather than a silent fallback.

**Open in a new window** passes `--new-window`. Chromium and Firefox honour it; **Safari ignores
it**. With it off, opening reuses the frontmost tab — so "prefer existing tabs" is this same switch,
not a second one.

A path destination is checked for existence first, so a deleted folder names itself.

## Searching and pinning

Quicklinks get their own launcher section between System Settings and Snippets.

**Only the name is indexed.** The destination is not searchable.

Order is pinned first — in the order you pinned them — then the rest by name. Pinned means the top
of the Quicklinks section, not above Applications.

The **Search Quicklinks** command opens a dedicated screen:

| Action                                        | Shortcut                 |
| --------------------------------------------- | ------------------------ |
| Open                                          | <kbd>↵</kbd>             |
| Open With Default App                         | <kbd>⌘</kbd><kbd>↵</kbd> |
| Pin / Unpin                                   | <kbd>⌘</kbd><kbd>.</kbd> |
| Show in Finder                                | <kbd>⌘</kbd><kbd>F</kbd> |
| Delete Quicklink                              | <kbd>⌘</kbd><kbd>⌫</kbd> |
| Edit · Duplicate · Hide / Show in Root Search |                          |

Editing keeps the quicklink's shortcut, favorite slot, visibility and learned ranking. **Duplicating
takes a new identity**, so the copy cannot inherit the original's shortcut.

## Import and export

Versioned JSON, pretty-printed with ISO 8601 dates so you can hand-edit it. A bare array also
decodes, and only `name` and `link` are required.

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

Duplicates are detected **by name or by destination**, against your existing library and against the
rest of the incoming file. Skipped entries are counted and reported. Every imported entry takes a
fresh identity.
