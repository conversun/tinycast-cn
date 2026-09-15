// The hero's recreated palette. Labels copy the real app's strings (the action
// bar, section titles, placeholders), and every row names Tinycast's own
// things or generic apps, so nothing here pretends to be someone's data.

export type DemoRowIcon = "ghost" | "github" | "link" | "text" | "image";

export type DemoRow = {
  title: string;
  kind: string;
  icon: DemoRowIcon;
  /** CSS background for the icon tile. */
  tint: string;
};

type SceneBase = {
  id: string;
  chip: string;
  placeholder: string;
  /** Screens other than the root search show a back chevron instead of the magnifier. */
  isSubscreen: boolean;
  query: string;
  section: string;
  action: string;
};

export type DemoScene =
  | (SceneBase & { body: "rows"; rows: DemoRow[] })
  | (SceneBase & { body: "calculator"; from: string; to: string })
  | (SceneBase & { body: "emoji"; emoji: string[] });

export const demoScenes: DemoScene[] = [
  {
    id: "apps",
    chip: "Open an app",
    placeholder: "Search for apps and commands…",
    isSubscreen: false,
    query: "gh",
    section: "Applications",
    action: "Open Application",
    body: "rows",
    rows: [
      {
        title: "Ghostty",
        kind: "Application",
        icon: "ghost",
        tint: "linear-gradient(160deg, #3d5afe, #0d1b6e)",
      },
      {
        title: "GitHub Desktop",
        kind: "Application",
        icon: "github",
        tint: "linear-gradient(160deg, #a875ff, #5b12bd)",
      },
      {
        title: "Search GitHub",
        kind: "Quicklink",
        icon: "link",
        tint: "linear-gradient(160deg, #47bfff, #1769aa)",
      },
    ],
  },
  {
    id: "calculator",
    chip: "Do the math",
    placeholder: "Search for apps and commands…",
    isSubscreen: false,
    query: "560 km to mi",
    section: "Calculator",
    action: "Copy Answer",
    body: "calculator",
    from: "560 km",
    to: "347.9678677 mi",
  },
  {
    id: "clipboard",
    chip: "Paste from history",
    placeholder: "Type to filter entries…",
    isSubscreen: true,
    query: "tiny",
    section: "Today",
    action: "Paste",
    body: "rows",
    rows: [
      {
        title: "github.com/abue-ammar/tinycast",
        kind: "Link",
        icon: "link",
        tint: "rgb(255 255 255 / 0.1)",
      },
      {
        title: "brew install --cask tinycast",
        kind: "Text",
        icon: "text",
        tint: "rgb(255 255 255 / 0.1)",
      },
      {
        title: "tinycast-launcher.png",
        kind: "Image",
        icon: "image",
        tint: "linear-gradient(135deg, #863bff, #47bfff)",
      },
    ],
  },
  {
    id: "emoji",
    chip: "Find an emoji",
    placeholder: "Search emoji and symbols…",
    isSubscreen: true,
    query: "party",
    section: "Emoji",
    action: "Paste",
    body: "emoji",
    emoji: ["🎉", "🥳", "🎊", "🪅", "🎈", "🍾", "🪩", "🎂"],
  },
];
