import { FeatureBandsSection } from "@/components/sections/feature-bands-section";
import { FooterSection } from "@/components/sections/footer-section";
import { FaqSection } from "@/components/sections/faq-section";
import { HeroSection } from "@/components/sections/hero-section";
import { PermissionsSection } from "@/components/sections/permissions-section";
import { ProofSection } from "@/components/sections/proof-section";
import { StylesSection } from "@/components/sections/styles-section";
import { WaitlistSection } from "@/components/sections/waitlist-section";
import { WalkthroughSection } from "@/components/sections/walkthrough-section";

export default function HomePage() {
  return (
    <main id="top">
      <HeroSection />
      <ProofSection />
      <StylesSection />
      <WalkthroughSection />
      <FeatureBandsSection />
      <PermissionsSection />
      <WaitlistSection />
      <FaqSection />
      <FooterSection />
    </main>
  );
}

