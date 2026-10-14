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

export type DemoQuickAction = "hide" | "minimize" | "close" | "quit";

type QuickActionInput = Pick<KeyboardEvent, "key" | "metaKey" | "ctrlKey" | "altKey">;

const QUICK_ACTION_KEYS: Record<string, DemoQuickAction> = { h: "hide", m: "minimize", w: "close", q: "quit" };

/**
 * Mirrors SwitcherQuickAction.action(forKeyCode:keyEquivalent:commandHeld:acceptsBareShortcut:)
 * and ProductionSwitcherWindowController.handlePanelKeyEvent in Sources/CmdTab:
 * - Command Palette never maps letters to actions; they type into search.
 * - H, M, W and Q map to hide, minimize, close and quit, with Command held or bare
 *   (bare means neither Option nor Control is held; Shift is ignored).
 * - Quit is the one destructive action, so a bare Q does nothing.
 */
export function demoQuickActionForKey(
  input: QuickActionInput,
  mode: "classicGrid" | "commandPalette" | "radialMenu",
): DemoQuickAction | null {
  if (mode === "commandPalette") return null;
  const commandHeld = input.metaKey;
  if (!commandHeld && (input.altKey || input.ctrlKey)) return null;
  const action = QUICK_ACTION_KEYS[input.key.toLowerCase()] ?? null;
  if (action === "quit" && !commandHeld) return null;
  return action;
}
