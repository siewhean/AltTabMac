import assert from "node:assert/strict";
import test from "node:test";
import { demoRadialPosition, DEMO_RADIAL_RADIUS, DEMO_RADIAL_SELECTOR_SIZE } from "../src/lib/demo-radial-layout";

test("radial ordering starts at twelve o'clock and runs clockwise", () => {
  const points = Array.from({ length: 4 }, (_, index) => demoRadialPosition(index, 4));
  assert.deepEqual(points.map(({ x, y }) => [Math.round(x), Math.round(y)]), [[50, 16], [84, 50], [50, 84], [16, 50]]);
});

test("one through eight circular selectors remain on the ring without clipping or overlapping", () => {
  for (let count = 1; count <= 8; count++) {
    const points = Array.from({ length: count }, (_, index) => demoRadialPosition(index, count));
    for (const { x, y } of points) {
      assert.ok(Math.abs(Math.hypot(x - 50, y - 50) - DEMO_RADIAL_RADIUS) < 1e-9);
      assert.ok(x - DEMO_RADIAL_SELECTOR_SIZE / 2 >= 0 && x + DEMO_RADIAL_SELECTOR_SIZE / 2 <= 100);
      assert.ok(y - DEMO_RADIAL_SELECTOR_SIZE / 2 >= 0 && y + DEMO_RADIAL_SELECTOR_SIZE / 2 <= 100);
    }
    for (let first = 0; first < count; first++) {
      for (let second = first + 1; second < count; second++) {
        assert.ok(Math.hypot(points[first].x - points[second].x, points[first].y - points[second].y) > DEMO_RADIAL_SELECTOR_SIZE);
      }
    }
  }
});

test("unsupported counts and indexes fail rather than stacking selectors", () => {
  for (const [index, count] of [[0, 0], [0, 9], [-1, 8], [8, 8], [0.5, 8]]) {
    assert.throws(() => demoRadialPosition(index, count), RangeError);
  }
});
