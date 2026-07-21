import { ImageResponse } from "next/og";

export const alt = "CmdTab: macOS app switcher with real window previews";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          height: "100%",
          width: "100%",
          background:
            "radial-gradient(circle at top right, rgba(105,214,255,0.2), transparent 28%), radial-gradient(circle at left, rgba(78,161,255,0.22), transparent 26%), linear-gradient(180deg, #05070C 0%, #08101C 46%, #05070C 100%)",
          color: "#EAF1FF",
          padding: "64px",
          fontFamily:
            "SF Pro Display, SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif",
        }}
      >
        <div
          style={{
            display: "flex",
            flex: 1,
            flexDirection: "column",
            justifyContent: "space-between",
            borderRadius: "40px",
            border: "1px solid rgba(255,255,255,0.12)",
            background: "rgba(255,255,255,0.04)",
            padding: "48px",
          }}
        >
          <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
            <div
              style={{
                display: "flex",
                alignSelf: "flex-start",
                borderRadius: "999px",
                border: "1px solid rgba(126,231,200,0.3)",
                background: "rgba(126,231,200,0.12)",
                color: "#7EE7C8",
                fontSize: 20,
                fontWeight: 600,
                letterSpacing: "0.2em",
                padding: "12px 18px",
                textTransform: "uppercase",
              }}
            >
              14-day free trial
            </div>
            <div style={{ fontSize: 86, fontWeight: 600, letterSpacing: "-0.08em" }}>
              CmdTab
            </div>
            <div
              style={{
                maxWidth: "760px",
                fontSize: 50,
                lineHeight: 1.05,
                letterSpacing: "-0.05em",
              }}
            >
              Find the right Mac window in one move.
            </div>
          </div>

          <div
            style={{
              display: "flex",
              gap: "18px",
              color: "#A8B5CC",
              fontSize: 24,
            }}
          >
            <span>Real macOS window previews</span>
            <span>•</span>
            <span>Three switcher modes</span>
            <span>•</span>
            <span>One-time purchase, no subscription</span>
          </div>
        </div>
      </div>
    ),
    size,
  );
}
