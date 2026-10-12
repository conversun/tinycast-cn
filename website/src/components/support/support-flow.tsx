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
};

export function SupportFlow({ intro }: Props) {
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

  return (
    <div className="grid items-start gap-10 lg:grid-cols-[minmax(0,1fr)_420px] lg:gap-20">
      {intro}
      <div className="relative">
        <span
          aria-hidden="true"
          className="mark-bloom pointer-events-none absolute inset-x-0 -top-16 h-72 opacity-60"
        />
        <div className="relative lg:sticky lg:top-20">
          {returned ? <ThankYou plan={returned} /> : <CheckoutCard />}
        </div>
      </div>
    </div>
  );
}
