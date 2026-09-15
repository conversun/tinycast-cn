---
title: Camera
description: A quick camera check from the launcher, with mirroring and a photo straight to the clipboard.
---

**Open Camera** puts a live camera preview on screen. Check how you look before a call, flip the
image, switch cameras, or take a photo straight to your clipboard.

There is nothing to turn on and nothing to configure. The command lives in **Settings → Commands**,
where you can give it a global shortcut and an alias.

## Using it

| Control       | Does                                                            |
| ------------- | --------------------------------------------------------------- |
| Take Photo    | Copies a photo to the clipboard as a PNG, then closes           |
| Mirror        | Flips the preview and the photo together                        |
| Switch Camera | Moves to your next camera; shown only if you have more than one |
| Close         | Closes the preview. <kbd>esc</kbd> does the same                |

Clicking anywhere outside the preview closes it too.

**What you see is what you get.** Mirroring flips the photo as well as the preview, so the photo
always matches what you framed. Tinycast remembers the Mirror choice until you quit.

The photo lands in your [clipboard history](/docs/features/clipboard) like any other image.

## Privacy

- Nothing touches the camera until you run the command. The first time, macOS asks for camera
  access.
- The camera turns off the moment the preview closes, so the green light never stays on.
- Taking a photo closes the preview too, so the camera does not sit idle waiting for a second shot.

The [Calendar](/docs/features/calendar#camera-preview) feature uses this same preview before a
meeting.
