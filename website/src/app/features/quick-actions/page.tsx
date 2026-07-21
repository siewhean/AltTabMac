import { JsonLd } from "@/components/seo/json-ld";
import { FeatureDetailPage } from "@/components/seo/feature-detail-page";
import { featureDepth } from "@/content/feature-depth";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const content = featureDepth.quickActions;
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Window switcher", path: "/features/window-switcher" as const },
  { name: "Quick Actions", path: "/features/quick-actions" as const },
];

export const metadata = createPageMetadata({
  title: content.metadataTitle,
  description: content.metadataDescription,
  path: "/features/quick-actions",
  image: "/showcase/quick-actions-poster.png",
  imageAlt: "Real CmdTab Quick Actions render showing a selected Mac window item mutation",
  imageWidth: 1280,
  imageHeight: 800,
});

export default function QuickActionsPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: content.metadataTitle,
          description: content.metadataDescription,
          path: "/features/quick-actions",
          dateModified: content.reviewedAt,
        })}
      />
      <FeatureDetailPage content={content} headingAs="h1" breadcrumbs={breadcrumbs} />
    </main>
  );
}
