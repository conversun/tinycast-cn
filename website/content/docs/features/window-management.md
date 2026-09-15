---
title: Window management
description: 35 commands for halves, quarters, thirds, sizing, nudges, displays and instant Space switching.
---

Move and resize the window you were last using, without installing anything else.

**It needs no new permission.** It uses the same [Accessibility](/docs/permissions) grant that
clipboard pasting already uses.

**Settings → Window Management** holds the switch. It ships **off**. While it is off there are no
window commands in the launcher, and a shortcut you recorded moves nothing.

The same pane also holds [window layouts](/docs/features/window-layouts): saved arrangements of many
windows across your displays.

## The commands

**Halves** · Left Half · Right Half · Top Half · Bottom Half

**Quarters** · Top Left Quarter · Top Right Quarter · Bottom Left Quarter · Bottom Right Quarter

**Fourths** · First Three Fourths · Last Three Fourths

**Thirds** · First Third · Center Third · Last Third · First Two Thirds · Last Two Thirds

**Sizing** · Maximize · Almost Maximize · Reasonable Size · Maximize Height · Maximize Width ·
Center · Center Half · Center Two Thirds · Make Larger · Make Smaller · Restore Window

**Moving** · Move Left · Move Right · Move Up · Move Down · Move to Next Display · Move to Previous Display

**Fullscreen** · Toggle Fullscreen

**Spaces** · Switch to Previous Space · Switch to Next Space

## Settings

| Setting                  | Options                                  | Default  |
| ------------------------ | ---------------------------------------- | -------- |
| Enable window management | On · Off                                 | **Off**  |
| Show in launcher         | On · Off                                 | On       |
| Cycling                  | None · Cycle ½, ⅓ and ⅔ · Cycle displays | **None** |
| Gap between windows      | 0 to 64 points, in steps of 2            | **0**    |

Each command's shortcut, alias and launcher checkbox live in this same pane. To switch one command
off, clear its shortcut and untick its checkbox. There is no separate per-command switch.

## How the sizes are worked out

**Gaps.** An edge against the screen gets the full gap; an edge between two windows gets half. So two
windows side by side leave exactly one gap between them, and every screen edge is inset by one gap.
Edges are rounded, so thirds never overlap or leave a one-point seam.

**Make Larger and Make Smaller** step by 5% of the _screen_, not the window, so the two undo each
other exactly. The largest size is the screen. The smallest is 200 × 150 points or 15% of the
screen, whichever is bigger. Past either limit, they do nothing.

**Reasonable Size** is 60% of the screen, centered, and never more than 1025 × 900 points. On a big
5K display you get a sensible window, not a huge one. Pressing it again changes nothing.

**Center Half** is half the screen's width at full height, centered. **Center Two Thirds** is the
same, at two thirds of the width.

A window that is too big or off-screen is always pulled back onto the display. The usable area
already leaves out the menu bar, the Dock and the notch.

## Cycling and Restore

**Cycling** only applies to the four halves, and it is off by default. With it off, pressing Left Half
again just puts the window in the same place. The two modes change that:

- **Cycle ½, ⅓ and ⅔** changes the width in place with each press. Top Half and Bottom Half step
  through heights instead.
- **Cycle displays** moves the half along every half-slot across your displays, so one shortcut
  sweeps the whole desk. With two displays, Left Half goes Display 1 left → Display 2 right →
  Display 2 left → Display 1 right, then round again. With one display it does nothing.

The cycle starts over when you move the window yourself (by more than 2 points), use a different
command, move to a different display, or wait a while.

**Restore Window goes back one step, not through a history.** Left Half → Maximize → Top Right
Quarter → Restore Window puts the window back where it **started**, not where it was last.

Restore Window also works on windows Tinycast has never moved, because it notes the frame before the first
change. It remembers up to 64 windows, forgets an app's windows when it quits, and never saves this
to disk.

## Fullscreen

**Toggle Fullscreen** asks the window to go fullscreen, then tries pressing its green button, and
otherwise does nothing.

It never fakes <kbd>⌃</kbd><kbd>⌘</kbd><kbd>F</kbd>. Apps can use that key for something else, and
firing the wrong command would be worse than doing nothing.

It resets the cycle, but keeps the Restore point.

## Spaces

**Switch to Previous Space** and **Switch to Next Space** move between macOS Spaces **without the
sliding animation**: about 56 ms, instead of about a second for the system's own
<kbd>⌃</kbd><kbd>←</kbd> and <kbd>⌃</kbd><kbd>→</kbd>.

They work by sending the same trackpad swipe macOS already uses to switch Spaces, fast enough that
the switch finishes instead of animating. Desktop Spaces and fullscreen Spaces are both included.

If you hold the shortcut down, presses that arrive mid-switch are dropped, so a long press never
jumps too far. At the first or last Space, macOS does whatever it normally does.

## When a window will not move

Minimized windows, sheets and popovers, windows already in native fullscreen, and windows that do not
report a position or size are skipped before anything happens.

A window that cannot be resized, like System Information, is left alone rather than half-moved. If an
app refuses to shrink, Tinycast lines the window up against its side **once**, never in a loop.
