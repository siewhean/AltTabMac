export type ShowcaseSourceType =
  | "production-swiftui-render"
  | "deterministic-product-composite";

export type ShowcaseAsset = {
  id: "overview" | "classic-grid" | "command-palette" | "radial-menu" | "quick-actions";
  title: string;
  eyebrow: string;
  description: string;
  transcript: string;
  poster: `/showcase/${string}.webp`;
  video?: `/showcase/${string}.mp4`;
  durationSeconds?: number;
  posterWidth: number;
  posterHeight: number;
  videoWidth?: number;
  videoHeight?: number;
  sourceType: ShowcaseSourceType;
  sourceLabel: string;
};

export const showcaseReviewedAt = "2026-07-21";
export const showcaseUploadDate = "2026-07-21T00:00:00+08:00";
export const showcaseDisclosure =
  "Radial Menu is an authentic render of CmdTab’s production SwiftUI/AppKit view. The overview and Quick Actions clips, plus the Classic Grid and Command Palette posters, are deterministic product composites based on the current production geometry, styling, item model, and documented behavior contract. All media uses controlled fixture windows, is not AI-generated, and does not record a private desktop.";
export const showcaseBoundary =
  "This showcase demonstrates current presentation and interaction concepts. It does not prove signed-app Accessibility, Screen Recording, Space, display, fullscreen, signing, notarization, or exact focused-window acceptance; those remain separately documented on the Evidence page.";

export const showcaseAssets: ReadonlyArray<ShowcaseAsset> = [
  {
    id: "overview",
    title: "CmdTab app switcher overview",
    eyebrow: "Overview",
    description:
      "A short deterministic product composite introduces Classic Grid, Command Palette, Radial Menu, and Quick Actions using the current interface geometry and controlled fixture windows.",
    transcript:
      "The clip opens on Classic Grid and moves the selected exact-window tile. It changes to Command Palette and narrows the visible fixture set with a local query. It then presents the Radial Menu before ending with a selected fixture target leaving the grid after a Quick Action annotation.",
    poster: "/showcase/overview-poster.webp",
    video: "/showcase/overview.mp4",
    durationSeconds: 8,
    posterWidth: 720,
    posterHeight: 450,
    videoWidth: 480,
    videoHeight: 300,
    sourceType: "deterministic-product-composite",
    sourceLabel: "Deterministic product composite",
  },
  {
    id: "classic-grid",
    title: "Classic Grid exact-window preview",
    eyebrow: "Classic Grid",
    description:
      "A deterministic product poster shows separate exact-window cards, real-preview styling, and the selected-state treatment used by Classic Grid.",
    transcript:
      "The poster depicts six controlled fixture windows as separate thumbnail cards. A blue outline identifies the selected exact-window target without grouping the cards by application.",
    poster: "/showcase/classic-grid-poster.webp",
    posterWidth: 720,
    posterHeight: 450,
    sourceType: "deterministic-product-composite",
    sourceLabel: "Deterministic product poster",
  },
  {
    id: "command-palette",
    title: "Command Palette local window search",
    eyebrow: "Command Palette",
    description:
      "A deterministic product poster shows the current search layout, controlled fixture results, and selected-row treatment used by Command Palette.",
    transcript:
      "The poster depicts the local search field and a filtered fixture-window list. The selected result uses the current blue outline and return-key affordance.",
    poster: "/showcase/command-palette-poster.webp",
    posterWidth: 800,
    posterHeight: 500,
    sourceType: "deterministic-product-composite",
    sourceLabel: "Deterministic product poster",
  },
  {
    id: "radial-menu",
    title: "Radial Menu directional selection",
    eyebrow: "Radial Menu",
    description:
      "An authentic production SwiftUI/AppKit render shows the circular selector moving its highlighted exact-window target around the shared radial viewport.",
    transcript:
      "Eight controlled fixture-window targets appear around the production Radial Menu. The selected ring, arrow, and center details advance around the circle to demonstrate directional selection.",
    poster: "/showcase/radial-menu-poster.webp",
    video: "/showcase/radial-menu.mp4",
    durationSeconds: 4.833333,
    posterWidth: 800,
    posterHeight: 500,
    videoWidth: 480,
    videoHeight: 300,
    sourceType: "production-swiftui-render",
    sourceLabel: "Authentic production SwiftUI render",
  },
  {
    id: "quick-actions",
    title: "Quick Actions selected-item mutation",
    eyebrow: "Quick Actions",
    description:
      "A deterministic product composite shows a selected fixture target leaving the grid after a capture-only Command-W annotation.",
    transcript:
      "A controlled fixture window is selected in the grid. A capture-only Command-W badge explains the close action. The selected target leaves and the remaining fixture cards reflow.",
    poster: "/showcase/quick-actions-poster.webp",
    video: "/showcase/quick-actions.mp4",
    durationSeconds: 3.583333,
    posterWidth: 720,
    posterHeight: 450,
    videoWidth: 480,
    videoHeight: 300,
    sourceType: "deterministic-product-composite",
    sourceLabel: "Deterministic product composite",
  },
] as const;

export function showcaseAsset(id: ShowcaseAsset["id"]) {
  const asset = showcaseAssets.find((candidate) => candidate.id === id);
  if (!asset) throw new Error(`Unknown showcase asset: ${id}`);
  return asset;
}
