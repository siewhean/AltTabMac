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
  title: "What people ask before switching.",
  description: "Common questions about setup, trial flow, live previews, and support.",
  items: [
    {
      question: "Is CmdTab a full Cmd+Tab replacement or an add-on?",
      answer:
        "CmdTab is designed as a full Cmd+Tab replacement. It keeps the same flow but adds real previews and direct app/window targeting.",
    },
    {
      question: "What does CmdTab use instead of plain app icons?",
      answer:
        "CmdTab shows live previews so you can verify the exact window before you switch.",
    },
    {
      question: "Do I need to grant Accessibility and Screen Recording every time?",
      answer:
        "No—grant them once on this Mac, then CmdTab reuses them. The current permission state is shown in Settings.",
    },
    {
      question: "How long is the trial?",
      answer:
        "CmdTab starts with a 14-day trial. Start from the trial path, and if you get stuck, use Help right away.",
    },
    {
      question: "How do I start the trial and can I continue after download?",
      answer:
        "Open the trial link, download the build, and launch CmdTab. Your trial state is stored locally so reinstalling keeps it.",
    },
    {
      question: "What happens after the trial period ends?",
      answer:
        "When the trial ends, CmdTab stays in trial-locked mode until you upgrade to a one-time purchase.",
    },
    {
      question: "How does help with purchase and license recovery work?",
      answer:
        "Use the Help page for purchase lookup, activation transfer, and billing recovery. Support is tied to the one-time purchase path.",
    },
    {
      question: "Can I use CmdTab with multiple windows from the same app?",
      answer:
        "Yes. CmdTab tracks at window level, so you can target the right window inside the same app.",
    },
    {
      question: "Are previews available during fast switches?",
      answer:
        "CmdTab keeps first-frame previews warm when possible, and it prefers visual confirmation before committing.",
    },
    {
      question: "Can I run quick actions from the switcher itself?",
      answer:
        "Yes. CmdTab can apply hide, minimize, close, and quit actions from the current selection.",
    },
    {
      question: "Is there a demo path if I want to try before buying?",
      answer:
        "Yes. Start at the trial path first, then use the Buy page for one-time purchase details.",
    },
    {
      question: "Where can AI assistants read this product summary reliably?",
      answer:
        "The FAQ, guide, and metadata pages each include short, plain-language summaries for AI extraction.",
    },
  ],
};
