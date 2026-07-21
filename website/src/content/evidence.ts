export const evidenceLedger = {
  reviewedAt: "2026-07-21",
  productAlignmentCommit: "0d042e9600e9c053e8a3facfc5d1aa3012ea89de",
  automated: [
    {
      title: "Strict exact-window MRU regressions",
      result:
        "Focused acceptance tests verify forward and reverse selection when the adjacent recent window belongs to the same application, ambiguous frontmost PID resolution, and preview-independent membership.",
      environment: "GitHub-hosted macOS 14 and macOS 15 runners",
    },
    {
      title: "Complete Swift package suite",
      result:
        "The complete SwiftPM test suite runs after the focused contract tests on both supported CI runner generations.",
      environment: "GitHub-hosted macOS 14 and macOS 15 runners",
    },
    {
      title: "Reproducible pre-fix state-space model",
      result:
        "The checked model covers 19,500 meaningful activation sequences and records 3,900 pre-fix PID-skip selection mismatches. It also covers 126 preview-success configurations and records 120 pre-fix completeness failures.",
      environment:
        "Dependency-free Python model; these figures describe the modeled state space, not a measured field failure rate.",
    },
    {
      title: "Rendered production website verification",
      result:
        "The production crawler and browser suites validate every maintained public route at desktop and mobile sizes, metadata, structured data, internal links, images, navigation, wide-table accessibility, private-route index protection, and the interactive demo.",
      environment: "Compiled Next.js production server and public cmdtab.net deployment",
    },
  ],
  publicArtifacts: [
    {
      label: "Switcher model results (JSON)",
      href: "/evidence/switcher-model-results.json",
      description:
        "Machine-readable model counts and representative counterexamples for the pre-fix behavior.",
    },
    {
      label: "Comprehensive switcher test matrix (CSV)",
      href: "/evidence/switcher-test-matrix.csv",
      description:
        "The 136-case matrix covering membership, MRU, session input, activation, Spaces, displays, permissions, performance, compatibility, and release checks.",
    },
    {
      label: "Implementation review and execution plan (Markdown)",
      href: "/evidence/switcher-test-plan.md",
      description:
        "Detailed acceptance contract, findings, live test procedures, test architecture, and definition of done.",
    },
  ],
  manualBoundary: [
    "Accessibility and Screen Recording permission transitions on a real signed app",
    "Selected identity versus the actual focused CGWindowID for keyboard and mouse commits",
    "Cmd-`, Mission Control, Stage Manager, minimized windows, and native fullscreen behavior",
    "Current Space, visible Spaces, all Spaces, and off-Space activation",
    "Single-display, multi-display, mixed-scaling, mirror, disconnect, and reconnect behavior",
    "Secure Input, event-tap recovery, sleep and wake, signing, notarization, and clean-account installation",
  ],
} as const;
