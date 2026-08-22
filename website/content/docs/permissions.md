---
title: Permissions
description: Accessibility is the only permission Tinycast requests, and only when you use a feature that needs it.
---

Tinycast asks for **one** permission: Accessibility. Nothing else is ever requested.

The launcher, the calculator, the emoji picker and search all work with no permission at all.

## Accessibility

macOS calls this "control your computer". In Tinycast it is what allows the app to read from and
write to the window you were in before the palette opened.

**Grant it in System Settings → Privacy & Security → Accessibility**, or from
**Settings → Permissions**, which shows the current status and opens the right pane for you.

### What needs it

| Feature                                               | Why                                                      |
| ----------------------------------------------------- | -------------------------------------------------------- |
| [Clipboard](/docs/features/clipboard) paste-back      | Puts the clip into the app you came from                 |
| [Emoji](/docs/features/emoji) paste                   | Same                                                     |
| [Snippets](/docs/features/snippets)                   | Watches for the expansion keyword, then inserts the text |
| [Window management](/docs/features/window-management) | Reads and sets other apps' window frames                 |
| [Hyper key](/docs/reference/hotkeys#hyper-key)        | Rewrites the physical key into a modifier chord          |
| Double-tap modifier hotkeys                           | Detects the tap pattern                                  |
| `getSelectedText` in [extensions](/docs/extensions)   | Reads the selection from the front app                   |

You are prompted the first time you use one of these, not at launch.

### Snippets and keystroke matching

Snippet keyword expansion is the one feature that watches typing, so it is worth being precise about.

- Snippets ship **disabled**, and enabling them shows an explanation first. Turning the feature on
  _is_ the consent — there is no separate switch.
- Matching happens **entirely on device**. Keystrokes are never stored and never sent anywhere.
- The typing buffer holds at most 256 characters and resets on app switch, on any modifier shortcut,
  when Secure Event Input is active, and after 15 seconds of inactivity.
- Tinycast uses a **listen-only** event tap on the Accessibility grant. It deliberately does not use
  Input Monitoring.
- **A settings backup can never enable it.** The `snippetsEnabled` flag is excluded from exports on
  purpose, so importing a file someone sent you cannot switch on keystroke listening.

## Full Disk Access

Tinycast **detects** Full Disk Access but **never requests** it.

The [uninstaller](/docs/launcher/uninstall) probes silently to work out which files it will be able
to move. Without the grant, protected locations — `~/Library/Containers`,
`~/Library/Group Containers`, `~/Library/Cookies` — are shown as locked rows rather than being
removed. The probe can only under-report, so the worst case is a row you have to clear by hand.

## Automation and Bluetooth

Two [system actions](/docs/launcher/system-actions) trigger their own system prompts the first time
you run them:

- **Show Info in Finder** drives Finder through Apple Events, raising the standard Automation prompt.
- **Toggle Bluetooth** raises the Bluetooth prompt.

Both are requested at first use of that specific action, never up front.

## What File Search does not need

[File Search](/docs/features/file-search) asks for **no file permission whatsoever**. It reads the
system Spotlight index and structurally excludes hidden paths and application-bundle contents, which
is exactly what lets it stay permission-free. If Spotlight has not indexed something, you get a
thinner result list rather than a permission prompt.
