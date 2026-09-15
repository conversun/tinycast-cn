---
title: Snippets
description: Reusable Markdown templates with placeholders, arguments and keyword expansion.
---

A snippet is a piece of text you reuse, saved as a plain Markdown file you can also edit by hand.

Paste one from the launcher or the snippet browser, or type its keyword in any app and watch it
expand in place.

**Settings → Snippets** holds the switch. It ships **off**.

| Setting          | Default |
| ---------------- | ------- |
| Enable snippets  | Off     |
| Show in launcher | On      |

**The switch is also your consent to keyword matching.** There is no separate one. Turning it on
explains what happens first, then asks for
[Accessibility](/docs/permissions#snippets-and-keystroke-matching).

Turning it off stops everything: the keyword listener, the file watcher and the launcher rows. Your
files stay where they are.

**Show in launcher** off hides snippets and the two snippet commands from search. **Keyword expansion
and the browser's shortcut keep working.**

`snippetsEnabled` is never included in [backups](/docs/reference/backup), so importing a file can
never switch on keystroke listening.

## Commands

| Command         | Does                              |
| --------------- | --------------------------------- |
| Search Snippets | Opens the snippet browser         |
| Create Snippet  | Opens the editor on a new snippet |

Both take a global shortcut and an alias in **Settings → Snippets**.

## The snippet browser

**Search Snippets** lists every enabled snippet, with a preview beside it. Type to filter by name or
keyword.

The preview shows the **template as written**, with its placeholders, plus the name, keyword, file
name and character count. It never fills placeholders just to draw a preview, so browsing never reads
your clipboard or asks for an argument.

| Action (<kbd>⌘</kbd><kbd>K</kbd>) | Shortcut          |
| --------------------------------- | ----------------- |
| Paste Snippet                     | <kbd>return</kbd> |
| Edit Snippet                      |                   |
| Create Snippet                    |                   |
| Show in Finder                    |                   |

<kbd>esc</kbd> or <kbd>delete</kbd> in an empty search goes back.

## The file format

One Markdown file per snippet, in Tinycast's Application Support folder. Frontmatter is optional.

```markdown
---
name: "Meeting Notes"
keyword: "!notes"
enabled: true
show_confirmation: false
---

## {date format="EEEE, d MMMM"}

Attendees: {argument name="Attendees"}

{cursor}
```

`name` defaults to the file name. `keyword` is optional. `enabled` defaults to `true`, and
`show_confirmation` to `false`.

Text values need **double quotes**. Keys ignore case. Unknown keys, unquoted text, repeated keys and
booleans that are not lowercase `true` or `false` are rejected with a message that names them.

Everything after the closing `---` is the body, kept exactly as written: blank lines, line endings,
Unicode and any later `---` lines.

Each channel keeps its own folder, so stable and beta never share snippet files.

## Placeholders

| Token                          | Gives                                                              |
| ------------------------------ | ------------------------------------------------------------------ |
| `{clipboard}`                  | What is on the clipboard, as plain text                            |
| `{clipboard offset=1}`         | An earlier clip; `1` is the one before the current                 |
| `{selection}`                  | The selected text in the app you were using                        |
| `{date}` `{time}` `{datetime}` | Today's date, the time, or both, in your locale                    |
| `{day}`                        | The weekday's name                                                 |
| `{uuid}`                       | A fresh UUID for each token                                        |
| `{date format="yyyy-MM-dd"}`   | Any date format                                                    |
| `{date locale="fr-FR"}`        | Another locale; cannot be combined with `format`                   |
| `{time offset="+3h +30m"}`     | Shifted by `m` minutes, `h` hours, `d` days, `M` months, `y` years |
| `{argument}`                   | Asks you for a value, named "Argument"                             |
| `{argument name="Recipient"}`  | Asks for a named value                                             |
| `{argument default="Hi"}`      | Optional; uses the default without asking                          |
| `{argument options="a, b, c"}` | Asks with a list to pick from                                      |
| `{snippet:Name}`               | Another snippet, inline                                            |
| `{cursor}`                     | Where the cursor lands afterwards                                  |

These match [Raycast's dynamic placeholders](https://manual.raycast.com/dynamic-placeholders), so a
snippet you bring over keeps working. Raycast's spellings `{selectedText}` and `{query}` are accepted
too, as `{selection}` and `{argument}`. `{snippet name="Name"}` works as well as `{snippet:Name}`.

A value only needs quotes if it contains `|`. Without quotes, a value runs up to the next `key=`, so
`{date format=MMMM d, yyyy}` keeps its spaces.

The editor's **Insert…** menu lists every token. Parameters and modifiers you type by hand.

### Modifiers

Chain them left to right: `{clipboard | trim | uppercase}`

Available: `uppercase` · `lowercase` · `trim` · `percent-encode` · `json-stringify` · `raw`

`json-stringify` escapes text for use inside a JSON string, without adding the quotes. `raw` only
matters in [quicklinks](/docs/launcher/quicklinks#encoding). `{cursor}` and snippet references take
no modifiers.

### When a token is wrong

**A token Tinycast cannot read is left in the text exactly as you wrote it**, never silently dropped.
If you see `{arguemnt}` in your pasted text, that is the typo pointing at itself.

`{browser-tab}` and `{calculator}` are not supported.

### Limits

Each argument is asked for once, in the order it first appears, including ones inside referenced
snippets. Values are inserted as-is: text that looks like a token inside a value is not expanded
again.

Snippet references ignore case and nest up to **five** levels deep, with loop detection. A missing,
looping or too-deep reference stays visible as a token.

All `{cursor}` tokens are removed, and the first one decides where the cursor goes.

## Keyword expansion

Give a snippet a keyword and typing it in any app expands the snippet in place.

- Keywords match **without case, by the longest ending**, so a more specific keyword wins.
- The typing buffer holds at most 256 characters. It resets when you switch apps, on Secure Event
  Input, on arrow keys and shortcuts with modifiers, and after **15 seconds** of no typing.
- If you keep typing before an expansion lands, it is dropped rather than inserted mid-word.
- Just before it deletes the keyword and inserts the text, Tinycast checks everything again. If
  anything changed, what you typed is left alone.

Settings shows the status plainly: **Off**, **Needs Accessibility**, or **Active**.

A keyword typed into Tinycast's own search field or Settings never expands. A keyword typed in
[Notes](/docs/features/notes) expands right into the note.

### How the text gets there

First choice: one clean replacement through Accessibility, which Tinycast then checks actually
happened.

Some apps, like Chrome, VS Code, Slack and other Electron apps, do not really accept that, so
Tinycast types the text instead. Short, single-line expansions of up to 100 characters are typed as
keystrokes.

Longer or multi-line text uses a quick temporary paste. Tinycast saves your clipboard, pastes only
the snippet text, then puts your clipboard back exactly. If you copied something new in the meantime,
it leaves your new copy alone. None of this ends up in your
[clipboard history](/docs/features/clipboard).

## In the launcher

Enabled snippets show up in launcher search while **Show in launcher** is on. **Both the name and the
keyword are searchable**, ranked like an app name.

<kbd>return</kbd> pastes the snippet.

## The editor

Changes live in memory until you press **Save**. **New** creates no file until the first save.

If the file changed on disk while you were editing, saving is **refused as a conflict** instead of
overwriting. Open the snippet again to see what is on disk now.

**Show confirmation** is per snippet and off by default. When on, a small message names the snippet
after it is inserted. Failed or cancelled expansions never show it.
