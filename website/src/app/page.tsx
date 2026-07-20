import { DiscoveryResourcesSection } from "@/components/sections/discovery-resources-section";
import { FaqSection } from "@/components/sections/faq-section";
import { FeatureBandsSection } from "@/components/sections/feature-bands-section";
import { FooterSection } from "@/components/sections/footer-section";
import { HeroSection } from "@/components/sections/hero-section";
import { ProductFactsSection } from "@/components/sections/product-facts-section";
import { StylesSection } from "@/components/sections/styles-section";
import { WalkthroughSection } from "@/components/sections/walkthrough-section";

export default function HomePage() {
  return (
    <main id="top">
      <HeroSection />
      <StylesSection />
      <WalkthroughSection />
      <FeatureBandsSection />
      <ProductFactsSection />
      <DiscoveryResourcesSection />
      <FaqSection />
      <FooterSection />
    </main>
  );
}
