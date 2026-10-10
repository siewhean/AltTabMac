// Shared by the homepage beta section and the /waitlist page, so the plain
// statements about permissions, privacy and price cannot drift apart.
export const betaHonestyPoints = [
  {
    title: "What it asks for",
    body: "Accessibility (to detect your shortcut and focus the window you pick) and Screen Recording (to draw previews). Without Screen Recording, windows still appear with icons.",
  },
  {
    title: "What it never collects",
    body: "Optional telemetry is off by default. It never includes window titles, previews, screenshots, keystrokes, clipboard contents, or search queries.",
  },
  {
    title: "What it will cost",
    body: "Planned: a 14-day trial, then a one-time US$12 license for up to three of your Macs and all 1.x updates. No subscription. 14-day refund.",
  },
] as const;
