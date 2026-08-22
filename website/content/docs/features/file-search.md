---
title: File search
description: Find files through the Spotlight index, on demand, with no file permission.
---

Search filenames across folders you choose, using the index macOS already maintains.

**Settings → File Search** holds the feature switch. It ships **off**, and while off there is no
entry point and no Spotlight work at all.

Reach it with the **Search Files** command or its own global shortcut.

## It asks for nothing

Tinycast requests **no file permission** for this. Hidden paths and application-bundle contents are
excluded structurally — no setting can re-admit them — and that is exactly what keeps the feature
permission-free.

If Spotlight has not indexed something, you get a thinner result list rather than a Full Disk Access
prompt.

## Actions

| Action         | Shortcut                 |
| -------------- | ------------------------ |
| Open           | <kbd>↵</kbd>             |
| Show in Finder | <kbd>⌘</kbd><kbd>↵</kbd> |
| Copy Path      |                          |

**Copy Path leaves the palette open** and confirms with a pill, so you can copy several paths in a
row.

A row shows the file's native icon, its full name, and its parent folder with `~` abbreviated.

## Search scopes

**Settings → File Search → Search Scopes**, defaulting to your home folder.

Home expands to its **visible** children plus `Library/CloudStorage` and your iCloud Drive root.
**`~/Library` is never a scope Tinycast picks by itself** — if you add a folder inside it by hand,
you get what you asked for.

**An empty scope list searches nothing** rather than quietly falling back to home.

Scopes are stored with `~` abbreviated, so a backup still points somewhere sensible on another Mac.

## Ignore patterns

**Settings → File Search → Ignore Patterns**. Three shapes:

| Pattern          | Matched against    | Example          |
| ---------------- | ------------------ | ---------------- |
| Plain word       | Any path component | `node_modules`   |
| With `*` `?` `[` | Any path component | `*.tmp`          |
| Containing `/`   | The whole path     | `**/[Cc]ache/**` |

Matching is case-insensitive, and `*` spans `/`, so a `**/…/**` pattern behaves as written.

The setting stores **only what you add**. Six sensible rules are built in and cannot be switched off.

## Limits

Query terms are joined with AND — `annual report` needs both words in the filename, in any order and
not necessarily adjacent.

At most **1,000** Spotlight candidates per query, and at most **200** rows after filtering. Typing
waits 120 ms before searching.

## States

| You see                    | It means                              |
| -------------------------- | ------------------------------------- |
| _(nothing)_                | Empty query — no search is run        |
| Searching files…           | First query in flight                 |
| No files found             | Query completed with nothing matching |
| File search is unavailable | Spotlight could not be queried        |
