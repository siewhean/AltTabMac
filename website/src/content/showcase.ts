export type ShowcaseAsset = {
  id: "overview" | "classic-grid" | "command-palette" | "radial-menu" | "quick-actions";
  title: string;
  eyebrow: string;
  description: string;
  transcript: string;
  poster: `/showcase/${string}.png`;
  video: `/showcase/${string}.mp4`;
  durationSeconds: number;
  width: 1280;
  height: 800;
};

export const showcaseReviewedAt = "2026-07-21";
export const showcaseUploadDate = "2026-07-21T00:00:00+08:00";
export const showcaseDisclosure =
  "These are real renders of CmdTab’s production SwiftUI/AppKit switcher views using controlled fixture windows. They are not AI-generated and do not record a developer’s private desktop.";
export const showcaseBoundary =
  "The surrounding desktop, fixture window contents, and Quick Action key badge are capture-only explanatory context. Real signed-app permission, Space, display, fullscreen, and exact-focus acceptance remain separately documented on the Evidence page.";

export const showcaseAssets: ReadonlyArray<ShowcaseAsset> = [
  {
    id: "overview",
    title: "CmdTab app switcher showcase",
    eyebrow: "Overview",
    description:
      "See Classic Grid, Command Palette, Radial Menu, and a Quick Action item mutation rendered from the production switcher views in one short silent loop.",
    transcript:
      "The clip opens on Classic Grid and moves the selected exact-window tile across controlled fixture windows. It changes to Command Palette and narrows the list with a local query. It then shows the Radial Menu selection moving around the ring before ending with a selected fixture target leaving Classic Grid after an annotated Quick Action.",
    poster: "/showcase/overview-poster.png",
    video: "/showcase/overview.mp4",
    durationSeconds: 8,
    width: 1280,
    height: 800,
  },
  {
    id: "classic-grid",
    title: "Classic Grid exact-window selection",
    eyebrow: "Classic Grid",
    description:
      "Watch the production thumbnail grid move its selected state across separate exact-window targets while every fixture window remains visible.",
    transcript:
      "Classic Grid displays six controlled fixture windows as separate thumbnail cards. The blue selection outline advances from one exact-window tile to the next without grouping the targets by application.",
    poster: "/showcase/classic-grid-poster.png",
    video: "/showcase/classic-grid.mp4",
    durationSeconds: 5.1,
    width: 1280,
    height: 800,
  },
  {
    id: "command-palette",
    title: "Command Palette local window search",
    eyebrow: "Command Palette",
    description:
      "Watch the production palette narrow the current exact-window set as a local query is entered, then return to the unfiltered sequence.",
    transcript:
      "Command Palette starts with the fixture window list. The query grows from one character to the word switch, causing the production PaletteSearch ranking to narrow the displayed targets. The sequence then returns to the complete list.",
    poster: "/showcase/command-palette-poster.png",
    video: "/showcase/command-palette.mp4",
    durationSeconds: 4.8,
    width: 1280,
    height: 800,
  },
  {
    id: "radial-menu",
    title: "Radial Menu directional selection",
    eyebrow: "Radial Menu",
    description:
      "Watch the production circular selector move its highlighted exact-window target around the shared radial viewport.",
    transcript:
      "Eight controlled fixture-window targets appear around the production Radial Menu. The selected ring, arrow, and center details advance around the circle to demonstrate directional selection.",
    poster: "/showcase/radial-menu-poster.png",
    video: "/showcase/radial-menu.mp4",
    durationSeconds: 4.8,
    width: 1280,
    height: 800,
  },
  {
    id: "quick-actions",
    title: "Quick Action selected-item mutation",
    eyebrow: "Quick Actions",
    description:
      "See the production Classic Grid update after a selected fixture window is removed, with a capture-only key annotation explaining the action.",
    transcript:
      "A controlled fixture window is selected in Classic Grid. A capture-only Command-W badge explains the close action. The selected target then leaves the production grid and the remaining items reflow with the switcher’s item-mutation behavior.",
    poster: "/showcase/quick-actions-poster.png",
    video: "/showcase/quick-actions.mp4",
    durationSeconds: 3.6,
    width: 1280,
    height: 800,
  },
] as const;

export function showcaseAsset(id: ShowcaseAsset["id"]) {
  const asset = showcaseAssets.find((candidate) => candidate.id === id);
  if (!asset) throw new Error(`Unknown showcase asset: ${id}`);
  return asset;
}
