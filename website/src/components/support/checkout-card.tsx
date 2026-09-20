"use client";

import { LoaderCircle, Lock } from "lucide-react";
import { useEffect, useState } from "react";
import { maxAmount, plans, presetAmounts, type Plan } from "../../data/support";
import { cn } from "../../lib/cn";
import { PolarLogo, SupportIcon } from "../ui/icon";

async function createCheckout(plan: Plan, amount: number): Promise<string> {
  const res = await fetch("/api/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ plan, amount }),
  });
  const body = (await res.json().catch(() => null)) as {
    url?: string;
    error?: string;
  } | null;
  if (!res.ok || !body?.url) {
    throw new Error(body?.error ?? "The checkout could not be opened.");
  }
  return body.url;
}

export function CheckoutCard() {
  const [plan, setPlan] = useState<Plan>("one-time");
  const [preset, setPreset] = useState<number | null>(null);
  const [custom, setCustom] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const amount = preset ?? Number(custom);
  const valid = Number.isInteger(amount) && amount >= 1 && amount <= maxAmount;
  const cadence = plan === "monthly" ? " / month" : "";

  // Back from Polar restores this page from the back-forward cache, spinner and all.
  useEffect(() => {
    const reset = (event: PageTransitionEvent) => {
      if (event.persisted) setPending(false);
    };
    window.addEventListener("pageshow", reset);
    return () => window.removeEventListener("pageshow", reset);
  }, []);

  async function open() {
    if (!valid || pending) return;
    setPending(true);
    setError(null);
    try {
      // Polar's own page, so the address bar shows who takes the payment.
      window.location.assign(await createCheckout(plan, amount));
    } catch (cause) {
      setPending(false);
      setError(
        cause instanceof Error
          ? cause.message
          : "The checkout could not be opened.",
      );
    }
  }

  return (
    <div className="rounded-2xl bg-surface p-5 shadow-key sm:p-6">
      <div
        role="radiogroup"
        aria-label="Frequency"
        className="grid grid-cols-2 gap-1 rounded-full bg-well p-1"
      >
        {plans.map((option) => (
          <button
            key={option.id}
            type="button"
            role="radio"
            aria-checked={plan === option.id}
            onClick={() => setPlan(option.id)}
            className={cn(
              "h-9 rounded-full text-small font-medium transition-colors",
              plan === option.id
                ? "bg-surface text-fg shadow-key"
                : "text-fg-muted hover:text-fg",
            )}
          >
            {option.label}
          </button>
        ))}
      </div>

      <fieldset className="mt-6">
        <legend className="font-mono text-eyebrow uppercase text-fg-muted">
          Amount
        </legend>
        <div className="mt-3 grid grid-cols-4 gap-2">
          {presetAmounts.map((value) => (
            <button
              key={value}
              type="button"
              aria-pressed={preset === value}
              onClick={() => {
                setPreset(value);
                setCustom("");
              }}
              className={cn(
                "h-12 rounded-xl font-mono text-body transition-[box-shadow,color,background-color]",
                preset === value
                  ? "bg-violet/12 text-fg shadow-[inset_0_0_0_1.5px_var(--color-violet)]"
                  : "text-fg-muted shadow-key hover:text-fg hover:shadow-key-hover",
              )}
            >
              ${value}
            </button>
          ))}
        </div>
        <label
          className={cn(
            "mt-2 flex h-12 items-center gap-1 rounded-xl bg-well px-4 transition-shadow",
            "focus-within:shadow-[inset_0_0_0_1.5px_var(--color-violet)]",
            custom !== "" && "shadow-[inset_0_0_0_1.5px_var(--color-violet)]",
          )}
        >
          <span className="font-mono text-body text-fg-subtle">$</span>
          <input
            inputMode="numeric"
            placeholder="Other amount"
            aria-label="Other amount in US dollars"
            value={custom}
            onFocus={() => setPreset(null)}
            onChange={(event) => {
              setPreset(null);
              setCustom(event.target.value.replace(/\D/g, "").slice(0, 5));
            }}
            className="w-full bg-transparent font-mono text-body text-fg outline-none placeholder:font-sans placeholder:text-fg-subtle"
          />
        </label>
      </fieldset>

      <button
        type="button"
        onClick={open}
        disabled={!valid || pending}
        className="mt-6 inline-flex h-12 w-full items-center justify-center gap-2 rounded-full bg-violet text-body font-medium text-white transition-colors hover:bg-violet-deep active:translate-y-px disabled:cursor-not-allowed disabled:opacity-50"
      >
        {pending ? (
          <LoaderCircle size={20} className="animate-spin" />
        ) : (
          <SupportIcon size={20} />
        )}
        {valid ? `Support with $${amount}${cadence}` : "Choose an amount"}
      </button>

      <p
        role="status"
        className={cn(
          "text-center text-small text-fg",
          error ? "mt-3" : "sr-only",
        )}
      >
        {error}
      </p>

      <div className="mt-5 flex flex-wrap items-center justify-center gap-x-1.5 gap-y-1 text-caption text-fg-subtle">
        <Lock size={12} aria-hidden="true" />
        <span>Payments secured by</span>
        <a
          href="https://polar.sh"
          target="_blank"
          rel="noreferrer"
          className="text-fg-muted transition-colors hover:text-fg"
        >
          <PolarLogo height={14} className="translate-y-px" />
        </a>
      </div>
      <p className="mt-1.5 text-center text-caption text-fg-subtle">
        {plan === "monthly"
          ? "Cancel anytime from the link in your receipt."
          : "A single payment. Nothing recurring."}
      </p>
    </div>
  );
}
