export type DemoNavigationDirection = "next" | "previous";

type KeyboardInput = Pick<KeyboardEvent, "key" | "shiftKey">;

export function demoNavigationDirection(
  input: KeyboardInput,
): DemoNavigationDirection | null {
  switch (input.key) {
    case "ArrowRight":
    case "ArrowDown":
      return "next";
    case "ArrowLeft":
    case "ArrowUp":
      return "previous";
    default:
      return null;
  }
}
