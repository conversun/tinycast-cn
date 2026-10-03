// Drives the "Moving over" block. The steps mirror the real import flow
// (Settings → Backup → Raycast Export), and `transfers` matches the app's
// `RaycastImportOptions` exactly — don't add anything the importer can't carry.

export const migration = {
  title: "Bring your Raycast setup.",
  intro:
    "Tinycast reads Raycast's .rayconfig export. Choose the file, enter its passphrase, and your shortcuts, favorites and snippets come with it.",
  // Stated up front rather than in the docs alone: a 1.x file is the one thing
  // that will not work, and finding that out mid-import is the bad outcome.
  requirement: {
    title: "Raycast v2.0 and newer only",
    body: "Tinycast reads .rayconfig files from Raycast v2.0 and later. Support for Raycast v1.x files was removed in Tinycast v0.10.5.",
  },
  steps: [
    {
      title: "Export from Raycast",
      body: "Export your settings and data, and keep the passphrase you set.",
    },
    {
      title: "Open Settings → Backup",
      body: "Choose the file and enter the passphrase. If the passphrase is wrong, Tinycast says so.",
    },
    {
      title: "Choose what to import",
      body: "Import everything, or only the parts you want.",
    },
    {
      title: "Quit and reopen Tinycast",
      body: "Quit from the menu bar icon, because closing Settings isn't enough. Everything is in place after the restart.",
    },
  ],
  // Must match RaycastImportOptions in Features/Backup/Model/RaycastImport.swift.
  transfers: [
    "Shortcuts",
    "Favorites",
    "Clipboard history",
    "Snippets",
    "Quicklinks",
    "Aliases",
    "Emoji skin tone",
    "Compact mode",
    "Pop to root",
    "Launch at login",
    "Menu-bar preference",
  ],
} as const;
