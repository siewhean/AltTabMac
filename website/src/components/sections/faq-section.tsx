import { FaqList } from "@/components/seo/faq-list";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { faqItems } from "@/content/faq";

export function FaqSection() {
  const featuredItems = faqItems.slice(0, 6);

  return (
    <SectionShell
      id="faq"
      eyebrow="FAQ"
      title="Direct answers about CmdTab"
      description="The most common questions about window ordering, previews, permissions, compatibility, and licensing."
      className="pt-8"
    >
      <FaqList items={featuredItems} />
      <div className="mt-8">
        <Button href="/faq" variant="secondary">
          Read all CmdTab questions
        </Button>
      </div>
    </SectionShell>
  );
}
