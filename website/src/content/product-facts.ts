import { commerceContent } from "@/content/commerce";
import { siteConfig } from "@/content/site";

// Version, build, bundle ID, and minimum macOS are checked against
// release/ReleaseConfig.json during every Vercel prebuild.
export const productFacts = {
  name: siteConfig.name,
  category: "native macOS window switcher",
  currentVersion: "1.0.0",
  buildNumber: "1",
  bundleIdentifier: "net.cmdtab.CmdTab",
  minimumMacOS: "macOS 13.0 (Ventura) or later",
  trialLength: commerceContent.trialLength,
  licenseModel: "One-time purchase",
  licensePrice: commerceContent.license.price,
  licensedMacs: 3,
  updateEntitlement: "All CmdTab 1.x updates",
  refundPolicy: "14-day full refund",
  reviewedAt: "2026-07-22",
  sourceRepository: "https://github.com/siewhean/AltTabMac",
  developerProfile: "https://github.com/siewhean",
  permissions: [
    {
      name: "Accessibility",
      reason:
        "Lets CmdTab detect the switcher shortcut, inspect eligible windows, move selection, and focus the chosen app or exact window.",
    },
    {
      name: "Screen Recording",
      reason:
        "Lets CmdTab capture previews of open windows. If capture is unavailable, eligible windows remain visible with an icon or placeholder.",
    },
  ],
  modes: ["Classic Grid", "Command Palette", "Radial Menu"],
  windowScopes: ["Current Space", "Visible Spaces", "All Spaces"],
  displayTargets: ["Active window display", "Cursor display", "All displays"],
  quickActions: ["Hide app", "Minimize window", "Close window", "Quit app"],
  appTelemetry: {
    cadence:
      "Optional app telemetry is off by default. If enabled, an activation event is sent when the app starts, followed by an hourly heartbeat while it remains running.",
    events: ["App activation", "Hourly heartbeat", "Trial started", "License activated"],
    fields: [
      "Pseudonymous install identifier",
      "Event name and timestamp",
      "License state and license identifier when present",
      "App version",
      "macOS version",
    ],
    excluded:
      "The current native-app telemetry payload does not contain window titles, window previews, screenshots, keystrokes, file names, clipboard contents, or search queries.",
  },
  contactEmail: siteConfig.contactEmail,
} as const;

export const publicProductFactRows = [
  { label: "Product", value: "Native macOS window switcher" },
  { label: "Current app version", value: `${productFacts.currentVersion} (build ${productFacts.buildNumber})` },
  { label: "Minimum system", value: productFacts.minimumMacOS },
  { label: "Trial", value: productFacts.trialLength },
  { label: "License", value: productFacts.licenseModel },
  { label: "Switcher modes", value: productFacts.modes.join(", ") },
  { label: "Window scope", value: productFacts.windowScopes.join(", ") },
  { label: "Display placement", value: productFacts.displayTargets.join(", ") },
] as const;
