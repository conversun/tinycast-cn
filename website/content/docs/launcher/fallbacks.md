---
title: Fallbacks
description: When search has no answer, send what you typed to AI Chat, file search, the shell or a quicklink.
---

Below every search, Tinycast shows a few rows under **Use "…" with**. Each one sends what you typed
somewhere else. They always appear at the bottom, below the real results.

## The built-in fallbacks

| Fallback          | What happens to your text                                     | Shown when                                         |
| ----------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| AI Chat           | Sent as a question in a new chat                              | [AI](/docs/ai) is on                               |
| Search Files      | Opens [file search](/docs/features/file-search) with it typed | File Search is on                                  |
| Run Shell Command | Runs in `zsh`, with its output in a window                    | Always, unless you turn it off                     |
| A quicklink       | Fills in the quicklink's first `{argument}`                   | Quicklinks is on, and the link has an `{argument}` |

### Run Shell Command

Your text runs in `/bin/zsh` from your home folder with your shell configuration loaded, so your own
aliases like `ll` work. A window shows the output as it's printed, with **Stop** and **Run Again**
buttons.

This is separate from [custom commands](/docs/launcher/commands#custom-commands). Turning off custom
commands doesn't hide it; only its own checkbox in Settings does.

### Quicklinks as fallbacks

**Every quicklink with an `{argument}` in its link becomes a fallback.** Your text fills in the first
argument. If that was the only value the link needed, it opens right away. If it needs more, Search
Quicklinks opens with your text already filled in and the next field selected.

## Settings

**Settings → Fallbacks** lists every available fallback, each with a checkbox. Use the arrow buttons
to change their order.

Fallbacks for features that are turned off don't appear here or in search.

**The order and checkboxes are never included in a [backup](/docs/reference/backup)**, so importing
a file can't add a shell command runner to your launcher.

## Open in Browser

Open in Browser works the other way around. When your text looks like a web address, like
`https://…` or `github.com/user/repo`, **Open in Browser** appears at the **top** of the results and
opens the address in your default browser.

It doesn't affect learned ranking and can't be a favorite, because it only exists for the text you
typed.
