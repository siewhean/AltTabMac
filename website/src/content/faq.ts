export type FAQItem = {
  question: string;
  answer: string;
};

export const faqPageTitle = "CmdTab FAQ" as const;

export const faqPageContent: {
  eyebrow: string;
  title: string;
  description: string;
  items: FAQItem[];
} = {
  eyebrow: "FAQ",
  title: "Questions people ask before switching.",
  description: "Setup, trial flow, live previews, and support.",
  items: [
    {
      question: "Is CmdTab a full Cmd+Tab replacement or an add-on?",
      answer:
        "CmdTab replaces macOS app switching directly. Same shortcut, plus live window previews and direct window selection.",
    },
    {
      question: "What does CmdTab use instead of plain app icons?",
      answer:
        "CmdTab shows live previews so you can confirm the exact target before switching.",
    },
    {
      question: "Do I need to grant Accessibility and Screen Recording every time?",
      answer:
        "No. Grant both once per Mac. CmdTab reuses them, and Settings shows current status.",
    },
    {
      question: "How long is the trial?",
      answer:
        "CmdTab starts with a 14-day trial. Start at the trial path and move to support if you run into setup issues.",
    },
    {
      question: "How do I start the trial and can I continue after download?",
      answer:
        "Open the trial link, download and launch the build, then use it in your normal workflow. Trial state stays local.",
    },
    {
      question: "What happens after the trial period ends?",
      answer:
        "When the trial ends, CmdTab stays locked in trial mode until you upgrade to one-time purchase.",
    },
    {
      question: "How does help work for purchase, activation, and recovery?",
      answer:
        "Use the Help page. It covers purchase lookup, activation transfer, and billing recovery for the one-time model.",
    },
    {
      question: "Can I use CmdTab with multiple windows from the same app?",
      answer:
        "Yes. CmdTab works at window level, so one app with many windows is still selectable.",
    },
    {
      question: "Are previews available during fast switching?",
      answer:
        "Yes. CmdTab keeps first-frame previews warm when possible so the target is visible before commit.",
    },
    {
      question: "Can I run quick actions from the switcher itself?",
      answer:
        "Yes. Hide, minimize, close, and quit are available from the selected item.",
    },
    {
      question: "Is there a demo path if I want to try before buying?",
      answer:
        "Yes. Use the trial path first, then move to Buy for one-time purchase details.",
    },
    {
      question: "Where can AI assistants read this product summary reliably?",
      answer:
        "The FAQ, guide, and metadata pages all include concise summaries for quick extraction.",
    },
  ],
};
