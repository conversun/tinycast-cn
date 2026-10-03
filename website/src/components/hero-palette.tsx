import {
  AudioLines,
  Gem,
  Ghost,
  Hammer,
  Orbit,
  Search,
  Shield,
} from "lucide-react";
import type { ComponentType } from "react";
import {
  demoAction,
  demoQuery,
  demoSections,
  type DemoRow,
  type DemoRowIcon,
} from "../data/demo";
import { cn } from "../lib/cn";

const rowIcons: Record<DemoRowIcon, ComponentType<{ size?: number }>> = {
  ghost: Ghost,
  hammer: Hammer,
  shield: Shield,
  gem: Gem,
  orbit: Orbit,
  audio: AudioLines,
};

function MenuGlyph() {
  return (
    <span className="flex flex-col items-start gap-[3px]">
      <span className="h-[1.5px] w-3.5 rounded-full bg-current" />
      <span className="h-[1.5px] w-2 rounded-full bg-current" />
    </span>
  );
}

function Keycap({ children }: { children: string }) {
  return (
    <span className="inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-[6px] border border-(--glass-border) px-1 text-demo-key text-(--glass-fg-muted)">
      {children}
    </span>
  );
}

// The icon fills 22 of its 26px slot, the margin macOS app icons carry
// inside their canvas.
function RowIcon({ row }: { row: DemoRow }) {
  const Icon = rowIcons[row.icon];
  return (
    <span className="flex size-[26px] shrink-0 items-center justify-center">
      <span
        className="glass-app-icon flex size-[22px] items-center justify-center rounded-[5px] text-white"
        style={{ background: row.tint }}
      >
        <Icon size={13} />
      </span>
    </span>
  );
}

function ResultRow({ row, isSelected }: { row: DemoRow; isSelected: boolean }) {
  return (
    <li
      className={cn(
        "flex items-center gap-2.5 rounded-[10px] px-2 py-1.5",
        isSelected && "bg-(--glass-selection)",
      )}
    >
      <RowIcon row={row} />
      <span className="min-w-0 truncate text-demo-row text-(--glass-fg)">
        {row.title}
      </span>
      {row.hotkey && (
        <span className="flex shrink-0 gap-0.5">
          {row.hotkey.map((key) => (
            <Keycap key={key}>{key}</Keycap>
          ))}
        </span>
      )}
      <span className="ml-auto shrink-0 text-demo-callout text-(--glass-fg-muted)">
        {row.kind}
      </span>
    </li>
  );
}

// The palette as the app draws it. No rule anywhere inside: the real window
// separates its search field, list and action bar with spacing alone, and a
// hairline is the one thing that makes a mock read as a web card.
export function HeroPalette() {
  return (
    <div
      aria-hidden="true"
      className="glass-palette w-full rounded-[26px] text-left"
    >
      <span aria-hidden="true" className="glass-grain" />

      {/* The glyph's left edge lines up with the row icons below it. */}
      <div className="mt-1.5 flex h-10 items-center gap-2 px-4">
        <Search
          size={22}
          strokeWidth={1.75}
          className="shrink-0 text-(--glass-fg-muted)"
        />
        <span className="flex min-w-0 flex-1 items-center text-demo-query text-(--glass-fg)">
          <span className="truncate">{demoQuery}</span>
          <span className="demo-caret ml-px h-[1.1em] w-0.5 shrink-0 rounded-full bg-violet-bright" />
        </span>
      </div>

      {/* The last row sits on the footer's line, dissolving under its
          floating controls the way an overflowing list does in the app. */}
      <div className="glass-dissolve px-2 pb-2">
        {demoSections.map((section, sectionIndex) => (
          <div key={section.title}>
            <p
              className={cn(
                "px-2 pb-1 text-demo-section font-medium text-(--glass-fg-muted)",
                sectionIndex === 0 ? "pt-1" : "pt-3",
              )}
            >
              {section.title}
            </p>
            <ul>
              {section.rows.map((row, rowIndex) => (
                <ResultRow
                  key={row.title}
                  row={row}
                  isSelected={sectionIndex === 0 && rowIndex === 0}
                />
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="absolute inset-x-0 bottom-0 flex h-[52px] items-center justify-between px-2">
        <span className="glass-control flex size-9 items-center justify-center rounded-full text-(--glass-fg-muted)">
          <MenuGlyph />
        </span>
        <span className="glass-control flex items-center gap-0.5 rounded-full p-1 text-demo-callout font-medium">
          <span className="flex h-7 items-center gap-1.5 px-2 text-(--glass-fg)">
            {demoAction}
            <Keycap>↵</Keycap>
          </span>
          <span className="flex h-7 items-center gap-1.5 px-2 text-(--glass-fg-muted)">
            Actions
            <span className="flex gap-0.5">
              <Keycap>⌘</Keycap>
              <Keycap>K</Keycap>
            </span>
          </span>
        </span>
      </div>
    </div>
  );
}
