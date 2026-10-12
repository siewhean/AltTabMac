/** Browser-only sample windows. Search scoring follows Sources/CmdTab/PaletteSearch.swift. */
export interface DemoWindow {
  readonly id: string;
  readonly app: string;
  readonly title: string;
  readonly accent: string;
  readonly pill: string;
  readonly preview: "finder" | "conversation" | "code" | "document" | "calendar";
}
export type DemoMode = "classicGrid" | "commandPalette" | "radialMenu";
export function normalizedDemoQuery(query: string): string {
  return query.toLowerCase().replace(/\s/g, "");
}
function similarity(query: string, text: string): number {
  const source = Array.from(normalizedDemoQuery(text));
  const needle = Array.from(query);
  let previous = Array<number>(source.length + 1).fill(0);
  let strongest = 0;
  for (const letter of needle) {
    const row = Array<number>(source.length + 1).fill(0);
    for (let j = 1; j <= source.length; j++) {
      row[j] = Math.max(0, previous[j - 1] + (letter === source[j - 1] ? 2 : -1), previous[j] - 2, row[j - 1] - 2);
      strongest = Math.max(strongest, row[j]);
    }
    previous = row;
  }
  return strongest / Math.max(1, 2 * needle.length);
}
function acronymBonus(query: string, text: string): number {
  if (text.toLowerCase().startsWith(query)) return 6 + Math.min(2, Array.from(query).length * 0.25);
  const chars = Array.from(text);
  const alphanumeric = (value: string) => /[\p{L}\p{N}]/u.test(value);
  const starts = chars.filter((char, index) => alphanumeric(char) && (index === 0 || !alphanumeric(chars[index - 1]) || (/[\p{Ll}]/u.test(chars[index - 1]) && /[\p{Lu}]/u.test(char)))).map((char) => char.toLowerCase());
  let cursor = 0;
  let first = -1;
  const needle = Array.from(query);
  starts.forEach((char, index) => {
    if (cursor < needle.length && char === needle[cursor]) {
      if (first < 0) first = index;
      cursor++;
    }
  });
  return cursor === needle.length ? 4 + Math.min(2, needle.length * 0.2) + (first === 0 ? 1 : Math.max(0, 0.6 - first * 0.15)) : 0;
}
export function rankDemoWindows(windows: readonly DemoWindow[], query: string, rememberedID?: string): DemoWindow[] {
  const normalized = normalizedDemoQuery(query);
  if (!normalized) return [...windows];
  const ranked = windows.map((window, index) => ({ window, index, score: Math.max(similarity(normalized, window.app) * 1.02, similarity(normalized, window.title)) + Math.max(acronymBonus(normalized, window.app), acronymBonus(normalized, window.title)) })).filter((entry) => entry.score >= 0.4).sort((a, b) => b.score - a.score || a.index - b.index);
  const remembered = ranked.findIndex((entry) => entry.window.id === rememberedID);
  if (remembered > 0 && ranked[0].score - ranked[remembered].score <= 0.05) ranked.unshift(...ranked.splice(remembered, 1));
  return ranked.map((entry) => entry.window);
}
export function navigateDemo(index: number, count: number, key: string, mode: DemoMode, columns = 2): number {
  if (!count) return 0;
  if (mode === "classicGrid" && (key === "ArrowUp" || key === "ArrowDown")) {
    const width = Math.max(1, Math.min(columns, count));
    if (key === "ArrowDown") return index + width < count ? index + width : index % width;
    if (index >= width) return index - width;
    let bottom = index;
    while (bottom + width < count) bottom += width;
    return bottom;
  }
  const step = key === "ArrowLeft" || key === "ArrowUp" ? -1 : 1;
  return (index + step + count) % count;
}
export function activateDemoWindow(windows: readonly DemoWindow[], id: string): DemoWindow[] {
  const target = windows.find((window) => window.id === id);
  return target ? [target, ...windows.filter((window) => window.id !== id)] : [...windows];
}
/** Native forward invocation puts the exact currently focused window last. */
export function orderDemoWindows(windows: readonly DemoWindow[], frontmostID: string): DemoWindow[] {
  return [...windows.filter((window) => window.id !== frontmostID), ...windows.filter((window) => window.id === frontmostID)];
}
export function removeDemoTarget(windows: readonly DemoWindow[], target: DemoWindow, scope: "window" | "app"): DemoWindow[] {
  return windows.filter((window) => scope === "app" ? window.app !== target.app : window.id !== target.id);
}
