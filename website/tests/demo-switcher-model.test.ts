import assert from "node:assert/strict";
import test from "node:test";
import { activateDemoWindow, DEMO_MIN_SIMILARITY, DEMO_REMEMBERED_PROMOTION_TOLERANCE, demoRelevance, listedDemoWindows, navigateDemo, normalizedDemoQuery, orderDemoWindows, rankDemoWindows, removeDemoTarget, type DemoWindow } from "../src/lib/demo-switcher-model";
import { demoQuickActionForKey } from "../src/lib/demo-keyboard-navigation";
const windows: DemoWindow[] = [
  { id: "finder-one", app: "Finder", title: "Project files", accent: "", pill: "", preview: "finder" },
  { id: "finder-two", app: "Finder", title: "Downloads", accent: "", pill: "", preview: "finder" },
  { id: "editor", app: "VS Code", title: "SwitcherCycleSession.swift", accent: "", pill: "", preview: "code" },
];
test("activation targets one window, preserving siblings and putting current identity last on reopening", () => {
  const activated = activateDemoWindow(windows, "finder-two");
  assert.deepEqual(activated.map((item) => item.id), ["finder-two", "finder-one", "editor"]);
  assert.deepEqual(orderDemoWindows(activated, "finder-two").map((item) => item.id), ["finder-one", "editor", "finder-two"]);
});
test("close removes one window while quit removes all app windows", () => {
  assert.deepEqual(removeDemoTarget(windows, windows[0], "window").map((item) => item.id), ["finder-two", "editor"]);
  assert.deepEqual(removeDemoTarget(windows, windows[0], "app").map((item) => item.id), ["editor"]);
});
test("palette whitespace normalization, acronym, title matching, and stable ties", () => {
  assert.equal(normalizedDemoQuery(" V S\nCode "), "vscode");
  assert.equal(rankDemoWindows(windows, "vs")[0].id, "editor");
  assert.equal(rankDemoWindows(windows, "downloads")[0].id, "finder-two");
  assert.equal(rankDemoWindows(windows, "scs")[0].id, "editor");
  assert.deepEqual(rankDemoWindows(windows, "finder").map((item) => item.id), ["finder-one", "finder-two"]);
  assert.equal(rankDemoWindows(windows, "zzzzzz").length, 0);
});
test("remembered choice only promotes within native tolerance", () => {
  assert.equal(rankDemoWindows(windows, "finder", "finder-two")[0].id, "finder-two");
  assert.equal(rankDemoWindows(windows, "downloads", "finder-one")[0].id, "finder-two");
  assert.deepEqual(rankDemoWindows(windows, "", "finder-two"), windows);
});
test("Smith-Waterman fuzzy matching admits a partial result", () => {
  assert.equal(rankDemoWindows(windows, "findxr")[0].app, "Finder");
});
test("grid vertical navigation wraps within a column including incomplete rows", () => {
  assert.equal(navigateDemo(0, 5, "ArrowUp", "classicGrid", 2), 4);
  assert.equal(navigateDemo(3, 5, "ArrowDown", "classicGrid", 2), 1);
  assert.equal(navigateDemo(4, 5, "ArrowRight", "classicGrid", 2), 0);
  assert.equal(navigateDemo(0, 5, "ArrowLeft", "classicGrid", 2), 4);
  assert.equal(navigateDemo(0, 0, "ArrowRight", "classicGrid", 2), 0);
  assert.equal(navigateDemo(0, 3, "ArrowUp", "commandPalette"), 2);
});
const item = (id: string, app: string, title: string): DemoWindow => ({ id, app, title, accent: "", pill: "", preview: "document" });
test("ports the native PaletteSearchTests cases", () => {
  const settings = [item("settings", "System Settings", "System Settings"), item("safari", "Safari", "Safari"), item("slack", "Slack", "Slack")];
  const ss = rankDemoWindows(settings, "ss").map((entry) => entry.app);
  assert.equal(ss[0], "System Settings");
  assert.ok(ss.includes("Safari"));
  assert.equal(rankDemoWindows(settings, "sl")[0].app, "Slack");
  assert.deepEqual(rankDemoWindows([item("mime", "Mimestream", "Inbox"), item("codex", "OpenAI Codex", "Workspace")], "codex").map((entry) => entry.app), ["OpenAI Codex"]);
  assert.equal(rankDemoWindows([item("anti", "Anti Gravity Agent", "With reference to my code…"), item("nb", "Google NotebookLM", "NotebookLM")], "AntiGravity")[0].app, "Anti Gravity Agent");
  const chrome = item("chrome", "Google Chrome", "Chrome");
  const chat = item("chat", "Chat", "Chat");
  assert.deepEqual(rankDemoWindows([chrome, chat], "ch").map((entry) => entry.id), ["chrome", "chat"]);
  assert.equal(rankDemoWindows([chrome, chat], "ch", "chat")[0].id, "chat");
});
test("scoring constants and formula match PaletteSearch.swift", () => {
  assert.equal(DEMO_MIN_SIMILARITY, 0.4);
  assert.equal(DEMO_REMEMBERED_PROMOTION_TOLERANCE, 0.05);
  // Exact app match: similarity 1 x 1.02 app weight + prefix bonus 6 + min(2, 4 x 0.25).
  assert.ok(Math.abs(demoRelevance({ app: "Chat", title: "x" }, "chat") - (1.02 + 7)) < 1e-9);
  assert.equal(demoRelevance({ app: "VS Code", title: "" }, "v s c o d e"), demoRelevance({ app: "VS Code", title: "" }, "vscode"));
});
test("minimized windows are left out unless the profile includes them", () => {
  assert.deepEqual(listedDemoWindows(windows, ["finder-two"], false).map((entry) => entry.id), ["finder-one", "editor"]);
  assert.deepEqual(listedDemoWindows(windows, ["finder-two"], true).map((entry) => entry.id), ["finder-one", "finder-two", "editor"]);
});
test("quick-action keys follow SwitcherQuickAction: Command or bare H/M/W, Command-Q only, never in Command Palette", () => {
  const key = (value: string, modifiers: Partial<{ metaKey: boolean; ctrlKey: boolean; altKey: boolean }> = {}) => ({ key: value, metaKey: false, ctrlKey: false, altKey: false, ...modifiers });
  assert.equal(demoQuickActionForKey(key("h"), "classicGrid"), "hide");
  assert.equal(demoQuickActionForKey(key("M"), "radialMenu"), "minimize");
  assert.equal(demoQuickActionForKey(key("w", { metaKey: true }), "classicGrid"), "close");
  assert.equal(demoQuickActionForKey(key("q", { metaKey: true }), "radialMenu"), "quit");
  assert.equal(demoQuickActionForKey(key("q"), "classicGrid"), null);
  assert.equal(demoQuickActionForKey(key("h", { altKey: true }), "classicGrid"), null);
  assert.equal(demoQuickActionForKey(key("h", { ctrlKey: true }), "classicGrid"), null);
  assert.equal(demoQuickActionForKey(key("x"), "classicGrid"), null);
  for (const letter of ["h", "m", "w", "q"]) {
    assert.equal(demoQuickActionForKey(key(letter), "commandPalette"), null);
    assert.equal(demoQuickActionForKey(key(letter, { metaKey: true }), "commandPalette"), null);
  }
});
