---
title: System actions
description: 31 built-in actions for the Mac itself, like lock, sleep, volume, Bluetooth and the Trash.
---

System actions are things you do to your Mac rather than to a file. Each one is searchable, and each
one can have a global shortcut.

They have their own **System Actions** section in the launcher, and their own pane in
**Settings → System Actions**.

## The full list

**Session** · Lock Screen · Sleep · Sleep Displays · Restart · Shut Down · Log Out ·
Show Screen Saver

**Media** · Play / Pause · Next Track · Previous Track

**Volume** · Toggle Mute · Turn Volume Up · Turn Volume Down · Set Volume… ·
Set Volume to 0% · 25% · 50% · 75% · 100%

**Desktop** · Show Desktop · Toggle System Appearance · Toggle Stage Manager ·
Hide All Apps Except Frontmost · Unhide All Hidden Apps · Quit All Applications ·
Dismiss Notifications

**Files** · Open Trash · Empty Trash · Eject All Disks · Toggle Hidden Files

**Hardware** · Toggle Bluetooth

## Confirmation

Five actions ask first, because running them by accident is costly:

Restart · Shut Down · Log Out · Empty Trash · Quit All Applications

<kbd>return</kbd> runs and <kbd>esc</kbd> cancels. Each dialog shows that action's own icon, so you can see
at a glance what you are about to do. **Quit All Applications** tells you how many apps it will quit.

**The same question comes up when you use a shortcut.** There is no way around it, and holding a
shortcut down cannot stack up dialogs.

## What you see afterwards

Actions with no visible effect tell you where they landed: `Trash Emptied`, `Hidden Files Shown`,
`Dark Appearance`, `Bluetooth Off`, `3 Disks Ejected`.

A green check means something changed. A plain dot means there was nothing to do.
`Trash Is Already Empty` is an answer, not a failure, and so is the same kind of message from Eject
All Disks, Dismiss Notifications and Unhide All Hidden Apps.

## A few details

**Volume.** Up and Down move along a **5% grid**: from 37%, up goes to 40% and down to 35%. Tinycast
shows its own volume display, because macOS only shows one for the real media keys. It shows the
level as a number, says `Muted` instead of `0%`, and fades after 1.6 seconds.

**Eject All Disks** ejects external and removable drives, including a dock's hard drive, and never
touches internal or network volumes.

**Hide All Apps Except Frontmost** and **Quit All Applications**, run from a shortcut with the
palette closed, work on the app that is actually in front. Quit All leaves Finder and Tinycast
running, and quits politely, so apps with unsaved work still ask you to save.

**Toggle System Appearance** changes **macOS itself**, not just Tinycast. Tinycast follows along only
while its own [theme](/docs/palette#appearance) is set to System.

## Permissions

Some actions need Automation, Accessibility or Bluetooth access. Each is asked for the first time you
run the action that needs it, never up front. If you say no, you get a message with a link to the
right System Settings pane instead of nothing happening.

## Settings

**Settings → System Actions** has **Enable System Actions** at the top, and a row per action with a
launcher checkbox, a shortcut recorder and an alias field. A filter field at the top helps with 31
rows.

**Enable System Actions** off takes every action out of search and turns off their shortcuts. A single
row's checkbox only hides it from search, and <kbd>⇧</kbd><kbd>⌘</kbd><kbd>H</kbd> in the launcher
does the same.
