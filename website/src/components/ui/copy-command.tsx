"use client";

import { Check, Copy, Terminal } from "lucide-react";
import { useState } from "react";

// A terminal-style command row with a copy button. Lives here rather than in
// the install section because the docs install page shows the same commands.
export function CopyCommand({ command }: { command: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(command);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // Insecure contexts and denied permissions both land here; the command
      // is on screen either way, so there is nothing to recover from.
    }
  }

  return (
    <div className="flex items-center gap-3 rounded-lg bg-well px-3 py-2.5 shadow-key">
      <Terminal
        size={15}
        strokeWidth={1.8}
        className="shrink-0 text-fg-subtle"
        aria-hidden="true"
      />
      <code className="min-w-0 flex-1 overflow-x-auto whitespace-pre font-mono text-small text-fg-muted">
        {command}
      </code>
      <button
        type="button"
        onClick={copy}
        aria-label={copied ? "Copied" : "Copy command"}
        className="flex size-7 shrink-0 items-center justify-center rounded-md text-fg-subtle transition-colors hover:bg-tint/5 hover:text-fg"
      >
        {copied ? (
          <Check size={15} strokeWidth={2.2} className="text-violet-bright" />
        ) : (
          <Copy size={15} strokeWidth={1.8} />
        )}
      </button>
    </div>
  );
}
