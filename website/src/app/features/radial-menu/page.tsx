import { JsonLd } from "@/components/seo/json-ld";
import { FeatureDetailPage } from "@/components/seo/feature-detail-page";
import { featureDepth } from "@/content/feature-depth";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const content = featureDepth.radialMenu;
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Window switcher", path: "/features/window-switcher" as const },
  { name: "Radial Menu", path: "/features/radial-menu" as const },
];

export const metadata = createPageMetadata({
  title: content.metadataTitle,
  description: content.metadataDescription,
  path: "/features/radial-menu",
  image: "/showcase/radial-menu-poster.png",
  imageAlt: "Real CmdTab Radial Menu render arranging Mac window targets around a circular selector",
  imageWidth: 1280,
  imageHeight: 800,
});

export default function RadialMenuPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: content.metadataTitle,
          description: content.metadataDescription,
          path: "/features/radial-menu",
          dateModified: content.reviewedAt,
        })}
      />
      <FeatureDetailPage content={content} headingAs="h1" breadcrumbs={breadcrumbs} />
    </main>
  );
}
