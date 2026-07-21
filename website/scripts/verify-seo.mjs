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
assert.ok(publicRoutes.length >= 16, "expected a substantive public discovery architecture");

const routePaths = publicRoutes.map((route) => route.path);
assert.equal(new Set(routePaths).size, routePaths.length, "public route paths must be unique");
assert.ok(routePaths.includes("/features/window-switcher"), "window-switcher feature page is required");
assert.ok(routePaths.includes("/guides/switch-between-windows-on-mac"), "Mac window guide is required");
assert.ok(routePaths.includes("/compare/cmdtab-vs-macos-command-tab"), "native comparison page is required");
assert.ok(routePaths.includes("/compare/mac-window-switchers"), "source-dated market comparison is required");
assert.ok(routePaths.includes("/evidence"), "public evidence ledger is required");
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
assert.match(rootLayout, /GOOGLE_SITE_VERIFICATION/, "Google Search Console verification hook is missing");
assert.match(rootLayout, /BING_SITE_VERIFICATION/, "Bing Webmaster Tools verification hook is missing");
assert.match(rootLayout, /"msvalidate\.01"/, "Bing verification must emit the documented meta name");
assert.match(rootLayout, /verification:\s*webmasterVerification\(\)/, "webmaster verification metadata is not wired");

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
  "citation",
]) {
  assert.ok(structuredData.includes(required), `structured data is missing ${required}`);
}
assert.match(structuredData, /getCommerceConfig/, "software offers must use the visible commerce configuration");
assert.match(structuredData, /commerce\.trialDownloadUrl/, "trial structured data must require a configured download URL");
assert.match(structuredData, /commerce\.checkoutUrl/, "founder offer structured data must require a configured checkout URL");
assert.match(structuredData, /commerce\.standardCheckoutUrl/, "standard offer structured data must require a configured checkout URL");
assert.match(structuredData, /offers\.length > 0/, "empty or unavailable offers must not be emitted as InStock");

const homePage = read("src/app/page.tsx");
assert.match(homePage, /ProductFactsSection/, "homepage must publish factual product data");
assert.match(homePage, /DiscoveryResourcesSection/, "homepage must link authoritative discovery resources");
assert.match(homePage, /FaqSection/, "homepage must publish a focused FAQ entry point");
const discoveryResources = read("src/components/sections/discovery-resources-section.tsx");
assert.match(discoveryResources, /\/evidence/, "homepage resources must link the evidence ledger");
assert.match(discoveryResources, /\/compare\/mac-window-switchers/, "homepage resources must link the market landscape");

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

const evidence = read("src/content/evidence.ts");
const evidencePage = read("src/app/evidence/page.tsx");
assert.match(evidence, /productAlignmentCommit/, "evidence ledger must identify the aligned product commit");
assert.match(evidence, /19,500 meaningful activation sequences/, "evidence ledger must preserve the exact model scope");
assert.match(evidence, /not a measured field failure rate/, "evidence ledger must state the model limitation");
assert.match(evidencePage, /State-space counts are not field failure rates/, "evidence page must visibly explain model limits");
assert.match(evidencePage, /createArticleStructuredData/, "evidence page must publish article structured data");
const evidenceCopies = [
  ["public/evidence/switcher-model-results.json", "../docs/qa/AltTabMac_model_results.json"],
  ["public/evidence/switcher-test-matrix.csv", "../docs/qa/AltTabMac_comprehensive_test_matrix.csv"],
  ["public/evidence/switcher-test-plan.md", "../docs/qa/AltTabMac_implementation_review_and_test_plan.md"],
];
for (const [publicPath, canonicalPath] of evidenceCopies) {
  assert.ok(existsSync(resolve(root, publicPath)), `missing public evidence artifact ${publicPath}`);
  assert.equal(read(publicPath), read(canonicalPath), `${publicPath} must remain byte-identical to ${canonicalPath}`);
}

const landscape = read("src/content/market-landscape.ts");
const landscapePage = read("src/app/compare/mac-window-switchers/page.tsx");
const landscapeOptionCount = (landscape.match(/\bid:\s*"/g) ?? []).length;
assert.ok(landscapeOptionCount >= 5, `expected at least five source-reviewed switcher options, found ${landscapeOptionCount}`);
for (const requiredSource of [
  "support.apple.com",
  "alt-tab.app",
  "bettercmdtab.app",
  "cmdtab.net",
  "scopo.app",
]) {
  assert.ok(landscape.includes(requiredSource), `market landscape is missing official source ${requiredSource}`);
}
assert.match(landscape, /missing claim is treated as unknown/, "comparison methodology must distinguish unknown from absent");
assert.match(landscapePage, /source-dated first-party facts/i, "comparison page must expose its first-party source method");
assert.match(landscapePage, /role="region"/, "wide market comparison must be an accessible region");
assert.match(landscapePage, /createArticleStructuredData/, "market comparison must publish article structured data");

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
assert.ok(existsSync(resolve(root, "src/content/indexnow-key.json")), "stable IndexNow key configuration is missing");
const indexNowKey = JSON.parse(read("src/content/indexnow-key.json")).key;
assert.match(indexNowKey, /^[A-Za-z0-9-]{8,128}$/, "IndexNow key must contain 8-128 letters, numbers, or hyphens");
const indexNowRoute = read("src/app/indexnow-key.txt/route.ts");
const indexNowSubmit = read("scripts/submit-indexnow.mjs");
assert.match(indexNowRoute, /indexnow-key\.json/, "IndexNow key route must use the stable ownership key");
assert.match(indexNowRoute, /process\.env\.INDEXNOW_KEY/, "IndexNow key route must allow an environment override");
assert.match(indexNowSubmit, /indexnow-key\.json/, "IndexNow submissions must use the deployed ownership key");
assert.match(indexNowSubmit, /keyLocation/, "IndexNow submissions must declare the public key location");

assert.ok(existsSync(resolve(root, "src/app/llms.txt/route.ts")), "canonical-only llms directory is missing");
const llms = read("src/app/llms.txt/route.ts");
assert.match(llms, /Public evidence/, "llms directory must point to public evidence");
assert.match(llms, /Source-dated market comparison/, "llms directory must point to the comparison methodology");

const packageJson = JSON.parse(read("package.json"));
assert.equal(packageJson.scripts["indexnow:submit"], "node scripts/submit-indexnow.mjs", "IndexNow package script is missing");
assert.equal(
  packageJson.scripts["webmaster:check"],
  "node scripts/verify-webmaster-metadata.mjs",
  "rendered webmaster verification script is missing",
);
assert.ok(existsSync(resolve(root, "scripts/verify-webmaster-metadata.mjs")), "webmaster metadata verifier is missing");
const seoWorkflow = read("../.github/workflows/seo.yml");
assert.match(seoWorkflow, /GOOGLE_SITE_VERIFICATION:/, "SEO workflow must exercise Google verification metadata");
assert.match(seoWorkflow, /BING_SITE_VERIFICATION:/, "SEO workflow must exercise Bing verification metadata");
assert.match(seoWorkflow, /npm run webmaster:check/, "SEO workflow must verify rendered webmaster metadata");
assert.ok(isAtLeast(packageJson.dependencies.next, "16.2.6"), `Next.js must stay at 16.2.6 or later; found ${packageJson.dependencies.next}`);
assert.ok(isAtLeast(packageJson.dependencies.react, "19.2.6"), `React must stay at 19.2.6 or later; found ${packageJson.dependencies.react}`);
assert.ok(isAtLeast(packageJson.dependencies["react-dom"], "19.2.6"), `React DOM must stay at 19.2.6 or later; found ${packageJson.dependencies["react-dom"]}`);
const envExample = read(".env.example");
assert.match(envExample, /INDEXNOW_KEY=/, "IndexNow environment configuration is missing");
assert.match(envExample, /GOOGLE_SITE_VERIFICATION=/, "Google verification environment configuration is missing");
assert.match(envExample, /BING_SITE_VERIFICATION=/, "Bing verification environment configuration is missing");

console.log(
  `SEO verification passed for ${publicRoutes.length} public routes, ${questionCount} FAQ entries, ${landscapeOptionCount} source-reviewed switcher options, public byte-matched evidence, packaged version ${appVersion}, webmaster verification hooks, a stable IndexNow key, and AI discovery instrumentation.`,
);
