import { commerceContent } from "@/content/commerce";
import { siteConfig } from "@/content/site";

export const productFacts = {
  name: siteConfig.name,
  category: "macOS window switcher",
  minimumMacOS: "macOS 13 or later",
  trialLength: commerceContent.trialLength,
  licenseModel: "One-time purchase",
  founderPrice: commerceContent.founder.price,
  standardPrice: commerceContent.standard.price,
  permissions: [
    {
      name: "Accessibility",
      reason:
        "Lets CmdTab detect the switcher shortcut, move selection, and focus the chosen app or window.",
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
  contactEmail: siteConfig.contactEmail,
} as const;

export const publicProductFactRows = [
  { label: "Product", value: "Native macOS window switcher" },
  { label: "Minimum system", value: productFacts.minimumMacOS },
  { label: "Trial", value: productFacts.trialLength },
  { label: "License", value: productFacts.licenseModel },
  { label: "Switcher modes", value: productFacts.modes.join(", ") },
  { label: "Window scope", value: productFacts.windowScopes.join(", ") },
  { label: "Display placement", value: productFacts.displayTargets.join(", ") },
] as const;
