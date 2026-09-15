"use client";

import { Check, Copy } from "lucide-react";
import { useState } from "react";
import { cn } from "../../lib/cn";

const copiedResetMs = 1600;

// Copies `text` and says so for a moment. Styled by the caller, because it sits
// on the always-dark terminal as well as on the themed page.
export function CopyButton({
  text,
  className,
}: {
  text: string;
  className?: string;
}) {
  const [hasCopied, setHasCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      setHasCopied(true);
      setTimeout(() => setHasCopied(false), copiedResetMs);
    } catch (error) {
      // Insecure contexts and denied permissions land here. The command stays
      // on screen to select by hand, so a log is all this needs.
      console.warn("Copy to clipboard failed", error);
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      aria-label={hasCopied ? "Copied" : "Copy command"}
      className={cn(
        "inline-flex h-7 items-center gap-1.5 rounded-full px-2.5 text-caption font-medium transition-colors",
        className,
      )}
    >
      {hasCopied ? (
        <Check size={13} strokeWidth={2.4} className="text-violet-bright" />
      ) : (
        <Copy size={13} strokeWidth={2} />
      )}
      {hasCopied ? "Copied" : "Copy"}
    </button>
  );
}
