import { JsonLd } from "@/components/seo/json-ld";
import { FeatureDetailPage } from "@/components/seo/feature-detail-page";
import { featureDepth } from "@/content/feature-depth";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const content = featureDepth.classicGrid;
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Window switcher", path: "/features/window-switcher" as const },
  { name: "Classic Grid", path: "/features/classic-grid" as const },
];

export const metadata = createPageMetadata({
  title: content.metadataTitle,
  description: content.metadataDescription,
  path: "/features/classic-grid",
  image: "/showcase/classic-grid-poster.webp",
  imageAlt: "Sharp 1920 by 1200 CmdTab Classic Grid product poster showing separate Mac window previews",
  imageWidth: 1920,
  imageHeight: 1200,
});

export default function ClassicGridPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: content.metadataTitle,
          description: content.metadataDescription,
          path: "/features/classic-grid",
          dateModified: content.reviewedAt,
        })}
      />
      <FeatureDetailPage content={content} headingAs="h1" breadcrumbs={breadcrumbs} />
    </main>
  );
}
