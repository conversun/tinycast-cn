// Copy for /support. Amounts are whole US dollars; the Worker turns them into Polar's cents.

export type Plan = "monthly" | "one-time";

export const supportHero = {
  eyebrow: "Support",
  title: "Enjoying Tinycast?",
  intro:
    "Tinycast is free and open source. If you enjoy it, consider buying a wallpaper pack and get a discord role. It would help me a lot. Thanks",
} as const;

export const plans: { id: Plan; label: string }[] = [
  { id: "one-time", label: "One-time" },
  { id: "monthly", label: "Monthly" },
];

export const presetAmounts = [5, 10, 25, 50] as const;
export const maxAmount = 10_000;

export const thanks = {
  title: "Thank you.",
  body: "Your wallpapers are ready.",
  next: {
    monthly: [
      "Polar has emailed your receipt.",
      "Your subscription renews each month until canceled. Change or cancel it anytime in your Polar customer portal.",
    ],
    "one-time": [
      "Polar has emailed your receipt.",
      "This was a one-time payment, so nothing will renew.",
    ],
  },
  perks: {
    title: "Download your wallpapers",
    body: "Sign in with your checkout email to download the pack and connect Discord to get your role.",
    action: "Open your Polar portal",
    // Polar's customer portal for the tinycast organization; perks are claimed there.
    href: "https://polar.sh/tinycast/portal",
  },
  share: "Know someone who lives in Spotlight? Tell them about Tinycast.",
} as const satisfies {
  title: string;
  body: string;
  next: Record<Plan, readonly string[]>;
  perks: { title: string; body: string; action: string; href: string };
  share: string;
};
