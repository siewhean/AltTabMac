/**
 * Port of Sources/CmdTab/RadialMenuViewportState.swift.
 *
 * The ring shows at most eight windows. Selection moves between slots; after four
 * consecutive moves in one direction, the slot opposite the selection is replaced
 * with the next window not yet on the ring, so longer lists scroll through without
 * rotating the whole ring.
 */
export const DEMO_RADIAL_MAX_VISIBLE = 8;
const REPLACEMENT_THRESHOLD = 4;

export interface DemoRadialViewport {
  readonly visibleIndices: readonly number[];
  readonly selectedSlot: number;
  readonly lastDirection: number;
  readonly consecutiveMoves: number;
  readonly nextRightIndex: number | null;
  readonly nextLeftIndex: number | null;
}

export function resetDemoRadialViewport(itemCount: number, selectedIndex: number): DemoRadialViewport {
  const visibleCount = Math.min(DEMO_RADIAL_MAX_VISIBLE, Math.max(0, itemCount));
  return {
    visibleIndices: Array.from({ length: visibleCount }, (_, index) => index),
    selectedSlot: visibleCount === 0 ? 0 : Math.min(Math.max(0, selectedIndex), visibleCount - 1),
    lastDirection: 0,
    consecutiveMoves: 0,
    nextRightIndex: itemCount > visibleCount ? visibleCount % itemCount : null,
    nextLeftIndex: itemCount > visibleCount ? itemCount - 1 : null,
  };
}

/** Returns a new viewport moved by `direction` slots; read the item with `selectedDemoRadialIndex`. */
export function advanceDemoRadialViewport(viewport: DemoRadialViewport, direction: number, itemCount: number): DemoRadialViewport {
  if (itemCount <= 0) return resetDemoRadialViewport(0, 0);
  const visibleCount = Math.min(DEMO_RADIAL_MAX_VISIBLE, itemCount);
  const valid = viewport.visibleIndices.length === visibleCount && viewport.visibleIndices.every((index) => index >= 0 && index < itemCount);
  const start = valid ? viewport : resetDemoRadialViewport(itemCount, Math.min(viewport.selectedSlot, visibleCount - 1));
  const state = {
    visibleIndices: [...start.visibleIndices],
    selectedSlot: start.selectedSlot,
    lastDirection: start.lastDirection,
    consecutiveMoves: start.consecutiveMoves,
    nextRightIndex: start.nextRightIndex,
    nextLeftIndex: start.nextLeftIndex,
  };
  const step = direction >= 0 ? 1 : -1;
  for (let move = 0; move < Math.max(1, Math.abs(direction)); move++) {
    const slots = state.visibleIndices.length;
    state.selectedSlot = (state.selectedSlot + step + slots) % slots;
    if (state.lastDirection === step) state.consecutiveMoves += 1;
    else {
      state.lastDirection = step;
      state.consecutiveMoves = 1;
    }
    if (itemCount <= slots || state.consecutiveMoves < REPLACEMENT_THRESHOLD) continue;
    const replacementSlot = (state.selectedSlot + Math.floor(slots / 2)) % slots;
    const first = step > 0 ? state.nextRightIndex : state.nextLeftIndex;
    if (first === null) continue;
    let candidate = first;
    for (let scanned = 0; scanned < itemCount; scanned++) {
      if (!state.visibleIndices.includes(candidate)) {
        state.visibleIndices[replacementSlot] = candidate;
        if (step > 0) state.nextRightIndex = (candidate + 1) % itemCount;
        else state.nextLeftIndex = (candidate - 1 + itemCount) % itemCount;
        break;
      }
      candidate = (candidate + step + itemCount) % itemCount;
    }
  }
  return state;
}

export function selectedDemoRadialIndex(viewport: DemoRadialViewport): number {
  return viewport.visibleIndices[viewport.selectedSlot] ?? 0;
}
