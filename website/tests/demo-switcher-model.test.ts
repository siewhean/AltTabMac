import assert from "node:assert/strict";
import test from "node:test";
import { activateDemoWindow, navigateDemo, normalizedDemoQuery, orderDemoWindows, rankDemoWindows, removeDemoTarget, type DemoWindow } from "../src/lib/demo-switcher-model";
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
