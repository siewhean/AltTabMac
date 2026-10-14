import assert from "node:assert/strict";
import test from "node:test";
import { advanceDemoRadialViewport, resetDemoRadialViewport, selectedDemoRadialIndex, type DemoRadialViewport } from "../src/lib/demo-radial-viewport";

// Mirrors Tests/CmdTabTests/RadialMenuViewportTests.swift.
function moves(direction: number, count: number, itemCount = 12): { state: DemoRadialViewport; selected: number[] } {
  let state = resetDemoRadialViewport(itemCount, 0);
  const selected: number[] = [];
  for (let step = 0; step < count; step++) {
    state = advanceDemoRadialViewport(state, direction, itemCount);
    selected.push(selectedDemoRadialIndex(state));
  }
  return { state, selected };
}

test("viewport starts with the first eight windows", () => {
  const state = resetDemoRadialViewport(12, 0);
  assert.deepEqual(state.visibleIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
  assert.equal(state.selectedSlot, 0);
});

test("first three right moves keep the ring stable", () => {
  const { state, selected } = moves(1, 3);
  assert.deepEqual(selected, [1, 2, 3]);
  assert.deepEqual(state.visibleIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
});

test("fourth right move replaces the opposite slot without rotating the ring", () => {
  const { state } = moves(1, 4);
  assert.equal(state.selectedSlot, 4);
  assert.deepEqual(state.visibleIndices, [8, 1, 2, 3, 4, 5, 6, 7]);
});

test("reversing direction moves to the immediate left neighbour first", () => {
  const { state } = moves(1, 4);
  const reversed = advanceDemoRadialViewport(state, -1, 12);
  assert.equal(selectedDemoRadialIndex(reversed), 3);
  assert.deepEqual(reversed.visibleIndices, [8, 1, 2, 3, 4, 5, 6, 7]);
});

test("first left move keeps the viewport; the fourth begins replacing", () => {
  const first = moves(-1, 1);
  assert.deepEqual(first.selected, [7]);
  assert.deepEqual(first.state.visibleIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
  const { state } = moves(-1, 4);
  assert.equal(state.selectedSlot, 4);
  assert.deepEqual(state.visibleIndices, [11, 1, 2, 3, 4, 5, 6, 7]);
});

test("continuing in one direction reaches every window without duplicates or errors", () => {
  for (const count of [1, 5, 8, 9, 10, 17]) {
    let state = resetDemoRadialViewport(count, 0);
    const seen = new Set([selectedDemoRadialIndex(state)]);
    for (let step = 0; step < count * 4; step++) {
      state = advanceDemoRadialViewport(state, 1, count);
      seen.add(selectedDemoRadialIndex(state));
      assert.equal(new Set(state.visibleIndices).size, state.visibleIndices.length);
      assert.ok(state.visibleIndices.length <= 8);
    }
    assert.equal(seen.size, count);
  }
});

test("a stale viewport resets when the window list shrinks, and empty lists are safe", () => {
  const { state } = moves(1, 6, 12);
  const shrunk = advanceDemoRadialViewport(state, 1, 5);
  assert.equal(shrunk.visibleIndices.length, 5);
  assert.ok(shrunk.visibleIndices.every((index) => index < 5));
  assert.deepEqual(advanceDemoRadialViewport(state, 1, 0).visibleIndices, []);
  assert.equal(selectedDemoRadialIndex(resetDemoRadialViewport(0, 0)), 0);
});
