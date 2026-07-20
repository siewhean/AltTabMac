import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path), "utf8");

const expectedPublicRoutes = [
  "/",
  "/about",
  "/buy",
  "/changelog",
  "/compatibility",
  "/help",
  "/permissions",
  "/privacy",
  "/security",
  "/trial",
];

const sitemap = read("src/app/sitemap.ts");
for (const route of expectedPublicRoutes) {
  assert.match(sitemap, new RegExp(`\\"${route.replaceAll("/", "\\/")}\\"`), `sitemap is missing ${route}`);
}
assert.doesNotMatch(sitemap, /lastModified\s*:\s*now/, "sitemap must not publish generation time as lastModified");
assert.doesNotMatch(sitemap, /dashboard|\/api\//, "private routes must not appear in the sitemap");

const robots = read("src/app/robots.ts");
assert.match(robots, /OAI-SearchBot/, "robots policy must explicitly document ChatGPT search crawler access");
assert.match(robots, /\/api\//, "robots policy must exclude API endpoints");

const dashboardLayout = read("src/app/dashboard/layout.tsx");
assert.match(dashboardLayout, /index:\s*false/, "dashboard layout must be noindex");
assert.match(dashboardLayout, /follow:\s*false/, "dashboard layout must be nofollow");

const nextConfig = read("next.config.ts");
assert.match(nextConfig, /X-Robots-Tag/, "private routes need an HTTP noindex fallback");
assert.match(nextConfig, /\/dashboard\/:path\*/, "dashboard noindex header is missing");
assert.match(nextConfig, /\/api\/:path\*/, "API noindex header is missing");

const rootLayout = read("src/app/layout.tsx");
assert.match(rootLayout, /template:\s*`%s \| \$\{siteConfig\.name\}`/, "root title template is missing");
assert.match(rootLayout, /createHomeStructuredData/, "home entity structured data is missing");
assert.doesNotMatch(rootLayout, /keywords:/, "meta keywords should not be emitted");

const pagePaths = [
  "src/app/about/page.tsx",
  "src/app/buy/page.tsx",
  "src/app/changelog/page.tsx",
  "src/app/compatibility/page.tsx",
  "src/app/help/page.tsx",
  "src/app/permissions/page.tsx",
  "src/app/privacy/page.tsx",
  "src/app/security/page.tsx",
  "src/app/trial/page.tsx",
];

for (const pagePath of pagePaths) {
  const page = read(pagePath);
  assert.match(page, /createPageMetadata/, `${pagePath} must use complete route metadata`);
  assert.match(page, /headingAs="h1"/, `${pagePath} must expose a page-level h1`);
  assert.match(page, /createBreadcrumbStructuredData/, `${pagePath} must expose breadcrumbs`);
}

const homePage = read("src/app/page.tsx");
assert.match(homePage, /ProductFactsSection/, "homepage must publish factual product data");
assert.match(homePage, /FaqSection/, "homepage must publish the current FAQ");

const faq = read("src/content/faq.ts");
const questionCount = (faq.match(/question:/g) ?? []).length;
assert.ok(questionCount >= 10, `expected at least 10 factual FAQ entries, found ${questionCount}`);

console.log(`SEO verification passed for ${expectedPublicRoutes.length} public routes and ${questionCount} FAQ entries.`);
