// A subset of docs/reference/shortcuts.md. The first row is the one chord a
// user picks themselves; Tinycast ships none, so it is labelled as a choice.

export type ShortcutRow = { keys: string[]; does: string };

export const shortcutRows: ShortcutRow[] = [
  { keys: ["⌥", "Space"], does: "Summon the palette, with keys you pick" },
  { keys: ["return"], does: "Run the main action" },
  { keys: ["⌘", "return"], does: "Run the second action" },
  { keys: ["⌘", "K"], does: "Open the actions menu" },
  { keys: ["tab"], does: "Launcher, then AI Chat, then clipboard" },
  { keys: ["⌘", "1…0"], does: "Open favorite 1 to 10" },
  { keys: ["esc"], does: "Clear, go back, then close" },
  { keys: ["⌘", "esc"], does: "Back to the root search from anywhere" },
];
