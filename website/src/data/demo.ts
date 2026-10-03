// The hero's recreated palette. Labels copy the real app's strings (the action
// bar, section titles, placeholders), and every row names Tinycast's own
// things or generic apps, so nothing here pretends to be someone's data.

export type DemoRowIcon =
  "ghost" | "hammer" | "shield" | "gem" | "orbit" | "audio";

export type DemoRow = {
  title: string;
  kind: string;
  icon: DemoRowIcon;
  /** CSS background for the app icon. */
  tint: string;
  /** The row's bound hotkey, drawn as keycaps beside its title. */
  hotkey?: string[];
};

export type DemoSection = {
  title: string;
  rows: DemoRow[];
};

export const demoQuery = "o";
export const demoAction = "Open Application";

export const demoSections: DemoSection[] = [
  {
    title: "Favorites",
    rows: [
      {
        title: "Ghostty",
        kind: "Application",
        icon: "ghost",
        tint: "linear-gradient(160deg, #3d5afe, #0d1b6e)",
        hotkey: ["⌥", "⌘", "T"],
      },
      {
        title: "Xcode",
        kind: "Application",
        icon: "hammer",
        tint: "linear-gradient(160deg, #5ab8ff, #1466d8)",
      },
    ],
  },
  {
    title: "Applications",
    rows: [
      {
        title: "Brave Browser",
        kind: "Application",
        icon: "shield",
        tint: "linear-gradient(160deg, #ff7a3d, #e0381c)",
      },
      {
        title: "Obsidian",
        kind: "Application",
        icon: "gem",
        tint: "linear-gradient(160deg, #a875ff, #5b12bd)",
      },
      {
        title: "Spotify",
        kind: "Application",
        icon: "audio",
        tint: "linear-gradient(160deg, #2fe06f, #14833c)",
      },
      {
        title: "OrbStack",
        kind: "Application",
        icon: "orbit",
        tint: "linear-gradient(160deg, #4c4f9e, #16173a)",
      },
    ],
  },
];
