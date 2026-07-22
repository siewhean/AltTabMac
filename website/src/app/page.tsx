import { FeatureBandsSection } from "@/components/sections/feature-bands-section";
import { FooterSection } from "@/components/sections/footer-section";
import { HeroSection } from "@/components/sections/hero-section";
import { StylesSection } from "@/components/sections/styles-section";

export default function HomePage() {
  return (
    <main id="top">
      <HeroSection />
      <StylesSection />
      <FeatureBandsSection />
      <FooterSection />
    </main>
  );
}
