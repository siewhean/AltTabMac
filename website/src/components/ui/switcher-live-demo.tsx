"use client";

import Image from "next/image";
import { demoRadialPosition, DEMO_RADIAL_SELECTOR_SIZE } from "@/lib/demo-radial-layout";
import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { interactiveDemoWindows } from "@/content/home";
import { activateDemoWindow, navigateDemo, normalizedDemoQuery, orderDemoWindows, rankDemoWindows, removeDemoTarget, type DemoMode, type DemoWindow } from "@/lib/demo-switcher-model";
import { trackSiteEvent } from "@/lib/site-analytics-client";

const MODES: { id: DemoMode; label: string }[] = [
  { id: "classicGrid", label: "Classic Grid" },
  { id: "commandPalette", label: "Command Palette" },
  { id: "radialMenu", label: "Radial Menu" },
];
const radialIcons: Record<string, string> = { Finder: "finder", Claude: "claude", "VS Code": "vscode", PDFGear: "pdfgear", Calendar: "calendar" };
const control = "min-h-10 rounded-xl border border-white/15 px-3 py-2 text-sm text-text hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan disabled:opacity-40";

function SamplePreview({ item }: { item: DemoWindow }) {
  return <div aria-hidden="true" className={`mb-3 aspect-[4/3] overflow-hidden rounded-xl border border-white/10 bg-linear-to-br/srgb ${item.accent}`}>
    <div className="border-b border-white/10 bg-black/30 px-3 py-2 text-[10px] text-muted">{item.title}</div>
    <div className="p-3 text-[10px] leading-5 text-muted">
      {item.preview === "finder" ? <div className="grid grid-cols-2 gap-2">{(item.id === "finder-downloads" ? ["Documents", "Screenshots", "Notes.pdf", "Archive"] : ["Sources", "Tests", "Website", "README.md"]).map((name) => <span key={name}>▰ {name}</span>)}</div>
        : item.preview === "code" ? <pre className="whitespace-pre-wrap font-mono text-cyan/80">{item.id === "vscode-tests" ? "struct SwitcherCycleSession {\n  let items: [SwitcherItem]\n  var selectedIndex: Int\n}" : "<main>\n  <SwitcherLiveDemo />\n</main>"}</pre>
          : item.preview === "conversation" ? <><p className="rounded bg-white/10 p-2">{item.id === "claude-review" ? "Review the switcher checklist." : "Summarize the research notes."}</p><p className="mt-2">{item.id === "claude-review" ? "Check window identity, previews, and keyboard navigation." : "Keep each window distinguishable by its title."}</p></>
            : item.preview === "calendar" ? <div className="grid grid-cols-5 gap-1">{["Mon", "Tue", "Wed", "Thu", "Fri"].map((day) => <div key={day} className="rounded border border-white/10 p-1">{day}<div className="mt-2 rounded bg-cyan/20 p-1">Focus</div></div>)}</div>
              : <div className="rounded bg-white/10 p-3"><strong>Launch notes</strong><p className="mt-2">Window switching · Search · Keyboard navigation</p></div>}
    </div>
  </div>;
}

export function SwitcherLiveDemo() {
  const [mode, setMode] = useState<DemoMode>("classicGrid");
  const [windows, setWindows] = useState<DemoWindow[]>([...interactiveDemoWindows]);
  const [frontmost, setFrontmost] = useState("vscode-tests");
  const [selected, setSelected] = useState(0);
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(true);
  const [hiddenApps, setHiddenApps] = useState<string[]>([]);
  const [minimized, setMinimized] = useState<string[]>([]);
  const [announcement, setAnnouncement] = useState("Sample switcher open. Choose a different window.");
  const memory = useRef<Record<string, string>>({});
  const lastBucket = useRef<string | null>(null);
  const stage = useRef<HTMLDivElement>(null);
  const grid = useRef<HTMLDivElement>(null);
  const reopenButton = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (!open) reopenButton.current?.focus();
  }, [open]);
  const ordered = useMemo(() => orderDemoWindows(windows, frontmost), [windows, frontmost]);
  const results = useMemo(() => mode === "commandPalette" ? rankDemoWindows(ordered, query, memory.current[normalizedDemoQuery(query)]) : ordered, [ordered, mode, query]);
  const activeIndex = Math.min(selected, Math.max(0, results.length - 1));
  const target = results[activeIndex];
  const focused = windows.find((item) => item.id === frontmost);

  function reopen() {
    setOpen(true); setQuery(""); setSelected(0);
    setAnnouncement("Sample switcher open. The current window is last; the first alternative is selected.");
    requestAnimationFrame(() => stage.current?.focus());
  }
  function activate(item: DemoWindow) {
    if (mode === "commandPalette" && normalizedDemoQuery(query)) memory.current[normalizedDemoQuery(query)] = item.id;
    setWindows((current) => activateDemoWindow(current, item.id));
    setFrontmost(item.id); setHiddenApps((current) => current.filter((app) => app !== item.app)); setMinimized((current) => current.filter((id) => id !== item.id));
    setOpen(false); setAnnouncement(`Activated sample window: ${item.app} · ${item.title}.`);
    trackSiteEvent("demo_selection", { mode, target: item.app.toLowerCase().replace(/\s+/g, "_") });
  }
  function move(key: string) {
    const columns = grid.current ? getComputedStyle(grid.current).gridTemplateColumns.split(" ").length : 2;
    setSelected(navigateDemo(activeIndex, results.length, key, mode, columns));
    trackSiteEvent("demo_navigation", { mode, direction: key === "ArrowLeft" || key === "ArrowUp" ? "prev" : "next" });
  }
  function handleKeys(event: KeyboardEvent<HTMLDivElement>) {
    if (!open) return;
    // Tab keeps its browser focus behavior; system shortcuts remain with macOS.
    if (event.nativeEvent.isComposing || event.metaKey || event.ctrlKey || event.altKey) return;
    const element = event.target as HTMLElement;
    if (element !== stage.current && element.tagName !== "INPUT") return;
    if (event.key === "Escape") { event.preventDefault(); setOpen(false); setAnnouncement("Cancelled. The sample focused window has not changed."); }
    else if (event.key === "Enter" && target) { event.preventDefault(); activate(target); }
    else if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) {
      if (element.tagName === "INPUT" && ["ArrowLeft", "ArrowRight"].includes(event.key)) return;
      if (mode === "radialMenu" && ["ArrowUp", "ArrowDown"].includes(event.key)) return;
      event.preventDefault(); move(event.key);
    }
  }
  function action(kind: "hide" | "minimize" | "close" | "quit") {
    if (!target) return;
    if (kind === "hide") setHiddenApps((current) => [...new Set([...current, target.app])]);
    if (kind === "minimize") setMinimized((current) => [...new Set([...current, target.id])]);
    if (kind === "close" || kind === "quit") {
      const remaining = removeDemoTarget(windows, target, kind === "quit" ? "app" : "window");
      setWindows(remaining); setSelected(Math.min(activeIndex, Math.max(0, remaining.length - 1)));
      if (kind === "quit" && focused?.app === target.app || kind === "close" && frontmost === target.id) setFrontmost("");
    }
    setAnnouncement(kind === "hide" ? `Hidden sample app: ${target.app}. All its windows remain available.` : kind === "minimize" ? `Minimized sample window: ${target.title}. Activate it to restore.` : kind === "quit" ? `Quit sample app: ${target.app}. All its windows were removed.` : `Closed sample window: ${target.title}. Other windows remain available.`);
  }
  function reset() {
    setWindows([...interactiveDemoWindows]); setFrontmost("vscode-tests"); setHiddenApps([]); setMinimized([]); memory.current = {}; setQuery(""); setSelected(0); setOpen(true); setAnnouncement("Sample windows reset.");
  }

  return <div data-demo="switcher" className="overflow-hidden rounded-[32px] border border-white/10 bg-white/[0.04] shadow-panel">
    <div className="space-y-4 border-b border-white/10 p-5 sm:p-6">
      <h3 className="text-2xl font-medium text-text">Choose the window, not just the app.</h3>
      <p className="max-w-3xl text-sm leading-6 text-muted">Browser simulation with sample windows and illustrated previews. The Mac app captures real window previews when permissions allow. Your desktop is not accessed here.</p>
      <div className="flex flex-wrap gap-2" role="group" aria-label="Switcher layout">
        {MODES.map((item) => <button key={item.id} type="button" aria-pressed={mode === item.id} className={`${control} ${mode === item.id ? "border-cyan/60 bg-cyan/10" : ""}`} onClick={() => { setMode(item.id); setQuery(""); setSelected(0); setOpen(true); trackSiteEvent("demo_mode_selected", { mode: item.id }); }}>{item.label}</button>)}
      </div>
      <p className="text-xs leading-5 text-muted">Native profiles can use ⌘Tab or ⌥Tab with your chosen layout. In this browser: focus the switcher, use arrows, then Enter. Click a window to activate it. Escape cancels; Tab moves between controls.</p>
    </div>
    <div className="grid lg:grid-cols-[minmax(0,1fr)_280px]">
      <div ref={stage} tabIndex={open ? 0 : -1} aria-label="Sample window switcher" onKeyDown={handleKeys} className="min-w-0 p-5 focus-visible:outline-2 focus-visible:outline-offset-[-4px] focus-visible:outline-cyan sm:p-6">
        {!open ? <div className="flex min-h-[380px] flex-col items-center justify-center gap-4 rounded-2xl border border-white/10 bg-black/20 text-center"><p className="text-xs text-muted">Sample focused window</p><h4 className="text-xl text-text">{focused ? `${focused.app} · ${focused.title}` : "No focused window"}</h4>{focused && <div className="w-64 max-w-full"><SamplePreview item={focused} /></div>}<button ref={reopenButton} type="button" className={control} onClick={reopen}>Open sample switcher</button></div> : <>
          {mode === "commandPalette" && <label className="mb-4 block text-xs text-muted">Search sample windows<input aria-label="Search sample windows" className="mt-2 block w-full rounded-xl border border-white/15 bg-black/30 px-4 py-3 text-base text-text focus-visible:outline-2 focus-visible:outline-cyan" placeholder="App, window title, or acronym (try VS)" autoComplete="off" spellCheck={false} value={query} onChange={(event) => {
            const value = event.target.value.slice(0, 120); setQuery(value); setSelected(0);
            const count = rankDemoWindows(ordered, value).length;
            const length = value.trim().length; const queryLengthBucket = length <= 2 ? "1-2" : length <= 4 ? "3-4" : "5+"; const resultsBucket = count === 0 ? "0" : count <= 2 ? "1-2" : count <= 4 ? "3-4" : "5+"; const bucket = `${queryLengthBucket}:${resultsBucket}`;
            if (length && lastBucket.current !== bucket) { trackSiteEvent("demo_palette_search", { queryLengthBucket, resultsBucket }); lastBucket.current = bucket; }
            if (!length) lastBucket.current = null;
          }} /></label>}
          {!results.length ? <p className="py-12 text-center text-muted">{windows.length ? "No matches. Try an app name, window title, or acronym." : "No sample windows remain. Reset the demo to try again."}</p>
            : <div ref={grid} className={mode === "classicGrid" ? "grid grid-cols-1 gap-3 sm:grid-cols-2" : mode === "radialMenu" ? "relative mx-auto aspect-square w-full max-w-[480px]" : "space-y-2"}>
              {mode === "radialMenu" && <div className="pointer-events-none absolute inset-[34%] flex flex-col items-center justify-center rounded-full border border-white/10 bg-black/20 px-2 text-center"><p className="hidden text-xs text-muted sm:block">Selected window</p><p className="mt-1 text-xs font-semibold text-text sm:text-sm">{target?.app}</p><p className="mt-1 line-clamp-2 max-w-full break-words text-[10px] leading-tight text-muted sm:text-xs" title={target?.title}>{target?.title}</p>{target && (hiddenApps.includes(target.app) || minimized.includes(target.id)) && <p className="mt-1 text-[9px] text-cyan">{[hiddenApps.includes(target.app) && "Hidden app", minimized.includes(target.id) && "Minimized"].filter(Boolean).join(" · ")}</p>}</div>}
              {results.map((item, index) => {
                const status = [hiddenApps.includes(item.app) && "Hidden app", minimized.includes(item.id) && "Minimized window"].filter(Boolean).join(" · ");
                if (mode === "radialMenu") {
                  const position = demoRadialPosition(index, results.length);
                  return <div key={item.id} data-demo-radial-node className="absolute aspect-square -translate-x-1/2 -translate-y-1/2" style={{ width: `max(44px, ${DEMO_RADIAL_SELECTOR_SIZE}%)`, left: `${position.x}%`, top: `${position.y}%` }}>
                    <button data-demo-window-id={item.id} data-demo-radial-selector type="button" title={`${item.app}: ${item.title}`} aria-label={`Activate ${item.app}: ${item.title}${status ? `. ${status}` : ""}`} aria-current={index === activeIndex ? "true" : undefined} onClick={() => activate(item)} className={`absolute inset-0 flex items-center justify-center rounded-full border-2 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan ${index === activeIndex ? "border-cyan bg-cyan/15 shadow-[0_0_24px_rgba(105,214,255,0.15)]" : "border-white/15 bg-slate-950/80 hover:border-white/40 hover:bg-white/10"}`}>
                      <Image data-demo-radial-icon src={`/demo-icons/${radialIcons[item.app]}.png`} width={128} height={128} alt="" aria-hidden="true" draggable={false} className="pointer-events-none h-[72%] w-[72%] object-contain" />
                    </button>
                    <span aria-hidden="true" className={`pointer-events-none absolute left-1/2 top-full mt-1 block w-[125%] -translate-x-1/2 truncate text-center text-[10px] leading-4 sm:text-xs ${index === activeIndex ? "font-semibold text-cyan" : "text-muted"}`}>{item.app}</span>
                  </div>;
                }
                return <button key={item.id} data-demo-window-id={item.id} type="button" title={`${item.app}: ${item.title}`} aria-label={`Activate ${item.app}: ${item.title}`} aria-current={index === activeIndex ? "true" : undefined} onClick={() => activate(item)} className={`w-full rounded-2xl border p-3 text-left focus-visible:outline-2 focus-visible:outline-cyan ${index === activeIndex ? "border-cyan/70 bg-cyan/10" : "border-white/10 bg-slate-950/80"}`}>
                  {mode === "classicGrid" && <SamplePreview item={item} />}
                  <span className="block truncate text-sm font-semibold text-text">{item.app}</span><span className="mt-1 block truncate text-xs text-muted">{item.title}</span>
                  {status && <span className="mt-1 block text-[10px] text-cyan">{status}</span>}
                </button>;
              })}
            </div>}
        </>}
      </div>
      <div className="space-y-4 border-t border-white/10 p-5 lg:border-l lg:border-t-0">
        <p className="text-xs leading-5 text-muted">Windows are ordered by recent use. The currently focused window moves to the end when you reopen. Palette search remembers close-ranked choices during this session.</p>
        <p className="text-sm text-text">Selected: {open && target ? `${target.app} · ${target.title}` : "None"}</p>
        {open && <><div className="flex gap-2"><button type="button" className={control} disabled={!target} onClick={() => move("ArrowLeft")}>Previous</button><button type="button" className={control} disabled={!target} onClick={() => move("ArrowRight")}>Next</button></div><button type="button" className={`${control} w-full border-cyan/40`} disabled={!target} onClick={() => target && activate(target)}>Activate selected window</button><div className="grid grid-cols-2 gap-2">{([ ["hide", "Hide app"], ["minimize", "Minimize window"], ["close", "Close window"], ["quit", "Quit app"] ] as const).map(([kind, label]) => <button key={kind} type="button" className={control} disabled={!target} onClick={() => action(kind)}>{label}</button>)}</div><p className="text-xs leading-5 text-muted">Actions affect sample windows only. Hide and quit apply to the app; minimize and close apply to one window. Native action availability depends on the app and permissions.</p></>}
        <button type="button" className={control} onClick={reset}>Reset sample windows</button>
      </div>
    </div>
    <p role="status" aria-live="polite" aria-atomic="true" className="border-t border-white/10 px-5 py-3 text-sm leading-6 text-muted">{announcement}</p>
  </div>;
}
