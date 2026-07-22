export type ShowcaseSourceType = "deterministic-product-composite";

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
  videoFrameRate?: number;
  sourceType: ShowcaseSourceType;
  sourceLabel: string;
};

export const showcaseReviewedAt = "2026-07-22";
export const showcaseUploadDate = "2026-07-22T00:00:00+08:00";
export const showcaseDisclosure =
  "Every showcase asset is a deterministic HD product composite generated at 1920 × 1200 from vector source based on CmdTab’s current production geometry, styling, item model, and documented behavior contract. All media uses controlled fixture windows, is not AI-generated, and does not record a private desktop.";
export const showcaseBoundary =
  "The HD showcase demonstrates presentation and controlled interaction concepts. It is not a literal desktop recording and does not prove signed-app Accessibility, Screen Recording, Space, display, fullscreen, signing, notarization, latency, memory, processor, architecture, or exact focused-window acceptance; those remain separately documented on the Evidence page.";

const HD_WIDTH = 1920;
const HD_HEIGHT = 1200;
const HD_FPS = 30;

export const showcaseAssets: ReadonlyArray<ShowcaseAsset> = [
  {
    id: "overview",
    title: "CmdTab app switcher overview",
    eyebrow: "Overview",
    description:
      "A sharp HD product composite introduces Classic Grid, Command Palette, Radial Menu, and Quick Actions using current interface geometry and controlled fixture windows.",
    transcript:
      "The clip opens on Classic Grid and moves the selected exact-window tile. It changes to Command Palette and narrows the visible fixture set with a local query. It then presents Radial Menu before ending with a selected fixture target leaving the grid after a Quick Action annotation.",
    poster: "/showcase/overview-poster.webp",
    video: "/showcase/overview.mp4",
    durationSeconds: 8,
    posterWidth: HD_WIDTH,
    posterHeight: HD_HEIGHT,
    videoWidth: HD_WIDTH,
    videoHeight: HD_HEIGHT,
    videoFrameRate: HD_FPS,
    sourceType: "deterministic-product-composite",
    sourceLabel: "HD deterministic product composite",
  },
  {
    id: "classic-grid",
    title: "Classic Grid exact-window preview",
    eyebrow: "Classic Grid",
    description:
      "A sharp HD product poster shows separate exact-window cards, preview styling, and the selected-state treatment used by Classic Grid.",
    transcript:
      "The poster depicts six controlled fixture windows as separate thumbnail cards. A cyan outline identifies the selected exact-window target without grouping the cards by application.",
    poster: "/showcase/classic-grid-poster.webp",
    posterWidth: HD_WIDTH,
    posterHeight: HD_HEIGHT,
    sourceType: "deterministic-product-composite",
    sourceLabel: "HD deterministic product poster",
  },
  {
    id: "command-palette",
    title: "Command Palette local window search",
    eyebrow: "Command Palette",
    description:
      "A sharp HD product poster shows the current search layout, controlled fixture results, and selected-row treatment used by Command Palette.",
    transcript:
      "The poster depicts the local search field and a filtered fixture-window list. The selected result uses the current cyan outline and return-key affordance.",
    poster: "/showcase/command-palette-poster.webp",
    posterWidth: HD_WIDTH,
    posterHeight: HD_HEIGHT,
    sourceType: "deterministic-product-composite",
    sourceLabel: "HD deterministic product poster",
  },
  {
    id: "radial-menu",
    title: "Radial Menu directional selection",
    eyebrow: "Radial Menu",
    description:
      "A sharp HD product composite shows the circular selector moving its highlighted exact-window target around the radial viewport.",
    transcript:
      "Six controlled fixture-window targets appear around Radial Menu. The highlighted ring and center details advance around the circle to demonstrate directional selection.",
    poster: "/showcase/radial-menu-poster.webp",
    video: "/showcase/radial-menu.mp4",
    durationSeconds: 5,
    posterWidth: HD_WIDTH,
    posterHeight: HD_HEIGHT,
    videoWidth: HD_WIDTH,
    videoHeight: HD_HEIGHT,
    videoFrameRate: HD_FPS,
    sourceType: "deterministic-product-composite",
    sourceLabel: "HD deterministic product composite",
  },
  {
    id: "quick-actions",
    title: "Quick Actions selected-item mutation",
    eyebrow: "Quick Actions",
    description:
      "A sharp HD product composite shows a selected fixture target leaving the grid after a capture-only Command-W annotation.",
    transcript:
      "A controlled fixture window is selected in the grid. A capture-only Command-W badge explains the close action. The selected target leaves and the remaining fixture cards reflow.",
    poster: "/showcase/quick-actions-poster.webp",
    video: "/showcase/quick-actions.mp4",
    durationSeconds: 4,
    posterWidth: HD_WIDTH,
    posterHeight: HD_HEIGHT,
    videoWidth: HD_WIDTH,
    videoHeight: HD_HEIGHT,
    videoFrameRate: HD_FPS,
    sourceType: "deterministic-product-composite",
    sourceLabel: "HD deterministic product composite",
  },
] as const;

export function showcaseAsset(id: ShowcaseAsset["id"]) {
  const asset = showcaseAssets.find((candidate) => candidate.id === id);
  if (!asset) throw new Error(`Unknown showcase asset: ${id}`);
  return asset;
}
