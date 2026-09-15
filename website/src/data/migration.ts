// Drives the "Import your setup" block. The steps mirror the real import flow
// (Settings → Backup → Raycast Export), and `transfers` matches the app's
// `RaycastImportOptions` exactly — don't add anything the importer can't carry.

export const migration = {
  title: "Bring your setup with you.",
  intro:
    "Tinycast reads a Raycast export directly. Point it at your .rayconfig file, type the passphrase, and your shortcuts come with you.",
  steps: [
    {
      title: "Export what you have",
      body: "In Raycast, export your settings and data. Note the passphrase you set.",
    },
    {
      title: "Open Settings → Backup",
      body: "Choose the file and type the passphrase. A wrong one is reported as exactly that.",
    },
    {
      title: "Pick what to bring",
      body: "Keep everything, or only the parts you want. That's the whole setup.",
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
