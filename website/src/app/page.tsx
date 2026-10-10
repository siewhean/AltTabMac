import { BetaCtaSection } from "@/components/sections/beta-cta-section";
import { DemoSection } from "@/components/sections/demo-section";
import { FeatureBandsSection } from "@/components/sections/feature-bands-section";
import { FooterSection } from "@/components/sections/footer-section";
import { HeroSection } from "@/components/sections/hero-section";
import { StylesSection } from "@/components/sections/styles-section";

export default function HomePage() {
  return (
    <main id="top">
      <HeroSection />
      <StylesSection />
      <DemoSection />
      <FeatureBandsSection />
      <BetaCtaSection />
      <FooterSection />
    </main>
  );
}
