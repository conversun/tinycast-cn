// Copy for /support. Amounts are whole US dollars; the Worker turns them into Polar's cents.

export type Plan = "monthly" | "one-time";

export const supportHero = {
  eyebrow: "Support",
  title: "Enjoying Tinycast?",
  intro:
    "Tinycast is free and open source, and it will stay that way. If it saves you time and you'd like to support its development, you can contribute here. It's optional, and thank you either way.",
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
    body: "Tinycast has no investors, ads or paid tiers. It's made for the people who use it.",
  },
  {
    title: "Native",
    body: "Built with Apple's frameworks for the current version of macOS, so it's fast, small and feels like part of your Mac.",
  },
] as const;

export const runningCosts =
  "Your support also pays the running costs: the yearly Apple Developer Program membership needed to sign and notarize releases, the tinycast.dev domain, and the services the project uses.";

export const thanks = {
  title: "Thank you.",
  body: "Your support goes straight into making Tinycast better.",
  next: {
    monthly: [
      "Polar has emailed your receipt.",
      "It renews each month. Change or cancel it anytime from the link in that email.",
    ],
    "one-time": [
      "Polar has emailed your receipt.",
      "This was a one-time payment, so nothing will renew.",
    ],
  },
  perks: {
    title: "Claim your perks",
    body: "A thank-you download and a supporter role on Discord. Sign in with the email you paid with, then connect Discord to get the role.",
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
