"use client";

import { ChevronRight } from "lucide-react";
import { useState } from "react";
import {
  brewInstallCommand,
  brewTrustCommand,
  channels,
  quarantineCommand,
  site,
} from "../data/site";
import { CopyButton } from "./ui/copy-button";
import { Section } from "./ui/section";

function PromptLine({ command }: { command: string }) {
  return (
    <span className="block whitespace-pre">
      <span aria-hidden="true" className="select-none text-violet-bright">
        ${" "}
      </span>
      {command}
    </span>
  );
}

// Always dark in both themes: it stands in for Terminal, which people run dark.
function TerminalWindow({ cask }: { cask: string }) {
  const installCommand = brewInstallCommand(cask);
  return (
    <div className="overflow-hidden rounded-2xl bg-[#0c0c0f] shadow-window ring-1 ring-white/10">
      <div className="flex h-11 items-center gap-2 px-4">
        <span aria-hidden="true" className="flex gap-1.5">
          <span className="size-2.5 rounded-full bg-white/15" />
          <span className="size-2.5 rounded-full bg-white/15" />
          <span className="size-2.5 rounded-full bg-white/15" />
        </span>
        <span className="ml-2 text-caption text-white/40">Terminal</span>
        <CopyButton
          text={`${brewTrustCommand} && ${installCommand}`}
          className="ml-auto text-white/60 hover:bg-white/10 hover:text-white"
        />
      </div>
      <pre className="overflow-x-auto px-5 pb-6 pt-2 font-mono text-small leading-7 text-white/85">
        <code>
          <PromptLine command={brewTrustCommand} />
          <PromptLine command={installCommand} />
        </code>
      </pre>
    </div>
  );
}

export function Install() {
  const [activeId, setActiveId] = useState<string>(channels[0].id);
  const channel = channels.find((c) => c.id === activeId) ?? channels[0];

  return (
    <Section
      id="install"
      index={6}
      label="Install"
      title="One command, and you're running."
      intro="Homebrew clears the macOS quarantine flag for you, so Tinycast opens without a warning. After that, it updates itself."
    >
      <div
        className="inline-flex rounded-full bg-tint/5 p-1"
        role="tablist"
        aria-label="Install channel"
      >
        {channels.map((c) => (
          <button
            key={c.id}
            type="button"
            role="tab"
            aria-selected={c.id === activeId}
            onClick={() => setActiveId(c.id)}
            className="h-8 rounded-full px-4 text-small font-medium text-fg-muted transition-colors hover:text-fg aria-selected:bg-canvas aria-selected:text-fg aria-selected:shadow-sm"
          >
            {c.label}
          </button>
        ))}
      </div>

      <div className="mt-4">
        <TerminalWindow cask={channel.cask} />
      </div>
      <p className="mt-3 px-1 text-small text-fg-muted">
        {channel.description}
      </p>

      {/* Homebrew clears quarantine on every install and update, so this only
          ever applies to a hand-downloaded DMG. */}
      <details className="group mt-10 rounded-2xl bg-tint/4 px-5 py-4">
        <summary className="flex cursor-pointer list-none items-center gap-2 text-small font-medium text-fg [&::-webkit-details-marker]:hidden">
          <ChevronRight
            size={15}
            aria-hidden="true"
            className="text-fg-muted transition-transform group-open:rotate-90"
          />
          Installing from the DMG instead?
        </summary>
        <div className="mt-3 pl-6 text-small text-fg-muted">
          <p className="max-w-xl">
            Tinycast is self-signed, so macOS quarantines a copy downloaded by
            hand. Grab it from{" "}
            <a
              href={`${site.repo}/releases`}
              target="_blank"
              rel="noreferrer"
              className="text-fg underline decoration-border-strong underline-offset-4 transition-colors hover:decoration-violet-bright"
            >
              GitHub Releases
            </a>
            , move it to Applications, then clear the flag once:
          </p>
          <div className="mt-3 flex items-center gap-3 rounded-xl bg-canvas px-4 py-2.5">
            <code className="min-w-0 flex-1 overflow-x-auto whitespace-pre font-mono text-small text-fg">
              {quarantineCommand}
            </code>
            <CopyButton
              text={quarantineCommand}
              className="text-fg-muted hover:bg-tint/5 hover:text-fg"
            />
          </div>
        </div>
      </details>
    </Section>
  );
}
