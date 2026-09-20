"use client";

import { useEffect, useState, type ReactNode } from "react";
import type { Plan } from "../../data/support";
import { CheckoutCard } from "./checkout-card";
import { ThankYou } from "./thank-you";

const THANKS_PARAM = "thanks";

function parsePlan(value: string | null): Plan | null {
  return value === "monthly" || value === "one-time" ? value : null;
}

type Props = {
  intro: ReactNode;
  reasons: ReactNode;
};

/** `intro` and `reasons` are server-rendered and passed through, so only the card ships as JS. */
export function SupportFlow({ intro, reasons }: Props) {
  const [returned, setReturned] = useState<Plan | null>(null);

  // Polar's return adds ?thanks=<plan>; drop it so a reload shows the card again.
  useEffect(() => {
    const url = new URL(window.location.href);
    const plan = parsePlan(url.searchParams.get(THANKS_PARAM));
    if (!plan) return;
    url.searchParams.delete(THANKS_PARAM);
    window.history.replaceState(window.history.state, "", url);
    // oxlint-disable-next-line react/set-state-in-effect -- URL is only readable after hydration
    setReturned(plan);
  }, []);

  // Phones read intro → card → reasons; from lg the card holds the right column beside both.
  return (
    <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_420px] lg:gap-x-20 lg:gap-y-14">
      {intro}
      <div className="relative lg:col-start-2 lg:row-span-2 lg:row-start-1">
        <span
          aria-hidden="true"
          className="mark-bloom pointer-events-none absolute inset-x-0 -top-16 h-72 opacity-60"
        />
        <div className="relative lg:sticky lg:top-20">
          {returned ? <ThankYou plan={returned} /> : <CheckoutCard />}
        </div>
      </div>
      {reasons}
    </div>
  );
}
