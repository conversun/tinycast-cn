---
title: Getting started
description: What Tinycast is, and the few minutes it takes to set up.
---

Tinycast is a small, native launcher for macOS. It lives in your menu bar. Press your shortcut, a
palette floats in over whatever you are doing, you type, and it gets out of the way.

It is built with SwiftUI and AppKit, with zero third-party dependencies, and it stays under 100 MB of
memory. There is no Electron, no account, no sign-in and no telemetry.

## Set it up

The first time Tinycast opens, a short welcome takes you through these steps. You can skip any of
them and come back later.

### 1. Pick a shortcut

**Tinycast ships with no shortcut bound.** Nothing happens until you choose one. That is on purpose:
a launcher should never grab a key combination you already use.

The welcome screen asks for one. Later you can change it in **Settings → General → App Launcher**:
click the field, then press the keys you want. <kbd>⌥</kbd><kbd>Space</kbd> is a common choice.

You can also use a double-tap of one modifier key, like pressing <kbd>⌘</kbd> twice. See
[Hotkeys](/docs/reference/hotkeys).

The same step has a **Launch at login** switch, so Tinycast is ready after a restart.

### 2. Allow pasting (optional)

Tinycast asks for Accessibility so it can paste a clip or an emoji back into the app you came from.
The launcher itself needs no permission. See [Permissions](/docs/permissions).

### 3. Bring your Raycast setup (optional)

If you used Raycast, pick its `.rayconfig` export. Tinycast brings your shortcuts, favorites,
snippets, quicklinks and clipboard history across. See
[Import from Raycast](/docs/reference/import-from-raycast).

## Turn on what you want

Most features ship **off**. A feature that is off does nothing at all: nothing is scanned, nothing is
indexed and nothing sits in memory. That is how the app stays small while the feature list is long.

| Feature                                               | Where to turn it on          |
| ----------------------------------------------------- | ---------------------------- |
| [AI Chat](/docs/ai)                                   | Settings → AI                |
| [Quick Actions](/docs/ai/quick-actions)               | Settings → Quick Actions     |
| [File Search](/docs/features/file-search)             | Settings → File Search       |
| [Notes](/docs/features/notes)                         | Settings → Notes             |
| [Snippets](/docs/features/snippets)                   | Settings → Snippets          |
| [Navigation](/docs/features/navigation)               | Settings → Navigation        |
| [Window Management](/docs/features/window-management) | Settings → Window Management |
| [Calendar](/docs/features/calendar)                   | Settings → Calendar          |
| [Quicklinks](/docs/launcher/quicklinks)               | Settings → Quicklinks        |
| [Custom commands](/docs/launcher/commands)            | Settings → Commands          |
| [Extensions](/docs/extensions)                        | Settings → Extensions        |

[Clipboard history](/docs/features/clipboard) is the one feature that ships on. You can turn it off
in **Settings → Clipboard**.

## The first thing to learn

Everything happens in one window. Type to search, <kbd>return</kbd> to act, <kbd>⌘</kbd><kbd>K</kbd> to
see every other action for what is selected, and <kbd>esc</kbd> to go back.

<kbd>⌘</kbd><kbd>K</kbd> matters more than it sounds. Every screen lists all of its actions there,
with the shortcut for each one printed beside it. It is the fastest way to learn the app.

Next: [the palette](/docs/palette), or [install Tinycast](/docs/install) if you have not yet.
