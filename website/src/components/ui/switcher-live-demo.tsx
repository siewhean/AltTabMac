"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { interactiveDemoWindows } from "@/content/home";
import { demoNavigationDirection } from "@/lib/demo-keyboard-navigation";
import { trackSiteEvent } from "@/lib/site-analytics-client";

// ─── Types ───────────────────────────────────────────────────────────────────

type DemoMode = "classicGrid" | "commandPalette" | "radialMenu";

interface DemoWindow {
  readonly id: string;
  readonly app: string;
  readonly title: string;
  readonly accent: string;
  readonly pill: string;
}

// ─── App icons (emoji stand-ins that match the real app icons' colours) ──────

const APP_ICONS: Record<string, string> = {
  Claude: "🟡",
  Telegram: "🔵",
  "VS Code": "🩵",
  PDFGear: "🔴",
  Mimestream: "🟣",
  Spotify: "🟢",
  NotebookLM: "🟤",
  Calendar: "🟠",
};

// ─── Radial positions – evenly spaced on the ring ────────────────────────────

const RADIAL_POSITIONS = [
  { x: 50, y: 14 },
  { x: 78, y: 22 },
  { x: 86, y: 50 },
  { x: 78, y: 78 },
  { x: 50, y: 86 },
  { x: 22, y: 78 },
  { x: 14, y: 50 },
  { x: 22, y: 22 },
];

// ─── Fake preview content bars ───────────────────────────────────────────────

const PREVIEW_BARS = [
  ["78%", "58%", "86%", "44%"],
  ["66%", "82%", "52%", "70%"],
  ["72%", "46%", "88%", "60%"],
  ["84%", "62%", "44%", "78%"],
  ["58%", "76%", "64%", "82%"],
  ["88%", "52%", "72%", "56%"],
  ["64%", "84%", "56%", "76%"],
  ["74%", "60%", "80%", "50%"],
] as const;

// ─── Search filtering (mirrors the Swift PaletteSearch logic) ─────────────────

function searchWindows(query: string): DemoWindow[] {
  const needle = query.trim().toLowerCase();
  if (!needle) return [...interactiveDemoWindows] as DemoWindow[];

  return ([...interactiveDemoWindows] as DemoWindow[])
    .map((item) => {
      const appName = item.app.toLowerCase();
      const windowTitle = item.title.toLowerCase();
      if (appName.startsWith(needle)) return { item, rank: 0 };
      if (appName.includes(needle)) return { item, rank: 1 };
      if (windowTitle.includes(needle)) return { item, rank: 2 };
      return null;
    })
    .filter(Boolean)
    .sort((a, b) => a!.rank - b!.rank)
    .map((r) => r!.item);
}

// ─── Mode labels ──────────────────────────────────────────────────────────────

const MODE_META: Record<DemoMode, { label: string; kbd: string; hint: string }> = {
  classicGrid: {
    label: "Classic Grid",
    kbd: "⌘ Tab",
    hint: "Click a card or use Tab / arrow keys to move the selection. Release to switch.",
  },
  commandPalette: {
    label: "Command Palette",
    kbd: "⌘ Space",
    hint: "Type an app name, use ↑ ↓ to navigate, then press Return to activate.",
  },
  radialMenu: {
    label: "Radial Menu",
    kbd: "⌥ Tab",
    hint: "Click an icon around the ring or use ← → to spin through apps.",
  },
};

const MODES: DemoMode[] = ["classicGrid", "commandPalette", "radialMenu"];

// ─── Auto-play sequence ───────────────────────────────────────────────────────

type AutoStep =
  | { mode: "classicGrid"; select: number }
  | { mode: "commandPalette"; query: string; select: number }
  | { mode: "radialMenu"; select: number };

const AUTO_SEQUENCE: AutoStep[] = [
  { mode: "classicGrid", select: 0 },
  { mode: "classicGrid", select: 2 },
  { mode: "classicGrid", select: 5 },
  { mode: "commandPalette", query: "", select: 0 },
  { mode: "commandPalette", query: "c", select: 0 },
  { mode: "commandPalette", query: "cl", select: 0 },
  { mode: "commandPalette", query: "cla", select: 0 },
  { mode: "commandPalette", query: "clau", select: 0 },
  { mode: "commandPalette", query: "claud", select: 0 },
  { mode: "radialMenu", select: 0 },
  { mode: "radialMenu", select: 2 },
  { mode: "radialMenu", select: 5 },
  { mode: "radialMenu", select: 7 },
  { mode: "classicGrid", select: 1 },
];

const AUTO_STEP_DURATION_MS = 820;
const MODE_TRANSITION_OUT_MS = 110;
const MODE_TRANSITION_IN_MS = 220;

// ─── Component ────────────────────────────────────────────────────────────────

export function SwitcherLiveDemo() {
  const [mode, setMode] = useState<DemoMode>("classicGrid");
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [query, setQuery] = useState("");
  const [autoPlaying, setAutoPlaying] = useState(true);
  const [stagePhase, setStagePhase] = useState<"steady" | "out" | "in">("steady");
  const demoRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const lastTrackedSearchBucket = useRef<string | null>(null);
  const modeTransitionTimeouts = useRef<number[]>([]);

  // ── Derived state ──────────────────────────────────────────────────────────

  const filteredWindows = useMemo(() => searchWindows(query), [query]);
  const clampedIndex = Math.min(selectedIndex, Math.max(0, filteredWindows.length - 1));
  const activeIndex = mode === "commandPalette" ? clampedIndex : selectedIndex % interactiveDemoWindows.length;
  const activeWindow =
    mode === "commandPalette"
      ? filteredWindows[activeIndex] ?? (interactiveDemoWindows[0] as DemoWindow)
      : (interactiveDemoWindows[activeIndex] as DemoWindow);

  // ── Auto-play ──────────────────────────────────────────────────────────────

  const clearModeTransition = useCallback(() => {
    for (const timeout of modeTransitionTimeouts.current) {
      window.clearTimeout(timeout);
    }
    modeTransitionTimeouts.current = [];
  }, []);

  const applyDemoState = useCallback(
    ({
      nextMode,
      nextSelectedIndex,
      nextQuery,
      animateModeShift = true,
    }: {
      nextMode: DemoMode;
      nextSelectedIndex: number;
      nextQuery: string;
      animateModeShift?: boolean;
    }) => {
      const commit = () => {
        setMode(nextMode);
        setSelectedIndex(nextSelectedIndex);
        setQuery(nextQuery);
      };

      if (!animateModeShift || nextMode === mode) {
        clearModeTransition();
        setStagePhase("steady");
        commit();
        return;
      }

      clearModeTransition();
      setStagePhase("out");

      const swapTimeout = window.setTimeout(() => {
        commit();
        setStagePhase("in");

        const settleTimeout = window.setTimeout(() => {
          setStagePhase("steady");
        }, MODE_TRANSITION_IN_MS);
        modeTransitionTimeouts.current.push(settleTimeout);
      }, MODE_TRANSITION_OUT_MS);

      modeTransitionTimeouts.current.push(swapTimeout);
    },
    [clearModeTransition, mode]
  );

  useEffect(() => {
    return () => clearModeTransition();
  }, [clearModeTransition]);

  useEffect(() => {
    if (!autoPlaying) return;

    const id = setInterval(() => {
      const currentIndex = AUTO_SEQUENCE.findIndex((step) => {
        if (step.mode !== mode) return false;
        if (step.mode === "commandPalette") {
          return step.query === query && step.select === selectedIndex;
        }
        return step.select === selectedIndex;
      });
      const nextIndex = (currentIndex + 1 + AUTO_SEQUENCE.length) % AUTO_SEQUENCE.length;
      const step = AUTO_SEQUENCE[nextIndex];
      applyDemoState({
        nextMode: step.mode,
        nextSelectedIndex: step.select,
        nextQuery: step.mode === "commandPalette" ? step.query : "",
      });
    }, AUTO_STEP_DURATION_MS);

    return () => clearInterval(id);
  }, [applyDemoState, autoPlaying, mode, query, selectedIndex]);

  const stopAutoPlay = useCallback(() => {
    if (autoPlaying) setAutoPlaying(false);
  }, [autoPlaying]);

  // ── Keyboard handler ───────────────────────────────────────────────────────

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      // Only intercept when focus is inside the demo container
      if (!demoRef.current?.contains(document.activeElement)) return;
      if (mode === "commandPalette" && document.activeElement === inputRef.current) return;

      const collection = mode === "commandPalette" ? filteredWindows : [...interactiveDemoWindows];
      const count = collection.length;
      if (count === 0) return;

      const direction = demoNavigationDirection(e);
      if (direction === "next") {
        e.preventDefault();
        stopAutoPlay();
        setSelectedIndex((i) => (i + 1) % count);
      } else if (direction === "previous") {
        e.preventDefault();
        stopAutoPlay();
        setSelectedIndex((i) => (i - 1 + count) % count);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mode, filteredWindows, stopAutoPlay]);

  // ── Helpers ────────────────────────────────────────────────────────────────

  function switchMode(next: DemoMode) {
    stopAutoPlay();
    applyDemoState({
      nextMode: next,
      nextSelectedIndex: 0,
      nextQuery: next === "commandPalette" ? query : "",
    });
    trackSiteEvent("demo_mode_selected", { mode: next });
  }

  function moveSelection(dir: "prev" | "next") {
    stopAutoPlay();
    const collection = mode === "commandPalette" ? filteredWindows : [...interactiveDemoWindows];
    if (collection.length === 0) return;
    trackSiteEvent("demo_navigation", { mode, direction: dir });
    setSelectedIndex((i) => {
      const base = Math.min(i, collection.length - 1);
      return dir === "next"
        ? (base + 1) % collection.length
        : (base - 1 + collection.length) % collection.length;
    });
  }

  function trackDemoSelection(selectedMode: DemoMode, app: string) {
    trackSiteEvent("demo_selection", {
      mode: selectedMode,
      target: app.toLowerCase().replace(/\s+/g, "_"),
    });
  }

  function trackPaletteSearch(nextQuery: string, resultCount: number) {
    const normalized = nextQuery.trim();
    if (!normalized) {
      lastTrackedSearchBucket.current = null;
      return;
    }

    const queryLengthBucket =
      normalized.length <= 2 ? "1-2" : normalized.length <= 4 ? "3-4" : "5+";
    const resultsBucket =
      resultCount === 0 ? "0" : resultCount <= 2 ? "1-2" : resultCount <= 4 ? "3-4" : "5+";
    const bucket = `${queryLengthBucket}:${resultsBucket}`;
    if (lastTrackedSearchBucket.current === bucket) return;

    lastTrackedSearchBucket.current = bucket;
    trackSiteEvent("demo_palette_search", { queryLengthBucket, resultsBucket });
  }

  // ─── Render ────────────────────────────────────────────────────────────────

  return (
    <div
      ref={demoRef}
      className="overflow-hidden rounded-[32px] border border-white/10 bg-white/[0.04] shadow-panel backdrop-blur-xl"
    >
      {/* ── Header ── */}
      <div className="border-b border-white/8 px-5 py-4 sm:px-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="space-y-1">
            <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-cyan">
              Interactive demo
            </p>
            <h3 className="text-2xl font-medium tracking-[-0.04em] text-text sm:text-[1.75rem]">
              Try each mode live in the browser.
            </h3>
            <p className="max-w-xl text-sm leading-6 text-muted">
              Click a mode tab, interact with the switcher, or just watch the auto-demo run.
              Keyboard navigation works too — use the arrow keys.
            </p>
          </div>

          {/* Mode tabs */}
          <div className="flex flex-wrap gap-2">
            {MODES.map((m) => {
              const active = m === mode;
              return (
                <button
                  key={m}
                  type="button"
                  onClick={() => switchMode(m)}
                  className={`inline-flex min-h-10 flex-col items-start rounded-2xl border px-4 py-2 text-left transition duration-200 ${
                    active
                      ? "border-cyan/50 bg-cyan/12 shadow-halo"
                      : "border-white/10 bg-white/[0.03] hover:border-white/18"
                  }`}
                >
                  <span className={`text-sm font-medium ${active ? "text-text" : "text-muted"}`}>
                    {MODE_META[m].label}
                  </span>
                  <span className="mt-0.5 font-mono text-[10px] tracking-wide text-subdued">
                    {MODE_META[m].kbd}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* ── Main area ── */}
      <div className="grid lg:grid-cols-[minmax(0,1fr)_300px]">

        {/* Left: switcher replica */}
        <div className="relative min-h-[540px] border-b border-white/8 p-5 sm:p-6 lg:min-h-[600px] lg:border-b-0 lg:border-r lg:border-white/8">

          {/* Auto-play badge */}
          {autoPlaying && (
            <div className="absolute right-4 top-4 z-10 flex items-center gap-1.5 rounded-full border border-white/10 bg-slate-950/60 px-3 py-1 backdrop-blur-xs">
              <span className="h-1.5 w-1.5 rounded-full bg-cyan animate-pulse" />
              <span className="text-[10px] font-medium uppercase tracking-[0.2em] text-subdued">
                Auto
              </span>
            </div>
          )}

          <div
            className={`h-full transition-[opacity,transform,filter] duration-300 ease-out ${
              stagePhase === "out"
                ? "translate-y-2 scale-[0.985] opacity-0 blur-[2px]"
                : stagePhase === "in"
                  ? "translate-y-0 scale-100 opacity-100 blur-[0px]"
                  : "translate-y-0 scale-100 opacity-100 blur-[0px]"
            }`}
          >

          {/* ── Classic Grid ── */}
          {mode === "classicGrid" && (
            <div className="grid h-full gap-3 sm:grid-cols-2 xl:grid-cols-4">
              {(interactiveDemoWindows as readonly DemoWindow[]).map((item, idx) => {
                const bars = PREVIEW_BARS[idx % PREVIEW_BARS.length];
                const selected = idx === activeIndex;
                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => {
                      stopAutoPlay();
                      setSelectedIndex(idx);
                      trackDemoSelection("classicGrid", item.app);
                    }}
                    className={`group flex flex-col rounded-[22px] border p-3 text-left transition-[transform,box-shadow,border-color,background-color,opacity] duration-250 ease-out ${
                      selected
                        ? "-translate-y-1 scale-[1.015] border-cyan/60 bg-cyan/[0.07] shadow-[0_0_0_1px_rgba(105,214,255,0.22),0_20px_60px_rgba(4,7,15,0.45)]"
                        : "border-white/10 bg-white/[0.03] opacity-90 hover:-translate-y-0.5 hover:border-white/18 hover:bg-white/[0.05] hover:opacity-100"
                    }`}
                  >
                    {/* Thumbnail */}
                    <div
                      className={`relative mb-2.5 aspect-[4/3] w-full overflow-hidden rounded-[16px] border border-white/8 bg-linear-to-br/srgb ${item.accent}`}
                    >
                      {/* Fake title bar */}
                      <div className="flex items-center justify-between border-b border-white/10 bg-slate-950/60 px-2.5 py-1.5">
                        <div className="flex gap-1">
                          <span className="h-2 w-2 rounded-full bg-white/15" />
                          <span className="h-2 w-2 rounded-full bg-white/15" />
                          <span className="h-2 w-2 rounded-full bg-white/15" />
                        </div>
                        <span className="text-[9px] uppercase tracking-[0.18em] text-subdued">
                          {item.app}
                        </span>
                        <span className="rounded-full border border-white/10 px-1.5 py-0.5 text-[8px] text-subdued">
                          {item.pill}
                        </span>
                      </div>
                      {/* Fake content */}
                      <div className="space-y-2 px-3 pb-3 pt-3">
                        {bars.map((w, bi) => (
                          <div
                            key={bi}
                          className={`h-2 rounded-full transition-all duration-300 ${
                            selected ? "bg-white/[0.16]" : "bg-white/[0.1]"
                          }`}
                          style={{ width: w }}
                        />
                      ))}
                      </div>
                    </div>
                    {/* Label */}
                    <p className="text-sm font-semibold tracking-[-0.02em] text-text">{item.app}</p>
                    <p className="mt-0.5 truncate text-xs leading-5 text-muted">{item.title}</p>
                    {selected && (
                      <span className="mt-1.5 self-start rounded-full border border-cyan/30 bg-cyan/10 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-[0.18em] text-cyan">
                        Selected
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          )}

          {/* ── Command Palette ── */}
          {mode === "commandPalette" && (
            <div className="mx-auto flex h-full max-w-[560px] flex-col">
              {/* Panel chrome */}
              <div className="overflow-hidden rounded-[24px] border border-white/12 bg-slate-950/70 shadow-[0_24px_80px_rgba(4,7,15,0.6)]">
                {/* Search bar */}
                <div className="flex items-center gap-3 border-b border-white/8 px-4 py-3">
                  <svg
                    width="16" height="16" viewBox="0 0 16 16" fill="none"
                    className="shrink-0 text-white/40"
                  >
                    <circle cx="6.5" cy="6.5" r="5" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M10.5 10.5L14 14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  <input
                    ref={inputRef}
                    type="text"
                    value={query}
                    onChange={(e) => {
                      stopAutoPlay();
                      const nextQuery = e.target.value;
                      setQuery(nextQuery);
                      setSelectedIndex(0);
                      trackPaletteSearch(nextQuery, searchWindows(nextQuery).length);
                    }}
                    onKeyDown={(e) => {
                      if (e.key === "ArrowDown") { e.preventDefault(); moveSelection("next"); }
                      else if (e.key === "ArrowUp") { e.preventDefault(); moveSelection("prev"); }
                    }}
                    placeholder="Type to filter…"
                    className="flex-1 bg-transparent font-mono text-sm text-text outline-hidden placeholder:text-white/30"
                    spellCheck={false}
                    autoComplete="off"
                  />
                  {query && (
                    <span className="shrink-0 text-[11px] font-medium text-white/35">
                      {filteredWindows.length} result{filteredWindows.length !== 1 ? "s" : ""}
                    </span>
                  )}
                </div>

                {/* Results list */}
                <div className="max-h-[380px] overflow-y-auto p-2">
                  {filteredWindows.length > 0 ? (
                    filteredWindows.map((item, idx) => {
                      const selected = idx === activeIndex;
                      return (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => {
                            stopAutoPlay();
                            setSelectedIndex(idx);
                            trackDemoSelection("commandPalette", item.app);
                          }}
                          className={`flex w-full items-center gap-3 rounded-[16px] border px-3 py-2.5 text-left transition-[transform,box-shadow,border-color,background-color,opacity] duration-200 ease-out ${
                            selected
                              ? "translate-x-1 scale-[1.01] border-[rgba(105,214,255,0.55)] bg-[rgba(105,214,255,0.08)] shadow-[0_0_0_1px_rgba(105,214,255,0.2),0_6px_30px_rgba(105,214,255,0.12)]"
                              : "border-transparent bg-transparent opacity-90 hover:border-white/8 hover:bg-white/[0.03] hover:opacity-100"
                          }`}
                        >
                          {/* App initial avatar */}
                          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl border border-white/10 bg-white/[0.06] text-base">
                            {APP_ICONS[item.app] ?? item.app[0]}
                          </div>
                          {/* Text */}
                          <div className="min-w-0 flex-1">
                            <p className="truncate text-sm font-semibold tracking-[-0.02em] text-text">
                              {item.app}
                            </p>
                            <p className="truncate text-xs leading-5 text-muted">{item.title}</p>
                          </div>
                          {/* Return hint on selected */}
                          {selected && (
                            <span className="shrink-0 font-mono text-xs text-white/30">↵</span>
                          )}
                        </button>
                      );
                    })
                  ) : (
                    <div className="px-4 py-10 text-center">
                      <p className="text-sm font-medium text-text">No matches</p>
                      <p className="mt-1 text-xs leading-5 text-muted">
                        Try: Claude, Spotify, VS Code…
                      </p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* ── Radial Menu ── */}
          {mode === "radialMenu" && (
            <div className="flex h-full min-h-[480px] items-center justify-center">
              <div className="relative aspect-square w-full max-w-[500px]">
                {/* Outer ring glow */}
                <div className="absolute inset-0 rounded-full border border-white/[0.07] bg-[radial-gradient(circle_at_center,rgba(105,214,255,0.06),transparent_50%)]" />
                <div
                  className="absolute h-[116px] w-[116px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-cyan/30 bg-cyan/[0.05] shadow-[0_0_0_1px_rgba(105,214,255,0.12),0_0_80px_rgba(105,214,255,0.1)] transition-all duration-300 ease-out"
                  style={{
                    left: `${RADIAL_POSITIONS[activeIndex % RADIAL_POSITIONS.length]?.x ?? 50}%`,
                    top: `${RADIAL_POSITIONS[activeIndex % RADIAL_POSITIONS.length]?.y ?? 10}%`,
                  }}
                />

                {/* Centre hub */}
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="flex h-[160px] w-[160px] flex-col items-center justify-center rounded-full border border-white/12 bg-slate-950/80 p-4 text-center shadow-[0_20px_70px_rgba(4,7,15,0.7)] transition-transform duration-300 ease-out">
                    <span className="text-[11px] font-semibold uppercase tracking-[0.26em] text-cyan">
                      Active
                    </span>
                    <span className="mt-2 text-xl font-semibold tracking-[-0.03em] text-text">
                      {activeWindow.app}
                    </span>
                    <span className="mt-1 line-clamp-2 text-[10px] leading-4 text-muted">
                      {activeWindow.title}
                    </span>
                  </div>
                </div>

                {/* Spoke lines */}
                {RADIAL_POSITIONS.map((pos, idx) => {
                  const selected = idx === activeIndex;
                  return (
                    <div
                      key={idx}
                      className={`absolute h-px origin-left transition-[background-color,opacity] duration-300 ease-out ${selected ? "bg-cyan/30" : "bg-white/[0.04]"}`}
                      style={{
                        left: "50%",
                        top: "50%",
                        width: `calc(${Math.hypot(pos.x - 50, pos.y - 50)}% - 80px)`,
                        transform: `rotate(${Math.atan2(pos.y - 50, pos.x - 50) * (180 / Math.PI)}deg)`,
                      }}
                    />
                  );
                })}

                {/* Ring nodes */}
                {(interactiveDemoWindows as readonly DemoWindow[]).slice(0, 8).map((item, idx) => {
                  const selected = idx === activeIndex;
                  const pos = RADIAL_POSITIONS[idx];
                  return (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => {
                        stopAutoPlay();
                        setSelectedIndex(idx);
                        trackDemoSelection("radialMenu", item.app);
                      }}
                      className={`absolute flex h-[86px] w-[86px] -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center rounded-full border text-center transition-[transform,box-shadow,border-color,background-color,opacity] duration-300 ease-out ${
                        selected
                          ? "scale-110 border-cyan/70 bg-cyan/[0.12] shadow-[0_0_0_1px_rgba(105,214,255,0.28),0_16px_50px_rgba(4,7,15,0.5)]"
                          : "border-white/10 bg-white/[0.04] opacity-95 hover:scale-[1.04] hover:border-white/20 hover:bg-white/[0.07]"
                      }`}
                      style={{ left: `${pos.x}%`, top: `${pos.y}%` }}
                    >
                      <span className="text-xl leading-none">{APP_ICONS[item.app] ?? item.app[0]}</span>
                      <span className="mt-1 max-w-[60px] truncate text-[9px] font-medium uppercase tracking-[0.14em] text-subdued">
                        {item.app.split(" ")[0]}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}
          </div>
        </div>

        {/* ── Right panel: context + controls ── */}
        <div className="flex flex-col justify-between gap-5 p-5 sm:p-6">

          {/* Info cards */}
          <div className="space-y-3">
            {/* Mode info */}
            <div className="rounded-[20px] border border-white/10 bg-white/[0.03] p-4">
              <p className="text-[10px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Mode
              </p>
              <p className="mt-2 text-lg font-semibold tracking-[-0.03em] text-text">
                {MODE_META[mode].label}
              </p>
              <p className="mt-1 text-xs leading-5 text-muted">{MODE_META[mode].hint}</p>
            </div>

            {/* Current selection */}
            <div className="rounded-[20px] border border-white/10 bg-white/[0.03] p-4">
              <p className="text-[10px] font-semibold uppercase tracking-[0.28em] text-cyan">
                Selected
              </p>
              <div className="mt-2 flex items-center gap-2.5 transition-transform duration-300 ease-out">
                <span className="text-2xl leading-none">{APP_ICONS[activeWindow.app] ?? activeWindow.app[0]}</span>
                <div className="min-w-0">
                  <p className="truncate text-base font-semibold tracking-[-0.03em] text-text">
                    {activeWindow.app}
                  </p>
                  <p className="truncate text-xs leading-5 text-muted">{activeWindow.title}</p>
                </div>
              </div>
            </div>

            {/* Keyboard shortcut reminder */}
            <div className="rounded-[20px] border border-white/8 bg-white/[0.02] px-4 py-3">
              <p className="text-[10px] font-semibold uppercase tracking-[0.26em] text-subdued">
                Real shortcut
              </p>
              <p className="mt-1.5 font-mono text-xl font-medium tracking-tight text-text">
                {MODE_META[mode].kbd}
              </p>
            </div>
          </div>

          {/* Step controls */}
          <div className="space-y-3">
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => moveSelection("prev")}
                className="flex flex-1 items-center justify-center gap-2 rounded-full border border-white/12 bg-white/[0.04] py-2.5 text-sm font-medium text-text transition hover:border-white/20 hover:bg-white/[0.08]"
              >
                <span className="text-xs text-subdued">←</span> Prev
              </button>
              <button
                type="button"
                onClick={() => moveSelection("next")}
                className="flex flex-1 items-center justify-center gap-2 rounded-full border border-cyan/40 bg-cyan/[0.1] py-2.5 text-sm font-medium text-text transition hover:border-cyan/60 hover:bg-cyan/[0.16]"
              >
                Next <span className="text-xs text-cyan/60">→</span>
              </button>
            </div>

            {/* Auto-play toggle */}
            <button
              type="button"
              onClick={() => setAutoPlaying((v) => !v)}
              className={`w-full rounded-full border py-2 text-xs font-medium transition ${
                autoPlaying
                  ? "border-white/10 bg-white/[0.04] text-subdued hover:text-muted"
                  : "border-cyan/30 bg-cyan/[0.07] text-cyan hover:bg-cyan/[0.12]"
              }`}
            >
              {autoPlaying ? "Pause auto-demo" : "Resume auto-demo"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
