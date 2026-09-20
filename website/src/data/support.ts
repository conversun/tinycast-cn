// Copy for /support. Amounts are whole US dollars; the Worker turns them into Polar's cents.

export type Plan = "monthly" | "one-time";

export const supportHero = {
  eyebrow: "Support",
  title: "Enjoying Tinycast?",
  intro:
    "Tinycast is free and open source, and it stays that way. If it saves you time and you would like to support its development, you can chip in here. Entirely optional, and thank you either way.",
} as const;

export const plans: { id: Plan; label: string }[] = [
  { id: "one-time", label: "One-time" },
  { id: "monthly", label: "Monthly" },
];

export const presetAmounts = [5, 10, 25, 50] as const;
export const maxAmount = 10_000;

export const reasonsLabel = "What you're supporting";

export const supportReasons = [
  {
    title: "Independent",
    body: "No investors, no ads, no upsell. Just an app made for the people who use it.",
  },
  {
    title: "Native",
    body: "Built with Apple's own frameworks, for the current macOS. Fast, small and at home on your Mac.",
  },
] as const;

export const runningCosts =
  "It also covers the running costs: the yearly Apple Developer Program membership, so releases can be properly signed and notarised, the tinycast.dev domain, and the tools and services behind it.";

export const thanks = {
  title: "Thank you.",
  body: "That genuinely means a lot. It goes straight into making Tinycast better.",
  next: {
    monthly: [
      "Polar has emailed your receipt.",
      "It renews each month. Change or cancel it anytime from the link in that email.",
    ],
    "one-time": [
      "Polar has emailed your receipt.",
      "That's it: one payment, nothing recurring.",
    ],
  },
  perks: {
    title: "Claim your perks",
    body: "A thank-you download and a supporter role on Discord. Sign in with the email you paid with, then connect Discord to get the role.",
    action: "Open your Polar portal",
    // Polar's customer portal for the tinycast organization; perks are claimed there.
    href: "https://polar.sh/tinycast/portal",
  },
  share: "Want to help a little more? Tell a friend who lives in Spotlight.",
} as const satisfies {
  title: string;
  body: string;
  next: Record<Plan, readonly string[]>;
  perks: { title: string; body: string; action: string; href: string };
  share: string;
};
