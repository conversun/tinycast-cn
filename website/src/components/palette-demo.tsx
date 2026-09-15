"use client";

import {
  ArrowRight,
  ChevronLeft,
  Ellipsis,
  FileText,
  Ghost,
  Image as ImageIcon,
  Link2,
  Search,
} from "lucide-react";
import {
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
  type ComponentType,
  type RefObject,
} from "react";
import {
  demoScenes,
  type DemoRow,
  type DemoRowIcon,
  type DemoScene,
} from "../data/demo";
import { cn } from "../lib/cn";
import { GitHubLogo } from "./ui/icon";

const typingDelayMs = 90;
const holdMs = 3400;

const rowIcons: Record<DemoRowIcon, ComponentType<{ size?: number }>> = {
  ghost: Ghost,
  github: GitHubLogo,
  link: Link2,
  text: FileText,
  image: ImageIcon,
};

const reducedMotionQuery = "(prefers-reduced-motion: reduce)";

function subscribeToReducedMotion(onChange: () => void) {
  const media = window.matchMedia(reducedMotionQuery);
  media.addEventListener("change", onChange);
  return () => media.removeEventListener("change", onChange);
}

function usePrefersReducedMotion() {
  return useSyncExternalStore(
    subscribeToReducedMotion,
    () => window.matchMedia(reducedMotionQuery).matches,
    () => false,
  );
}

// Typing and advancing stop while the demo is off screen, so it costs nothing
// out of view and resumes where it left off.
function useIsOnScreen(ref: RefObject<HTMLElement | null>) {
  const [isOnScreen, setIsOnScreen] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const observer = new IntersectionObserver(([entry]) =>
      setIsOnScreen(entry.isIntersecting),
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, [ref]);

  return isOnScreen;
}

function Keycap({ children }: { children: string }) {
  return (
    <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-lg border border-(--glass-key-border) px-1 text-caption text-(--glass-fg-muted)">
      {children}
    </span>
  );
}

function ResultRow({
  row,
  order,
  isSelected,
}: {
  row: DemoRow;
  order: number;
  isSelected: boolean;
}) {
  const Icon = rowIcons[row.icon];
  return (
    <li
      className={cn(
        "demo-row flex items-center gap-3 rounded-2xl px-3 py-2.5 sm:gap-4 sm:px-4 sm:py-3",
        isSelected && "glass-chip",
      )}
      style={{ animationDelay: `${order * 70}ms` }}
    >
      <span
        className="flex size-7 shrink-0 items-center justify-center rounded-[0.6rem] text-white shadow-sm sm:size-9 sm:rounded-xl"
        style={{ background: row.tint }}
      >
        <Icon size={15} />
      </span>
      <span className="min-w-0 flex-1 truncate text-demo-row text-(--glass-fg)">
        {row.title}
      </span>
      <span className="hidden text-demo-row text-(--glass-fg-subtle) sm:block">
        {row.kind}
      </span>
    </li>
  );
}

function SceneBody({ scene }: { scene: DemoScene }) {
  switch (scene.body) {
    case "rows":
      return (
        <ul className="flex flex-col gap-0.5">
          {scene.rows.map((row, order) => (
            <ResultRow
              key={row.title}
              row={row}
              order={order}
              isSelected={order === 0}
            />
          ))}
        </ul>
      );
    case "calculator":
      return (
        <div className="demo-row glass-chip grid h-24 grid-cols-[1fr_auto_1fr] items-center rounded-3xl px-4 text-center sm:h-36">
          <span className="text-demo-query text-(--glass-fg-muted)">
            {scene.from}
          </span>
          <ArrowRight size={18} className="text-(--glass-fg-subtle)" />
          <span className="text-demo-query font-semibold text-(--glass-fg)">
            {scene.to}
          </span>
        </div>
      );
    case "emoji":
      return (
        <ul className="grid grid-cols-4 gap-2 sm:grid-cols-8">
          {scene.emoji.map((glyph, order) => (
            <li
              key={glyph}
              className={cn(
                "demo-row flex aspect-square items-center justify-center rounded-3xl text-heading lg:text-closing",
                order === 0 ? "glass-chip" : "bg-(--glass-chip-soft)",
              )}
              style={{ animationDelay: `${order * 40}ms` }}
            >
              {glyph}
            </li>
          ))}
        </ul>
      );
  }
}

function Palette({
  scene,
  sceneIndex,
  typedLength,
}: {
  scene: DemoScene;
  sceneIndex: number;
  typedLength: number;
}) {
  const query = scene.query.slice(0, typedLength);
  const hasFinishedTyping = typedLength >= scene.query.length;
  const LeadingIcon = scene.isSubscreen ? ChevronLeft : Search;

  return (
    <div
      aria-hidden="true"
      className="glass-palette flex h-100 w-full flex-col rounded-[2.25rem] p-3 text-left sm:h-128 lg:h-150"
    >
      <span aria-hidden="true" className="glass-grain" />
      <div className="flex items-center gap-3 px-3 pb-3 pt-3 sm:gap-4 sm:px-4 sm:pt-4">
        <LeadingIcon
          size={24}
          className="size-5 shrink-0 text-(--glass-fg-subtle) sm:size-6"
        />
        <span className="flex min-w-0 items-center text-demo-query text-(--glass-fg)">
          {query ? (
            <span className="truncate">{query}</span>
          ) : (
            <span className="truncate text-(--glass-fg-subtle)">
              {scene.placeholder}
            </span>
          )}
          <span
            className={cn(
              "demo-caret ml-px h-[1.15em] w-0.5 shrink-0 rounded-full bg-violet-bright",
              !query && "-order-1 mr-px",
            )}
          />
        </span>
      </div>

      {/* Keyed by scene so each new query replays the rows' entrance. */}
      <div key={sceneIndex} className="min-h-0 flex-1 overflow-hidden px-1">
        {hasFinishedTyping && (
          <>
            <p className="demo-row px-3 pb-2 pt-2 text-small font-semibold text-(--glass-fg-subtle) sm:px-4">
              {scene.section}
            </p>
            <SceneBody scene={scene} />
          </>
        )}
      </div>

      <div className="flex items-center justify-between gap-2 px-1 pb-1">
        <span className="flex size-9 sm:size-11 items-center justify-center rounded-full border border-(--glass-key-border) text-(--glass-fg-muted)">
          <Ellipsis size={16} />
        </span>
        <span className="glass-chip flex items-center gap-3 rounded-full py-1.5 pl-4 pr-2 text-small sm:gap-5 sm:py-2 sm:pl-5 sm:pr-2.5 sm:text-body">
          <span className="flex items-center gap-2 font-medium text-(--glass-fg)">
            {scene.action}
            <Keycap>↵</Keycap>
          </span>
          <span className="hidden items-center gap-2 text-(--glass-fg-muted) sm:flex">
            Actions
            <span className="flex gap-1">
              <Keycap>⌘</Keycap>
              <Keycap>K</Keycap>
            </span>
          </span>
        </span>
      </div>
    </div>
  );
}

export function PaletteDemo() {
  const rootRef = useRef<HTMLDivElement>(null);
  const isOnScreen = useIsOnScreen(rootRef);
  const prefersReducedMotion = usePrefersReducedMotion();
  const [sceneIndex, setSceneIndex] = useState(0);
  const [typedLength, setTypedLength] = useState(0);
  const [isAutoPlaying, setIsAutoPlaying] = useState(true);

  const scene = demoScenes[sceneIndex];
  const shownLength = prefersReducedMotion ? scene.query.length : typedLength;
  const hasFinishedTyping = shownLength >= scene.query.length;
  const isAdvancing = isAutoPlaying && !prefersReducedMotion;

  useEffect(() => {
    if (prefersReducedMotion || !isOnScreen || hasFinishedTyping) return;
    const timer = setTimeout(
      () => setTypedLength((length) => length + 1),
      typingDelayMs,
    );
    return () => clearTimeout(timer);
  }, [prefersReducedMotion, isOnScreen, hasFinishedTyping, typedLength]);

  useEffect(() => {
    if (!isAdvancing || !isOnScreen || !hasFinishedTyping) return;
    const timer = setTimeout(() => {
      setSceneIndex((index) => (index + 1) % demoScenes.length);
      setTypedLength(0);
    }, holdMs);
    return () => clearTimeout(timer);
  }, [isAdvancing, isOnScreen, hasFinishedTyping, sceneIndex]);

  function showScene(index: number) {
    setIsAutoPlaying(false);
    setSceneIndex(index);
    setTypedLength(0);
  }

  const sceneDurationMs = scene.query.length * typingDelayMs + holdMs;

  return (
    <div ref={rootRef}>
      <p className="sr-only">
        A recreation of the Tinycast palette, cycling through opening an app,
        converting units, pasting from clipboard history and finding an emoji.
      </p>
      <div className="relative">
        <span aria-hidden="true" className="glass-backing" />
        <Palette
          scene={scene}
          sceneIndex={sceneIndex}
          typedLength={shownLength}
        />
      </div>

      <div
        className="mt-5 flex flex-wrap items-center justify-center gap-x-6 gap-y-2"
        role="group"
        aria-label="Demo scenes"
      >
        {demoScenes.map((candidate, index) => {
          const isActive = index === sceneIndex;
          return (
            <button
              key={candidate.id}
              type="button"
              aria-pressed={isActive}
              onClick={() => showScene(index)}
              className={cn(
                "relative flex items-center gap-2 py-1 font-mono text-micro uppercase transition-colors",
                isActive ? "text-fg" : "text-fg-muted hover:text-fg",
              )}
            >
              <span aria-hidden="true" className="text-violet-bright">
                +
              </span>
              {candidate.chip}
              {isActive && isAdvancing && (
                <span
                  key={sceneIndex}
                  aria-hidden="true"
                  className="demo-progress absolute inset-x-0 bottom-0 h-px bg-violet"
                  style={{
                    animationDuration: `${sceneDurationMs}ms`,
                    animationPlayState: isOnScreen ? "running" : "paused",
                  }}
                />
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
