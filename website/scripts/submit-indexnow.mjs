import committedIndexNowKey from "../src/content/indexnow-key.json" with { type: "json" };
import publicRoutes from "../src/content/public-routes.json" with { type: "json" };

const key = process.env.INDEXNOW_KEY?.trim() || committedIndexNowKey.key.trim();
const candidateSiteUrl =
  process.env.NEXT_PUBLIC_SITE_URL?.trim() ||
  process.env.SITE_URL?.trim() ||
  "https://cmdtab.net";

if (!/^[A-Za-z0-9-]{8,128}$/.test(key)) {
  throw new Error("INDEXNOW_KEY must contain 8-128 letters, numbers, or hyphens.");
}

const siteUrl = new URL(candidateSiteUrl);
const normalizedBase = new URL("/", siteUrl);
const urlList = publicRoutes.map(({ path }) => new URL(path, normalizedBase).toString());

const response = await fetch("https://api.indexnow.org/indexnow", {
  method: "POST",
  headers: {
    "Content-Type": "application/json; charset=utf-8",
  },
  body: JSON.stringify({
    host: siteUrl.host,
    key,
    keyLocation: new URL("/indexnow-key.txt", normalizedBase).toString(),
    urlList,
  }),
});

if (!response.ok) {
  const responseText = await response.text();
  throw new Error(
    `IndexNow rejected the submission (${response.status}): ${responseText.slice(0, 500)}`,
  );
}

console.log(`Submitted ${urlList.length} canonical URLs to IndexNow for ${siteUrl.host}.`);
