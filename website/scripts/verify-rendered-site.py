#!/usr/bin/env python3
"""Verify rendered CmdTab pages and crawler-facing HTTP contracts.

Run after `next build` and `next start`:
  VERIFY_BASE_URL=http://127.0.0.1:3000 python3 scripts/verify-rendered-site.py
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import date
from html.parser import HTMLParser
from pathlib import Path
from typing import Any

BASE_URL = os.environ.get("VERIFY_BASE_URL", "http://127.0.0.1:3000").rstrip("/")
CANONICAL_ORIGIN = os.environ.get("VERIFY_CANONICAL_ORIGIN", "https://cmdtab.net").rstrip("/")
ROOT = Path(__file__).resolve().parents[1]
PUBLIC_ROUTES = json.loads((ROOT / "src/content/public-routes.json").read_text(encoding="utf-8"))
FAILURES: list[str] = []


def fail(message: str) -> None:
    FAILURES.append(message)


def normalized_url(value: str) -> str:
    parsed = urllib.parse.urlsplit(value)
    path = parsed.path or "/"
    if path != "/":
        path = path.rstrip("/")
    return urllib.parse.urlunsplit((parsed.scheme.lower(), parsed.netloc.lower(), path, parsed.query, ""))


def expected_canonical(path: str) -> str:
    return normalized_url(f"{CANONICAL_ORIGIN}{path if path != '/' else '/'}")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[override]
        return None


def fetch(path: str, *, follow_redirects: bool = True, method: str = "GET") -> tuple[int, str, Any, str]:
    url = path if path.startswith("http://") or path.startswith("https://") else f"{BASE_URL}{path}"
    request = urllib.request.Request(
        url,
        method=method,
        headers={"User-Agent": "CmdTabRenderedVerifier/1.0", "Accept": "*/*"},
    )
    opener = urllib.request.build_opener() if follow_redirects else urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(request, timeout=20) as response:
            body = response.read().decode("utf-8", errors="replace")
            return int(response.status), body, response.headers, response.geturl()
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        return int(error.code), body, error.headers, error.geturl()
    except Exception as error:  # pragma: no cover - useful diagnostic in CI
        fail(f"request failed for {url}: {error}")
        return 0, "", {}, url


class ParsedPage(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title_parts: list[str] = []
        self.h1_parts: list[str] = []
        self.visible_text: list[str] = []
        self.meta: dict[str, list[str]] = {}
        self.canonicals: list[str] = []
        self.json_ld_raw: list[str] = []
        self.links: list[str] = []
        self.images_without_alt: list[str] = []
        self.breadcrumb_navs = 0
        self._title_depth = 0
        self._h1_depth = 0
        self._script_type: str | None = None
        self._script_parts: list[str] = []
        self._hidden_depth = 0

    def handle_starttag(self, tag: str, attrs_raw: list[tuple[str, str | None]]) -> None:
        attrs = {key.lower(): (value or "") for key, value in attrs_raw}
        tag = tag.lower()
        if tag == "title":
            self._title_depth += 1
        elif tag == "h1":
            self._h1_depth += 1
        elif tag in {"script", "style", "template", "noscript"}:
            self._hidden_depth += 1
        if tag == "script":
            self._script_type = attrs.get("type", "").lower()
            self._script_parts = []
        if tag == "meta":
            key = (attrs.get("property") or attrs.get("name") or attrs.get("http-equiv") or "").lower()
            content = attrs.get("content", "").strip()
            if key and content:
                self.meta.setdefault(key, []).append(content)
        elif tag == "link":
            rel_tokens = {token.lower() for token in attrs.get("rel", "").split()}
            if "canonical" in rel_tokens and attrs.get("href"):
                self.canonicals.append(attrs["href"])
        elif tag == "nav" and "breadcrumb" in attrs.get("aria-label", "").lower():
            self.breadcrumb_navs += 1
        elif tag == "a" and attrs.get("href"):
            self.links.append(attrs["href"])
        elif tag == "img" and "alt" not in attrs:
            self.images_without_alt.append(attrs.get("src", "<unknown>"))

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag == "title" and self._title_depth:
            self._title_depth -= 1
        elif tag == "h1" and self._h1_depth:
            self._h1_depth -= 1
        if tag == "script":
            if self._script_type == "application/ld+json":
                self.json_ld_raw.append("".join(self._script_parts).strip())
            self._script_type = None
            self._script_parts = []
        if tag in {"script", "style", "template", "noscript"} and self._hidden_depth:
            self._hidden_depth -= 1

    def handle_data(self, data: str) -> None:
        if self._script_type is not None:
            self._script_parts.append(data)
        if self._title_depth:
            self.title_parts.append(data)
        if self._h1_depth:
            self.h1_parts.append(data)
        if self._hidden_depth == 0 and data.strip():
            self.visible_text.append(data.strip())

    @property
    def title(self) -> str:
        return " ".join(" ".join(self.title_parts).split())

    @property
    def h1(self) -> str:
        return " ".join(" ".join(self.h1_parts).split())

    @property
    def body_text_length(self) -> int:
        return len(" ".join(self.visible_text))


def parse_html(body: str) -> ParsedPage:
    parser = ParsedPage()
    parser.feed(body)
    parser.close()
    return parser


def collect_schema_types(value: Any) -> set[str]:
    result: set[str] = set()
    if isinstance(value, dict):
        schema_type = value.get("@type")
        if isinstance(schema_type, str):
            result.add(schema_type)
        elif isinstance(schema_type, list):
            result.update(item for item in schema_type if isinstance(item, str))
        for child in value.values():
            result.update(collect_schema_types(child))
    elif isinstance(value, list):
        for child in value:
            result.update(collect_schema_types(child))
    return result


def meta_value(page: ParsedPage, key: str) -> str:
    values = page.meta.get(key.lower(), [])
    return values[0].strip() if values else ""


route_paths = [entry["path"] for entry in PUBLIC_ROUTES]
expected_route_set = {expected_canonical(path) for path in route_paths}
parsed_pages: dict[str, ParsedPage] = {}
internal_paths: set[str] = set()
titles: dict[str, str] = {}

for path in route_paths:
    status, body, headers, final_url = fetch(path)
    if status != 200:
        fail(f"{path}: expected HTTP 200, received {status}")
        continue
    if normalized_url(final_url) != normalized_url(f"{BASE_URL}{path}"):
        fail(f"{path}: unexpected redirect to {final_url}")
    content_type = str(headers.get("Content-Type", "")).lower()
    if "text/html" not in content_type:
        fail(f"{path}: expected HTML content type, received {content_type!r}")

    page = parse_html(body)
    parsed_pages[path] = page
    if page.body_text_length < 250:
        fail(f"{path}: rendered body is suspiciously short ({page.body_text_length} characters)")
    if not page.title or "cmdtab" not in page.title.lower():
        fail(f"{path}: missing a descriptive CmdTab title")
    elif page.title in titles:
        fail(f"{path}: duplicate title also used by {titles[page.title]}: {page.title!r}")
    else:
        titles[page.title] = path

    description = meta_value(page, "description")
    if len(description) < 70:
        fail(f"{path}: meta description is missing or too short ({len(description)} characters)")
    canonical = normalized_url(page.canonicals[0]) if len(page.canonicals) == 1 else ""
    if len(page.canonicals) != 1:
        fail(f"{path}: expected exactly one canonical, found {len(page.canonicals)}")
    elif canonical != expected_canonical(path):
        fail(f"{path}: canonical {canonical!r} does not match {expected_canonical(path)!r}")

    required_meta = {
        "og:title": page.title.replace(" | CmdTab", ""),
        "og:description": description,
        "og:url": expected_canonical(path),
        "twitter:card": "summary_large_image",
        "twitter:title": page.title.replace(" | CmdTab", ""),
        "twitter:description": description,
    }
    for key, expected in required_meta.items():
        actual = meta_value(page, key)
        if key == "og:url":
            actual = normalized_url(actual) if actual else actual
        if not actual:
            fail(f"{path}: missing {key}")
        elif key in {"og:description", "twitter:description"} and actual != expected:
            fail(f"{path}: {key} does not match the page description")
        elif key == "twitter:card" and actual != expected:
            fail(f"{path}: expected summary_large_image Twitter card, found {actual!r}")
        elif key == "og:url" and actual != expected:
            fail(f"{path}: og:url {actual!r} does not match canonical {expected!r}")
    for key in ("og:image", "twitter:image"):
        image = meta_value(page, key)
        if not image.startswith("https://cmdtab.net/"):
            fail(f"{path}: {key} must be an absolute cmdtab.net URL, found {image!r}")

    robots = meta_value(page, "robots").lower()
    if "noindex" in robots:
        fail(f"{path}: public page unexpectedly contains noindex")
    if page.h1.count("\n") or not page.h1:
        fail(f"{path}: missing page-level H1 text")
    h1_count = len(re.findall(r"<h1(?:\s|>)", body, flags=re.IGNORECASE))
    if h1_count != 1:
        fail(f"{path}: expected exactly one H1, found {h1_count}")
    if path != "/" and page.breadcrumb_navs < 1:
        fail(f"{path}: visible breadcrumb navigation is missing")
    if page.images_without_alt:
        fail(f"{path}: images without alt attributes: {page.images_without_alt}")

    schema_values: list[Any] = []
    for raw in page.json_ld_raw:
        try:
            schema_values.append(json.loads(raw))
        except json.JSONDecodeError as error:
            fail(f"{path}: invalid JSON-LD: {error}")
    schema_types = collect_schema_types(schema_values)
    if path == "/":
        for required_type in ("Person", "Organization", "WebSite", "SoftwareApplication"):
            if required_type not in schema_types:
                fail(f"/: missing {required_type} structured data")
    else:
        for required_type in ("WebPage", "BreadcrumbList"):
            if required_type not in schema_types:
                fail(f"{path}: missing {required_type} structured data")
    if path == "/faq" and "FAQPage" not in schema_types:
        fail("/faq: missing FAQPage structured data")
    if path == "/guides/switch-between-windows-on-mac" and "TechArticle" not in schema_types:
        fail(f"{path}: missing TechArticle structured data")

    for href in page.links:
        if not href or href.startswith(("#", "mailto:", "tel:", "javascript:")):
            continue
        parsed = urllib.parse.urlsplit(href)
        if parsed.scheme in {"http", "https"} and parsed.netloc.lower() not in {"cmdtab.net", "www.cmdtab.net"}:
            continue
        link_path = parsed.path or "/"
        if link_path.startswith(("/api/", "/dashboard")):
            continue
        if re.search(r"\.[a-zA-Z0-9]{2,8}$", link_path):
            continue
        internal_paths.add(link_path.rstrip("/") or "/")

for link_path in sorted(internal_paths):
    status, _body, _headers, _url = fetch(link_path)
    if status >= 400 or status == 0:
        fail(f"internal link {link_path!r} returned HTTP {status}")

# Crawler and machine-readable surfaces.
status, robots_body, robots_headers, _ = fetch("/robots.txt")
if status != 200:
    fail(f"/robots.txt returned HTTP {status}")
for expected in (
    "User-agent: OAI-SearchBot",
    "Disallow: /api/",
    f"Sitemap: {CANONICAL_ORIGIN}/sitemap.xml",
):
    if expected not in robots_body:
        fail(f"/robots.txt is missing {expected!r}")
if "text/plain" not in str(robots_headers.get("Content-Type", "")).lower():
    fail("/robots.txt has the wrong content type")

status, sitemap_body, sitemap_headers, _ = fetch("/sitemap.xml")
if status != 200:
    fail(f"/sitemap.xml returned HTTP {status}")
else:
    try:
        root = ET.fromstring(sitemap_body)
        namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
        entries = []
        for node in root.findall("sm:url", namespace):
            loc = node.findtext("sm:loc", default="", namespaces=namespace)
            lastmod = node.findtext("sm:lastmod", default="", namespaces=namespace)
            entries.append((normalized_url(loc), lastmod))
        sitemap_urls = {loc for loc, _lastmod in entries}
        if sitemap_urls != expected_route_set:
            fail(f"sitemap URL set mismatch; missing={sorted(expected_route_set - sitemap_urls)}, extra={sorted(sitemap_urls - expected_route_set)}")
        for loc, lastmod in entries:
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", lastmod):
                fail(f"sitemap has invalid lastmod for {loc}: {lastmod!r}")
            elif date.fromisoformat(lastmod) > date.today():
                fail(f"sitemap lastmod is in the future for {loc}: {lastmod}")
    except ET.ParseError as error:
        fail(f"/sitemap.xml is invalid XML: {error}")
if "xml" not in str(sitemap_headers.get("Content-Type", "")).lower():
    fail("/sitemap.xml has the wrong content type")

status, llms_body, llms_headers, _ = fetch("/llms.txt")
if status != 200:
    fail(f"/llms.txt returned HTTP {status}")
for canonical in sorted(expected_route_set):
    if canonical not in llms_body:
        fail(f"/llms.txt is missing canonical URL {canonical}")
if "/dashboard" in llms_body or "/api/" in llms_body:
    fail("/llms.txt exposes private or API routes")
if "text/plain" not in str(llms_headers.get("Content-Type", "")).lower():
    fail("/llms.txt has the wrong content type")

status, manifest_body, manifest_headers, _ = fetch("/manifest.webmanifest")
if status != 200:
    fail(f"/manifest.webmanifest returned HTTP {status}")
else:
    try:
        manifest = json.loads(manifest_body)
        if manifest.get("name") != "CmdTab" or manifest.get("short_name") != "CmdTab":
            fail("manifest product name is incorrect")
        icons = manifest.get("icons") or []
        if len(icons) < 1:
            fail("manifest should include at least one application icon")
        for icon in icons:
            icon_status, _icon_body, _icon_headers, _ = fetch(str(icon.get("src", "")))
            if icon_status != 200:
                fail(f"manifest icon {icon.get('src')!r} returned HTTP {icon_status}")
    except json.JSONDecodeError as error:
        fail(f"manifest is invalid JSON: {error}")
if "manifest" not in str(manifest_headers.get("Content-Type", "")).lower() and "json" not in str(manifest_headers.get("Content-Type", "")).lower():
    fail("manifest has the wrong content type")

status, key_body, key_headers, _ = fetch("/indexnow-key.txt")
if status not in {200, 404}:
    fail(f"/indexnow-key.txt returned unexpected HTTP {status}")
if "noindex" not in str(key_headers.get("X-Robots-Tag", "")).lower():
    fail("IndexNow key endpoint must be noindex")
if status == 200 and not re.fullmatch(r"[A-Za-z0-9-]{8,128}\n?", key_body):
    fail("configured IndexNow key endpoint returned an invalid key")
if status == 404 and "Not configured" not in key_body:
    fail("unconfigured IndexNow key endpoint returned an unexpected body")

# Private routes and security headers.
status, dashboard_body, dashboard_headers, _ = fetch("/dashboard/login")
if status != 200:
    fail(f"/dashboard/login returned HTTP {status}")
if "noindex" not in str(dashboard_headers.get("X-Robots-Tag", "")).lower():
    fail("dashboard response is missing X-Robots-Tag noindex")
if status == 200:
    dashboard_page = parse_html(dashboard_body)
    if "noindex" not in meta_value(dashboard_page, "robots").lower():
        fail("dashboard HTML metadata is missing noindex")

status, _api_body, api_headers, _ = fetch("/api/analytics")
if status not in {404, 405}:
    fail(f"GET /api/analytics should not be a public success response; received {status}")
if "noindex" not in str(api_headers.get("X-Robots-Tag", "")).lower():
    fail("API response is missing X-Robots-Tag noindex")

status, _missing_body, _missing_headers, _ = fetch("/__cmdtab_verifier_missing__")
if status != 404:
    fail(f"unknown route should return HTTP 404, received {status}")

root_status, _root_body, root_headers, _ = fetch("/")
if root_status == 200:
    required_headers = {
        "Content-Security-Policy": "default-src",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "Referrer-Policy": "strict-origin-when-cross-origin",
    }
    for header, expected_fragment in required_headers.items():
        actual = str(root_headers.get(header, ""))
        if expected_fragment.lower() not in actual.lower():
            fail(f"root response is missing {header}: expected {expected_fragment!r}, found {actual!r}")

if FAILURES:
    print("Rendered-site verification FAILED:", file=sys.stderr)
    for index, message in enumerate(FAILURES, start=1):
        print(f"  {index}. {message}", file=sys.stderr)
    raise SystemExit(1)

print(
    f"Rendered-site verification passed for {len(route_paths)} public pages, "
    f"{len(internal_paths)} internal links, crawler surfaces, private-route headers, and structured data."
)
