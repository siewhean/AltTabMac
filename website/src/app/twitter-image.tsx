import { ImageResponse } from "next/og";

export const alt = "CmdTab app switcher for macOS with preview thumbnails";
export const size = {
  width: 1200,
  height: 675,
};
export const contentType = "image/png";

export default function TwitterImage() {
  return new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          height: "100%",
          width: "100%",
          alignItems: "center",
          justifyContent: "center",
          background:
            "radial-gradient(circle at top right, rgba(105,214,255,0.18), transparent 30%), linear-gradient(180deg, #05070C 0%, #08101C 45%, #05070C 100%)",
          color: "#EAF1FF",
          padding: "56px",
          fontFamily:
            "SF Pro Display, SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif",
        }}
      >
        <div
          style={{
            display: "flex",
            width: "100%",
            flexDirection: "column",
            gap: "18px",
            borderRadius: "36px",
            border: "1px solid rgba(255,255,255,0.12)",
            background: "rgba(255,255,255,0.04)",
            padding: "42px",
          }}
        >
          <div style={{ fontSize: 64, fontWeight: 600, letterSpacing: "-0.08em" }}>CmdTab</div>
          <div style={{ maxWidth: "860px", fontSize: 46, letterSpacing: "-0.05em" }}>
            A practical macOS app switcher with real window previews.
          </div>
          <div style={{ display: "flex", gap: "14px", color: "#A8B5CC", fontSize: 24 }}>
            <span>Classic Grid</span>
            <span>•</span>
            <span>Command Palette</span>
            <span>•</span>
            <span>Radial Menu</span>
            <span>•</span>
            <span>No subscriptions</span>
          </div>
        </div>
      </div>
    ),
    size,
  );
}
