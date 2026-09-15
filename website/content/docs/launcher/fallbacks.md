---
title: Fallbacks
description: When search does not have the answer, send what you typed to AI Chat, file search, the shell or a quicklink.
---

Below every search, Tinycast offers a few rows under **Use "…" with**. Each one takes what you typed
and hands it to something else. They sit at the bottom on purpose: the real results always come
first.

## The built-in fallbacks

| Fallback          | What happens to your text                                     | Offered when                                       |
| ----------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| AI Chat           | Sent as a question in a new chat                              | [AI](/docs/ai) is on                               |
| Search Files      | Opens [file search](/docs/features/file-search) with it typed | File Search is on                                  |
| Run Shell Command | Runs in `zsh`, with its output in a window                    | Always, unless you untick it                       |
| A quicklink       | Fills the quicklink's first `{argument}`                      | Quicklinks is on, and the link has an `{argument}` |

### Run Shell Command

Your text runs in `/bin/zsh` from your home folder, with your shell configuration loaded, so your own
aliases like `ll` work. A window shows the output as it prints, with **Stop** and **Run Again**
buttons.

This is separate from [custom commands](/docs/launcher/commands#custom-commands). Turning custom
commands off does not hide it; its own checkbox in Settings does.

### Quicklinks as fallbacks

**Any quicklink with an `{argument}` in its link becomes a fallback.** Your text fills the first
argument. If that was the only value it needed, it opens straight away. If it needs more, Search
Quicklinks opens with your text already filled in and the next field ready.

## Settings

**Settings → Fallbacks** lists every fallback on offer, each with a checkbox. The arrow buttons change
the order.

A fallback whose feature is switched off does not show here or in search.

**The order and the checkboxes are never included in a [backup](/docs/reference/backup)**, so
importing a file cannot put a shell command runner into your launcher.

## Open in Browser

Open in Browser is the opposite of a fallback. When your text looks like a web address, like
`https://…` or `github.com/user/repo`, **Open in Browser** appears at the **top** of the results
instead, and opens it in your default browser.

It learns nothing and cannot be a favorite, because it only exists for the text you typed.
