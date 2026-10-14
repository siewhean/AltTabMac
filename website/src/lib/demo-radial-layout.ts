/** Percentage geometry shared by the icon, its circular selector, and its label. */
export const DEMO_RADIAL_SELECTOR_SIZE = 18;
export const DEMO_RADIAL_RADIUS = 34;

export function demoRadialPosition(index: number, count: number) {
  if (!Number.isInteger(count) || count < 1 || count > 8 || !Number.isInteger(index) || index < 0 || index >= count) {
    throw new RangeError("The sample radial layout supports one to eight windows.");
  }
  const angle = index * 2 * Math.PI / count - Math.PI / 2;
  return {
    x: 50 + Math.cos(angle) * DEMO_RADIAL_RADIUS,
    y: 50 + Math.sin(angle) * DEMO_RADIAL_RADIUS,
  };
}
