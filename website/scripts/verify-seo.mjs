import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path), "utf8");
const publicRoutes = JSON.parse(read("src/content/public-routes.json"));
const socialImage = read("src/app/opengraph-image.tsx");
assert.match(socialImage, /Join the waitlist/, "public social preview must identify waitlist availability");
assert.doesNotMatch(socialImage, /14-day free trial|One-time purchase/, "social preview must not advertise closed conversion paths");

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
assert.ok(publicRoutes.length >= 21, "expected the evidence-led feature and comparison architecture");

const routePaths = publicRoutes.map((route) => route.path);
assert.equal(new Set(routePaths).size, routePaths.length, "public route paths must be unique");
for (const requiredPath of [
  "/features/window-switcher",
  "/features/classic-grid",
  "/features/command-palette",
  "/features/radial-menu",
  "/features/quick-actions",
  "/guides/switch-between-windows-on-mac",
  "/compare/cmdtab-vs-macos-command-tab",
  "/compare/cmdtab-vs-alttab",
  "/compare/mac-window-switchers",
  "/evidence",
  "/faq",
  "/waitlist",
]) {
  assert.ok(routePaths.includes(requiredPath), `${requiredPath} is required`);
}
assert.ok(!routePaths.includes("/buy") && !routePaths.includes("/trial"), "retired conversion routes must not compete with the waitlist canonical page");
assert.ok(!routePaths.includes("/llms-full.txt"), "the non-standard context export must not compete in the HTML sitemap");
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

const site = read("src/content/site.ts");
const hero = read("src/components/sections/hero-section.tsx");
for (const content of [site, hero]) {
  assert.match(content, /standalone/i, "visible entity language must identify CmdTab as a standalone app");
  assert.match(content, /built-in Command-Tab/i, "visible entity language must disambiguate Apple’s shortcut");
}

const structuredData = read("src/lib/structured-data.ts");
for (const required of [
  '"SoftwareApplication"',
  '"Organization"',
  '"Person"',
  "softwareVersion",
  "softwareRequirements",
  "permissions",
  "disambiguatingDescription",
  "featureList",
  "sameAs",
  "createFaqStructuredData",
  "createArticleStructuredData",
  "createWebPageStructuredData",
  "citation",
]) {
  assert.ok(structuredData.includes(required), `structured data is missing ${required}`);
}
assert.match(structuredData, /standalone macOS window-switcher application/, "software schema must disambiguate the CmdTab entity");
assert.doesNotMatch(structuredData, /memoryRequirements|processorRequirements/, "unmeasured memory or processor claims must not enter schema");
assert.doesNotMatch(structuredData, /"Offer"|schema\.org\/InStock|configuredOffers|downloadUrl/, "waitlist-only software schema must not claim a purchasable or downloadable offer");

const homePage = read("src/app/page.tsx");
for (const requiredSection of ["HeroSection", "StylesSection", "FeatureBandsSection", "FooterSection"]) {
  assert.match(homePage, new RegExp(requiredSection), `homepage is missing ${requiredSection}`);
}
assert.doesNotMatch(
  homePage,
  /ProductFactsSection|DiscoveryResourcesSection|FaqSection|WalkthroughSection|RealShowcaseSection/,
  "homepage must keep long-form SEO and support material on its dedicated routes",
);
const mobileNavigation = read("src/components/ui/mobile-navigation.tsx");
for (const discoveryPath of ["/evidence", "/compare/mac-window-switchers", "/faq"]) {
  assert.ok(mobileNavigation.includes(discoveryPath), `mobile navigation must keep ${discoveryPath} easy to reach`);
}
const stylesSection = read("src/components/sections/styles-section.tsx");
for (const featurePath of ["/features/classic-grid", "/features/command-palette", "/features/radial-menu"]) {
  assert.ok(stylesSection.includes(featurePath), `homepage mode cards must link ${featurePath}`);
}

const featureDepth = read("src/content/feature-depth.ts");
for (const required of [
  'slug: "classic-grid"',
  'slug: "command-palette"',
  'slug: "radial-menu"',
  'slug: "quick-actions"',
  "exact-window",
  "Preview failure",
  "Tradeoffs and limits",
]) {
  assert.ok(featureDepth.includes(required), `deep feature content is missing ${required}`);
}
assert.match(featureDepth, /does not claim a fixed reveal latency/i, "feature pages must state the benchmark boundary");
assert.doesNotMatch(featureDepth, /ScreenCaptureKit|sub-50\s*ms|<\s*20\s*MB|Universal Binary/i, "feature pages contain an unproved technical claim");
const featureTemplate = read("src/components/seo/feature-detail-page.tsx");
assert.match(featureTemplate, /role="region"/, "feature behavior tables must be accessible keyboard regions");
assert.match(featureTemplate, /Best fit/, "feature pages must explain intended fit");
assert.match(featureTemplate, /Tradeoffs and limits/, "feature pages must explain limitations");

const faq = read("src/content/faq.ts");
const questionCount = (faq.match(/question:/g) ?? []).length;
assert.ok(questionCount >= 15, `expected at least 15 factual FAQ entries, found ${questionCount}`);
const faqPage = read("src/app/faq/page.tsx");
assert.match(faqPage, /createFaqStructuredData\(faqItems\)/, "FAQ schema must reuse the exact visible FAQ source");
assert.match(faqPage, /<FaqList items=\{faqItems\}/, "visible FAQ must match its structured answers");
assert.match(faq, /Can I download or buy CmdTab now\?/, "FAQ must answer current availability directly");
assert.match(faq, /Downloads, free trials, and purchases are not currently available/, "FAQ must make waitlist-only availability explicit");
assert.match(faq, /browser tabs/, "FAQ must distinguish windows from browser tabs");
const switchingGuide = read("src/app/guides/switch-between-windows-on-mac/page.tsx");
assert.match(switchingGuide, /createFaqStructuredData\(guideQuestions\)/, "guide schema must reuse its visible questions");
assert.match(switchingGuide, /<FaqList items=\{guideQuestions\}/, "guide answers must remain visible");
assert.match(switchingGuide, /support\.apple\.com\/en-us\/102650/, "native shortcut claims need the Apple keyboard-shortcut source");
assert.match(switchingGuide, /citation:/, "article schema must cite its visible primary sources");

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
assert.ok(landscapeOptionCount >= 6, `expected at least six source-reviewed switcher options, found ${landscapeOptionCount}`);
for (const requiredSource of [
  "support.apple.com",
  "alt-tab.app",
  "bettercmdtab.app",
  "contexts.co",
  "cmdtab.net",
  "scopo.app",
]) {
  assert.ok(landscape.includes(requiredSource), `market landscape is missing official source ${requiredSource}`);
}
assert.match(landscape, /missing claim is treated as unknown/, "comparison methodology must distinguish unknown from absent");
assert.match(landscape, /free trial and a US\$9\.99 license/, "Contexts commercial terms must remain source-dated");
assert.match(landscapePage, /source-dated first-party facts/i, "comparison page must expose its first-party source method");
assert.match(landscapePage, /role="region"/, "wide market comparison must be an accessible region");
assert.match(landscapePage, /createArticleStructuredData/, "market comparison must publish article structured data");
assert.match(landscapePage, /Contexts/, "Contexts must be visible in the landscape article context");

const altTabComparison = read("src/content/alttab-comparison.ts");
const altTabPage = read("src/app/compare/cmdtab-vs-alttab/page.tsx");
for (const required of ["alt-tab.app/pricing", "alt-tab.app/terms", "9.2 million downloads", "16,000 GitHub stars", "accepting waitlist signups"]) {
  assert.ok(altTabComparison.includes(required), `AltTab comparison is missing ${required}`);
}
assert.match(altTabComparison, /not a controlled reliability benchmark/, "AltTab adoption must not be misrepresented as reliability");
assert.match(altTabPage, /createArticleStructuredData/, "focused AltTab comparison must publish article schema");
assert.match(altTabPage, /role="region"/, "focused AltTab comparison must expose an accessible wide table");
assert.match(altTabPage, /Neither product wins every workflow/, "focused AltTab comparison must expose fair decision guidance");

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

assert.ok(existsSync(resolve(root, "src/app/llms.txt/route.ts")), "llms directory is missing");
const llms = read("src/app/llms.txt/route.ts");
assert.match(llms, /Availability: Waitlist only/, "retrieval directory must state current availability");
assert.match(llms, /Product behavior and modes/, "llms directory must describe the deep feature sources");
assert.match(llms, /Public evidence/, "llms directory must point to public evidence");
assert.match(llms, /Source-dated comparisons/, "llms directory must point to the comparison methodology");
assert.match(llms, /\/llms-full\.txt/, "llms directory must disclose the optional consolidated context export");
assert.match(llms, /not claimed as an AI-search requirement/, "llms directory must state the helper-file limitation");
assert.ok(existsSync(resolve(root, "src/app/llms-full.txt/route.ts")), "consolidated context export is missing");
const llmsFull = read("src/app/llms-full.txt/route.ts");
assert.match(llmsFull, /Availability: Waitlist only/, "consolidated context must state current availability");
assert.doesNotMatch(llmsFull, /Current personal-license price/, "consolidated context must not advertise a current purchase");
assert.match(llmsFull, /non-standard convenience export/, "consolidated context must identify itself as non-standard");
assert.match(llmsFull, /canonical HTML as authoritative/, "consolidated context must defer to canonical HTML");
assert.match(llmsFull, /"X-Robots-Tag": "noindex, follow"/, "consolidated context must be noindex");
assert.match(llmsFull, /No processor architecture, Universal Binary status, memory footprint/, "consolidated context must expose the unsupported-spec boundary");
assert.match(llmsFull, /Does CmdTab use ScreenCaptureKit\?/, "consolidated context must correct the unsupported ScreenCaptureKit claim");

const directoryPack = read("../docs/seo/software-directory-submission-pack.md");
assert.match(directoryPack, /does \*\*not\*\* claim that CmdTab has been submitted/i, "directory pack must not pretend listings exist");
for (const directory of ["AlternativeTo", "Product Hunt", "MacUpdate", "Softpedia", "StackShare"]) {
  assert.ok(directoryPack.includes(directory), `directory submission pack is missing ${directory}`);
}
assert.match(directoryPack, /Not submitted/g, "directory statuses must remain explicit until owner actions occur");
assert.doesNotMatch(directoryPack, /ScreenCaptureKit fast-path|sub-50\s*ms|<\s*20\s*MB|Universal Binary `arm64 \+ x86_64`/i, "directory pack contains an unproved technical claim");
assert.ok(existsSync(resolve(root, "../docs/seo/review-feedback-implementation-plan.md")), "feedback implementation plan is missing");

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
  `SEO verification passed for ${publicRoutes.length} public routes, ${questionCount} FAQ entries, ${landscapeOptionCount} source-reviewed switcher options, four factual feature references, a focused AltTab comparison, a noindex consolidated context export, public byte-matched evidence, packaged version ${appVersion}, webmaster verification hooks, a stable IndexNow key, and AI discovery instrumentation.`,
);
