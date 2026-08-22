---
title: System actions
description: 31 built-in actions for the Mac itself — lock, sleep, volume, Bluetooth, Trash and more.
---

System actions are things you do to the machine rather than to a file. Each one is searchable and
each one can take a global shortcut.

They live in their own **System Actions** section, and are configured in
**Settings → System Actions**.

## The full list

**Session** — Lock Screen · Sleep · Sleep Displays · Restart · Shut Down · Log Out ·
Show Screen Saver

**Media** — Play / Pause · Next Track · Previous Track

**Volume** — Toggle Mute · Turn Volume Up · Turn Volume Down · Set Volume… ·
Set Volume to 0% / 25% / 50% / 75% / 100%

**Desktop** — Show Desktop · Toggle System Appearance · Toggle Stage Manager ·
Hide All Apps Except Frontmost · Unhide All Hidden Apps · Quit All Applications ·
Dismiss Notifications

**Files** — Open Trash · Empty Trash · Eject All Disks · Toggle Hidden Files

**Hardware** — Toggle Bluetooth

## Confirmation

Five actions ask first, because getting them by accident is expensive:

Restart · Shut Down · Log Out · Empty Trash · Quit All Applications

<kbd>↵</kbd> runs, <kbd>⎋</kbd> cancels. Each confirmation carries that action's own icon, so you can
tell at a glance what you are about to do.

**The gate applies to the global shortcut too.** There is no way to bypass it, and holding a
shortcut down cannot stack up dialogs.

## What you see afterwards

Actions with no visible effect report the state they landed in — `Trash Emptied`,
`Hidden Files Shown`, `Dark Appearance`, `Bluetooth Off`, `3 Disks Ejected`.

A green check means something changed. A neutral dot means there was nothing to do:
`Trash Is Already Empty` is an outcome, not a failure, and the same goes for Eject All Disks,
Dismiss Notifications and Unhide All Apps.

## Volume

Volume Up and Down walk a **5% grid** — from 37%, up lands on 40% and down on 35%.

Tinycast draws its own volume HUD, because macOS only shows one for real media keys. It prints the
level as text, shows `Muted` rather than `0%`, and dismisses after 1.6 seconds. Arrow keys walk the
same 5% grid; clicking the track jumps straight to a level.

## Toggle System Appearance

This changes **macOS itself**, not just Tinycast. Tinycast follows along only while its own
[theme](/docs/palette#appearance) is set to System.

## Permissions

Automation, Accessibility and Bluetooth are requested at first use of the specific action that needs
them, never up front. If you deny one, you get an alert with a link to the right System Settings
pane rather than a silent no-op.

## Settings

**Settings → System Actions** is a list with a **Show in launcher** master toggle, and per action a
visibility checkbox, a shortcut recorder and an alias field. There is a filter field at the top,
which you will want with 31 rows.
