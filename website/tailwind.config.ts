import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#05070C",
        panel: "#0B1220",
        shell: "#111A2B",
        line: "#18243A",
        text: "#EAF1FF",
        muted: "#A8B5CC",
        subdued: "#6F7D95",
        accent: "#4EA1FF",
        cyan: "#69D6FF",
        violet: "#8E7CFF",
        success: "#7EE7C8",
      },
      boxShadow: {
        halo: "0 30px 80px rgba(78, 161, 255, 0.16)",
        panel: "0 32px 80px rgba(5, 7, 12, 0.48)",
      },
      borderRadius: {
        panel: "28px",
      },
      fontFamily: {
        sans: [
          "SF Pro Display",
          "SF Pro Text",
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "sans-serif",
        ],
        mono: [
          "SF Mono",
          "ui-monospace",
          "SFMono-Regular",
          "Menlo",
          "Monaco",
          "Consolas",
          "monospace",
        ],
      },
      backgroundImage: {
        "grid-fade":
          "linear-gradient(to right, rgba(24, 36, 58, 0.45) 1px, transparent 1px), linear-gradient(to bottom, rgba(24, 36, 58, 0.45) 1px, transparent 1px)",
      },
    },
  },
  plugins: [],
};

export default config;

