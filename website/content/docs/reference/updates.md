---
title: Updates
description: How Tinycast finds, checks and installs new versions by itself.
---

Tinycast keeps itself up to date. There is nothing to set up.

## How it works

1. **Once a day**, Tinycast asks GitHub whether a newer release is out for its channel. If a check
   fails, it tries again in two hours. The first check waits 30 seconds after launch, so it never
   slows down logging in.
2. When there is one, a window shows **what changed**, taken from the release notes.
3. One click downloads it, with real progress and a **Cancel** button that really stops the download.
4. Tinycast checks the download, installs it, and offers to **relaunch**.

Choose **Later** and that version stops asking. A newer version will still ask.

**Check for Updates** always looks for anything newer, even a version you skipped. It is in the
launcher, the Tinycast menu bar menu, and **Settings → About**.

## It waits for a good moment

The update window never pops up in the middle of something. It waits while the palette is open, while
a snippet is expanding, an extension command is running, the uninstaller is working, you are recording
a shortcut, or a dialog is up. It tries again every two minutes for half an hour, then goes back to
checking once a day.

Each version is offered at most once per launch, so it never nags.

## Channels stay separate

Stable only updates to stable releases, and beta only to beta releases. They are separate apps, and an
update never crosses from one to the other.

On an Intel Mac, Tinycast only installs the universal build. If a release has none, nothing is
offered, rather than installing a build that would not open.

## Safety checks

Nothing is installed unless every check passes. If any fails, the app you are running stays exactly
as it was.

- **The signature must prove the download is Tinycast**, signed the same way as the copy you are
  running.
- The app identifier and the version must be the ones expected.
- Tinycast never runs `xattr` or asks for an administrator password. If `/Applications` cannot be
  written to, it tells you instead of working around it.

Updating never touches your settings, clipboard history, notes, snippets or anything else you made.

## Homebrew

Tinycast's Homebrew casks tell Homebrew that the app updates itself. So `brew upgrade` **skips
Tinycast on purpose**: it never reports it as outdated, never downloads it again, and never rolls a
self-updated copy back.

`brew install`, `brew uninstall` and `brew list` work as usual.

## Supporting Tinycast

Tinycast is free and open source. **Support Tinycast** in the launcher, the menu bar and
**Settings → About** opens a small window with a link to support the project.

About once a month, that window may appear on its own, never on the day you install and never while
you are in the middle of something. Untick the reminder checkbox in the window and it will never ask
again.
