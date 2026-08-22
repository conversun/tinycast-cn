---
title: Snippets
description: Reusable Markdown templates with placeholders, arguments and keyword expansion.
---

A snippet is a piece of text you reuse, stored as a plain Markdown file you can edit by hand.

Paste one from the launcher, or type its keyword in any app and have it expand in place.

**Settings → Snippets** holds the feature switch. It ships **off**.

| Setting          | Default |
| ---------------- | ------- |
| Enable snippets  | Off     |
| Show in launcher | On      |

**The enable switch is also the consent for keystroke matching** — there is no separate toggle. It
explains itself before turning on, then requests
[Accessibility](/docs/permissions#snippets-and-keystroke-matching).

Turning **Show in launcher** off hides the section but **keyword expansion keeps working**.

`snippetsEnabled` is deliberately excluded from
[settings backups](/docs/reference/backup), so importing a file can never enable keystroke listening.

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

`name` defaults to the filename, `keyword` is optional, `enabled` defaults to `true`, and
`show_confirmation` defaults to `false`.

Strings must use **double quotes**. Keys are case-insensitive with no aliases; unknown keys,
unquoted strings, duplicates and non-lowercase booleans are rejected by name rather than ignored.

Everything after the closing `---` is the body, preserved byte for byte — blank lines, line endings,
Unicode and any later `---` lines.

Each channel has its own folder, so stable and beta never share files.

## Placeholders

| Token                          | Gives                                         |
| ------------------------------ | --------------------------------------------- |
| `{clipboard}`                  | The clipboard as plain text                   |
| `{clipboard offset=1}`         | The Nth most recent clip                      |
| `{selection}`                  | Selected text from the app you were in        |
| `{date}` `{time}` `{datetime}` | In your locale                                |
| `{day}`                        | Weekday name                                  |
| `{uuid}`                       | A fresh UUID per token                        |
| `{date format="yyyy-MM-dd"}`   | Any date format                               |
| `{date locale="fr-FR"}`        | Another locale — cannot combine with `format` |
| `{time offset="+3h +30m"}`     | Signed offsets: `m` `h` `d` `M` `y`           |
| `{argument}`                   | Prompts, named "Argument"                     |
| `{argument name="Recipient"}`  | A named prompt                                |
| `{argument default="Hi"}`      | Optional — expands without prompting          |
| `{argument options="a, b, c"}` | Prompts with a picker                         |
| `{snippet:Name}`               | Another snippet, inline                       |
| `{cursor}`                     | Where the caret lands                         |

`{selectedText}` is accepted as an alias for `{selection}`.

### Modifiers

Pipe them left to right: `{clipboard | trim | uppercase}`

Available: `uppercase` · `lowercase` · `trim` · `percent-encode` · `json-stringify` · `raw`

`{cursor}` and snippet references take no modifiers.

### When a token is wrong

**An unparseable token is left in the output exactly as written** — never silently dropped. If you
see `{arguemnt}` in your pasted text, that is the typo telling you about itself.

`{browser-tab}` and `{calculator}` are not supported.

### Limits

Arguments are unique and prompted in first-appearance order, including ones inside referenced
snippets. Inserted values are literal — token-shaped text in a value is not re-expanded.

Snippet references are case-insensitive and nest **five** levels deep with cycle detection. A
missing, cyclic or too-deep reference leaves the token visible.

All `{cursor}` tokens are removed; the first one wins.

## Keyword expansion

With a keyword set, typing it in any app expands the snippet in place.

- Keywords match **case-insensitively, by longest suffix**, so a more specific keyword wins.
- The typing buffer holds at most 256 characters and resets on app or session change, on Secure
  Event Input, on navigation and modifier shortcuts, and after **15 seconds** of inactivity.
- Before deleting the keyword and before inserting, every gate is re-checked. A failed gate leaves
  what you typed untouched.

Status is shown plainly in Settings: **Off**, **Needs Accessibility**, or **Active**.

### How the text is delivered

The preferred path is a single atomic Accessibility replacement.

Editors that grant Accessibility but expose no writable text fall back to synthetic keystrokes.
Short single-line expansions — up to 100 characters — use Unicode key events. Longer or multiline
text uses a temporary paste, but **only when your existing clipboard's first item is restorable
plain text**, and the change count is checked before restoring so a newer copy is never overwritten.

An image, empty or unreadable clipboard uses the keystroke path instead. The clipboard poller ignores
these temporary writes, so they never enter your [history](/docs/features/clipboard).

## In the launcher

Enabled snippets appear in launcher search while **Show in launcher** is on, and **both the name and
the keyword are searchable**, scored in the same band as an app name.

<kbd>↵</kbd> pastes the snippet.

## The editor

Drafts live in memory and write only on **Save**. **New** creates no file until the first save.

Saving over a file that changed underneath is **rejected as a conflict**, not silently merged.
Reopening shows what is actually on disk.

**Show confirmation** is per snippet and off by default. When on, a brief pill names the snippet
after a confirmed insertion. Failed, cancelled and prompt-cancelled expansions never show it.
