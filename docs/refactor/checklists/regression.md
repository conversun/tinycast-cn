# Regression checklist — manual behaviour sweep

There is no UI test suite. **You are it.** Run the Core sweep after every phase; run the scoped sections
whose feature the phase touched.

Budget: ~5 minutes for Core, ~3 minutes per scoped section.

> Run against the **Debug channel** (`Tinycast Dev.app`, `com.tinycast.app.dev`). It has its own prefs,
> caches, TCC grants and login item, so this can never corrupt your real installation.

---

## Core sweep — after every phase

### Palette lifecycle

- [ ] Palette hotkey opens the launcher; pressing it again closes it
- [ ] Escape closes it
- [ ] Clicking away closes it (`windowDidResignKey`)
- [ ] Reopening focuses the search field with an empty query
- [ ] The window opens in the same position and at the same size as before the phase
- [ ] Compact mode: typing expands it; the search bar **does not shift vertically** during the swap
- [ ] The top edge stays anchored across the compact↔expanded swap

### Search and selection

- [ ] Typing filters results; results appear instantly with no visible lag
- [ ] ↑/↓ move the highlight and scroll it into view without yanking the list
- [ ] The highlight always sits on the row the footer pill describes
- [ ] With a calculation typed, the calculator card is at the top and is selected first
- [ ] ↵ launches the highlighted entry
- [ ] Section headers appear in the documented order: Favorites, Applications, System Settings,
      Quicklinks, Snippets, System Actions, Window Management, Custom Commands, Commands

### Menus and keys

- [ ] ⌘K opens the Actions menu for the current selection
- [ ] ↑/↓ move the menu highlight; ↵ activates; Escape closes the menu, not the palette
- [ ] While a menu is open, typing does **not** change the query and the caret is hidden
- [ ] Right-click on a row opens that row's Actions menu
- [ ] Tab toggles launcher ↔ clipboard
- [ ] Bare Backspace on an empty query backs out of a sub-screen
- [ ] ⌘, opens Settings; ⌘W closes the palette

### Focus restoration

- [ ] Launching an app from the palette gives that app focus
- [ ] Escaping the palette returns focus to the app you were in
- [ ] Paste from clipboard history lands in the app you were in, not in Tinycast

### Visual

- [ ] Dark surface, glass materials and blur identical to before — compare against a screenshot
- [ ] Row heights, spacing, icon sizes, keycap chips unchanged
- [ ] No flash, flicker or reflow on open

---

## Scoped sections

### Clipboard — phases 09, 10, 17, 22

- [ ] Copying text anywhere records a new entry at the top within ~1 second
- [ ] Copying an image records a thumbnail
- [ ] Search filters; results are correct for queries under and over 3 characters
- [ ] ⌘P pins; the row moves into the Pinned section and the highlight follows it
- [ ] ⌘⌫ deletes the selected entry
- [ ] ↵ pastes into the previous app; ⌥↵ pastes without closing the palette
- [ ] ⌘↵ copies without pasting
- [ ] A copy from an excluded app (Settings ▸ Clipboard ▸ Disabled Applications) is **not** recorded
- [ ] Password-manager copies are still not recorded

### Launcher & icons — phases 02, 07, 09, 17, 23, 31

- [ ] Every installed app appears; Settings panes appear under System Settings
- [ ] Icons render with no placeholder flash on reopen
- [ ] Settings ▸ Applications scrolls smoothly with no hitch on first paint
- [ ] Running apps show the running dot
- [ ] An app uninstalled since the last open drops out after a reopen
- [ ] Learned ranking still surfaces your habitual result for a short query

### Hotkeys — phases 06, 15, 26

- [ ] The palette, clipboard and emoji global shortcuts all fire
- [ ] A per-app shortcut still toggles that app
- [ ] Recording a shortcut in Settings captures it, and the old binding does not fire while recording
- [ ] A conflicting binding is rejected and names its current owner
- [ ] A double-tap binding still fires
- [ ] Hyper Key still remaps and the status dot is green
- [ ] Quit and relaunch: every binding survives

### Uninstall — phases 08, 25

- [ ] The Uninstall action from the launcher opens the scan screen
- [ ] **List order is identical to before**: the bundle first, leftovers sorted by path
- [ ] The size total matches what it showed before the phase
- [ ] Locked rows are still locked and cannot be checked
- [ ] Filtering by name works
- [ ] Confirming moves items to the Trash and they are recoverable from it
- [ ] Escaping mid-scan cancels promptly with no spinner left behind

### Quicklinks — phases 17, 21, 24

- [ ] A quicklink opens its destination
- [ ] One with `{argument}` prompts for each argument in order; Backspace steps back
- [ ] `{selection}` falls back per the Settings choice
- [ ] Pin, duplicate, delete and "Open with Default" all behave as before
- [ ] Import and export round-trip
- [ ] Display order: pinned first by pin time, then by name

### Snippets — phases 04, 17, 24

- [ ] With snippets **off**: no launcher entries, no keyword expansion, no permission prompt at launch
- [ ] Enabling shows the consent dialog **before** the Accessibility prompt
- [ ] Declining the consent dialog leaves the feature off and prompts for nothing
- [ ] After enabling, a keyword expands in a text field
- [ ] An argument-bearing snippet prompts, then delivers
- [ ] Editing a snippet file externally reloads it

### Calculator & currency — phases 09, 14, 17

- [ ] `2+2` shows a card; ↵ copies and records to history
- [ ] Unit and date conversions still work
- [ ] With currency conversion **off**, a currency query produces no card and no network request
- [ ] Turning it on shows the consent sheet naming the provider first

### System actions & window management — phases 14, 25, 26, 31

- [ ] A confirmation-gated action (Restart, Quit All) still confirms, with the subject's own glyph
- [ ] Volume actions show the volume HUD; other actions show the message pill
- [ ] Holding a bound hotkey does **not** stack dialogs
- [ ] Window commands move the window you were last in
- [ ] Cycle-on-repeat still steps ½ → ⅓ → ⅔
- [ ] "Top Half" lands flush with the top of the visible frame — on a secondary display too

### Settings & backup — phases 05, 16, 32, 33

- [ ] Every pane renders; the sidebar switches without flicker
- [ ] Toggling a feature switch takes effect in the launcher immediately
- [ ] Every setting survives quit and relaunch
- [ ] Export produces a file; import applies it and reports a sensible summary
- [ ] **`snippetsEnabled` is not in the exported file** and importing does not enable snippets

---

## Clean install — phases 05, 06, 16, 17, 27–30, 35

Per [`../POLICY.md`](../POLICY.md) there are no existing users and local data is disposable, so this is
no longer a data-preservation check. It is a **fresh-install** check, and it is now the primary storage
test — because the realistic failure is a store that crashes on an absent file rather than starting
empty.

Wipe the Dev channel first:

```bash
rm -rf ~/Library/Caches/com.tinycast.app.dev
rm -rf "$HOME/Library/Application Support/com.tinycast.app.dev"
defaults delete com.tinycast.app.dev 2>/dev/null || true
```

- [ ] App launches with every store directory absent — no crash, no hang
- [ ] Onboarding runs (the marker file is genuinely gone)
- [ ] Palette opens; the launcher lists apps
- [ ] Clipboard history is empty and records the next copy
- [ ] Quicklinks, snippets and calculator history are all empty and all accept a first entry
- [ ] **Every setting shows its intended default.** Walk the panes — this is what catches a broken
      absence-vs-`false` conversion (see `POLICY.md` carve-out 1)
- [ ] Quit and relaunch → everything created above persisted
- [ ] Channel isolation intact: nothing was written outside `com.tinycast.app.dev/`

> Channel isolation is the one storage guarantee the policy does **not** relax. A Dev build writing into
> the stable app's directory is still a defect.

---

## Recording results

- [ ] Every applicable box ticked, or the failure written into the progress file
- [ ] Any failure root-caused **before** the next phase starts
