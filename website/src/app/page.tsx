import { FeatureBandsSection } from "@/components/sections/feature-bands-section";
import { FooterSection } from "@/components/sections/footer-section";
import { HeroSection } from "@/components/sections/hero-section";
import { StylesSection } from "@/components/sections/styles-section";
import { WaitlistSection } from "@/components/sections/waitlist-section";
import { WalkthroughSection } from "@/components/sections/walkthrough-section";

export default function HomePage() {
  return (
    <main id="top">
      <HeroSection />
      <StylesSection />
      <WalkthroughSection />
      <FeatureBandsSection />
      <WaitlistSection />
      <FooterSection />
    </main>
  );
}
