import { FeatureBandsSection } from "@/components/sections/feature-bands-section";
import { FooterSection } from "@/components/sections/footer-section";
import { HeroSection } from "@/components/sections/hero-section";
import { LaunchSection } from "@/components/sections/launch-section";
import { StylesSection } from "@/components/sections/styles-section";
import { WalkthroughSection } from "@/components/sections/walkthrough-section";

export default function HomePage() {
  return (
    <main id="top">
      <HeroSection />
      <StylesSection />
      <WalkthroughSection />
      <FeatureBandsSection />
      <LaunchSection />
      <FooterSection />
    </main>
  );
}
