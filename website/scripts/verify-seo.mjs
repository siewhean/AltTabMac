import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path), "utf8");
const publicRoutes = JSON.parse(read("src/content/public-routes.json"));

function versionTuple(value) {
  const match = String(value).match(/\d+\.\d+\.\d+/);
  assert.ok(match, `could not parse semantic version from ${value}`);
  return match[0].split(".").map(Number);
}

function isAtLeast(value, minimum) {
  const actual = versionTuple(value);
  const required = versionTuple(minimum);
  for (let index = 0; index < Math.max(actual.length, required.length); index += 1) {
    const left = actual[index] ?? 0;
    const right = required[index] ?? 0;
    if (left !== right) return left > right;
  }
  return true;
}

assert.ok(Array.isArray(publicRoutes), "public route registry must be an array");
assert.ok(publicRoutes.length >= 14, "expected a substantive public discovery architecture");

const routePaths = publicRoutes.map((route) => route.path);
assert.equal(new Set(routePaths).size, routePaths.length, "public route paths must be unique");
assert.ok(routePaths.includes("/features/window-switcher"), "window-switcher feature page is required");
assert.ok(routePaths.includes("/guides/switch-between-windows-on-mac"), "Mac window guide is required");
assert.ok(routePaths.includes("/compare/cmdtab-vs-macos-command-tab"), "native comparison page is required");
assert.ok(routePaths.includes("/faq"), "canonical FAQ page is required");
assert.ok(!routePaths.some((path) => path.startsWith("/dashboard") || path.startsWith("/api")), "private routes must not be public");

for (const route of publicRoutes) {
  assert.match(route.path, /^\/(?:[a-z0-9-]+(?:\/[a-z0-9-]+)*)?$/, `invalid canonical path: ${route.path}`);
  assert.match(route.lastModified, /^\d{4}-\d{2}-\d{2}$/, `invalid review date for ${route.path}`);
  assert.ok(!Number.isNaN(Date.parse(`${route.lastModified}T00:00:00Z`)), `unparseable review date for ${route.path}`);

  if (route.path === "/") continue;
  const pagePath = `src/app${route.path}/page.tsx`;
  assert.ok(existsSync(resolve(root, pagePath)), `missing page file for ${route.path}`);
  const page = read(pagePath);
  assert.match(page, /createPageMetadata/, `${pagePath} must use complete route metadata`);
  assert.match(page, /headingAs="h1"/, `${pagePath} must expose one page-level h1`);
  assert.match(page, /createBreadcrumbStructuredData/, `${pagePath} must expose breadcrumb schema`);
  assert.match(page, /breadcrumbs=\{breadcrumbs\}/, `${pagePath} must render visible breadcrumbs`);
  assert.match(page, /createWebPageStructuredData/, `${pagePath} must identify itself as a web page`);
}

const sitemap = read("src/app/sitemap.ts");
assert.match(sitemap, /public-routes\.json/, "sitemap must use the canonical route registry");
assert.match(sitemap, /lastModified/, "sitemap must publish maintained modification dates");
assert.doesNotMatch(sitemap, /new Date\(\)/, "sitemap must not publish generation time as lastModified");
assert.doesNotMatch(sitemap, /dashboard|\/api\//, "private routes must not appear in the sitemap implementation");

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

const structuredData = read("src/lib/structured-data.ts");
for (const required of [
  '"SoftwareApplication"',
  '"Organization"',
  '"Person"',
  "softwareVersion",
  "softwareRequirements",
  "featureList",
  "sameAs",
  "createFaqStructuredData",
  "createArticleStructuredData",
  "createWebPageStructuredData",
]) {
  assert.ok(structuredData.includes(required), `structured data is missing ${required}`);
}

const homePage = read("src/app/page.tsx");
assert.match(homePage, /ProductFactsSection/, "homepage must publish factual product data");
assert.match(homePage, /DiscoveryResourcesSection/, "homepage must link authoritative discovery resources");
assert.match(homePage, /FaqSection/, "homepage must publish a focused FAQ entry point");

const faq = read("src/content/faq.ts");
const questionCount = (faq.match(/question:/g) ?? []).length;
assert.ok(questionCount >= 15, `expected at least 15 factual FAQ entries, found ${questionCount}`);
const faqPage = read("src/app/faq/page.tsx");
assert.match(faqPage, /createFaqStructuredData/, "FAQ page must publish matching FAQ structured data");

const privacy = read("src/content/legal.ts");
assert.match(privacy, /hourly heartbeat/, "privacy disclosure must describe native app heartbeat telemetry");
assert.match(privacy, /pseudonymous install identifier/, "privacy disclosure must identify the app install identifier");
assert.match(privacy, /does not contain window titles/, "privacy disclosure must identify excluded local window content");
assert.match(privacy, /visitor identifier/, "privacy disclosure must describe first-party website analytics IDs");

const productFacts = read("src/content/product-facts.ts");
const infoPlist = read("../Resources/Info.plist");
const appVersion = infoPlist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
const appBuild = infoPlist.match(/<key>CFBundleVersion<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
const minimumSystem = infoPlist.match(/<key>LSMinimumSystemVersion<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
assert.ok(appVersion && appBuild && minimumSystem, "could not read packaged app metadata");
assert.match(productFacts, new RegExp(`currentVersion:\\s*"${appVersion.replaceAll(".", "\\.")}"`), "public version must match Info.plist");
assert.match(productFacts, new RegExp(`buildNumber:\\s*"${appBuild}"`), "public build must match Info.plist");
assert.match(productFacts, new RegExp(`macOS ${minimumSystem.replaceAll(".", "\\.")}`), "public minimum macOS must match Info.plist");

const analyticsClient = read("src/lib/site-analytics-client.ts");
for (const source of ["chatgpt", "perplexity", "microsoft_copilot", "google_gemini", "claude"]) {
  assert.ok(analyticsClient.includes(`"${source}"`), `analytics classification is missing ${source}`);
}
assert.match(analyticsClient, /discoverySource/, "pageviews must record a broad discovery source");
assert.doesNotMatch(analyticsClient, /searchParams\.get\(["'](?:q|query|prompt)["']\)/, "discovery analytics must not collect search queries or prompts");
assert.ok(existsSync(resolve(root, "src/app/dashboard/discovery/page.tsx")), "AI discovery dashboard is missing");
assert.ok(existsSync(resolve(root, "src/lib/discovery-analytics-store.ts")), "AI discovery store is missing");

assert.ok(existsSync(resolve(root, "src/app/indexnow-key.txt/route.ts")), "IndexNow key route is missing");
assert.ok(existsSync(resolve(root, "scripts/submit-indexnow.mjs")), "IndexNow submission script is missing");
assert.ok(existsSync(resolve(root, "src/app/llms.txt/route.ts")), "canonical-only llms directory is missing");
const packageJson = JSON.parse(read("package.json"));
assert.equal(packageJson.scripts["indexnow:submit"], "node scripts/submit-indexnow.mjs", "IndexNow package script is missing");
assert.ok(isAtLeast(packageJson.dependencies.next, "16.2.6"), `Next.js must stay at 16.2.6 or later; found ${packageJson.dependencies.next}`);
assert.ok(isAtLeast(packageJson.dependencies.react, "19.2.6"), `React must stay at 19.2.6 or later; found ${packageJson.dependencies.react}`);
assert.ok(isAtLeast(packageJson.dependencies["react-dom"], "19.2.6"), `React DOM must stay at 19.2.6 or later; found ${packageJson.dependencies["react-dom"]}`);
assert.match(read(".env.example"), /INDEXNOW_KEY=/, "IndexNow environment configuration is missing");

console.log(
  `SEO verification passed for ${publicRoutes.length} public routes, ${questionCount} FAQ entries, packaged version ${appVersion}, and AI discovery instrumentation.`,
);
