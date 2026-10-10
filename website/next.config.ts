import type { NextConfig } from "next";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const isProduction = process.env.NODE_ENV === "production";
const websiteRoot = dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  poweredByHeader: false,
  outputFileTracingRoot: resolve(websiteRoot, ".."),
  outputFileTracingIncludes: {
    "/releases/stable.json": ["../release/stable.json"],
  },
  async redirects() {
    // /waitlist is the one canonical page for early access. /trial and /buy used
    // to promise a trial and a purchase that are not open, and the native app
    // still links to /trial, so both stay as permanent redirects. Next.js passes
    // the query string (utm_*, ref) through to the destination.
    return [
      { source: "/trial", destination: "/waitlist", permanent: true },
      { source: "/buy", destination: "/waitlist", permanent: true },
    ];
  },
  async headers() {
    return [
      {
        source: "/dashboard/:path*",
        headers: [
          {
            key: "X-Robots-Tag",
            value: "noindex, nofollow, noarchive",
          },
        ],
      },
      {
        source: "/api/:path*",
        headers: [
          {
            key: "X-Robots-Tag",
            value: "noindex, nofollow, noarchive",
          },
        ],
      },
      {
        // Public images are not content-hashed, so cache for a day and
        // revalidate in the background rather than marking them immutable.
        source: "/:dir(brand|screenshots|showcase|email)/:path*",
        headers: [
          {
            key: "Cache-Control",
            value: "public, max-age=86400, stale-while-revalidate=604800",
          },
        ],
      },
      {
        source: "/:path*",
        headers: [
          { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
          { key: "Cross-Origin-Resource-Policy", value: "same-origin" },
          { key: "Origin-Agent-Cluster", value: "?1" },
          {
            key: "Permissions-Policy",
            value: "camera=(), geolocation=(), microphone=(), payment=(), usb=()",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
          { key: "X-DNS-Prefetch-Control", value: "off" },
          { key: "X-Permitted-Cross-Domain-Policies", value: "none" },
          ...(isProduction
            ? [
                {
                  key: "Strict-Transport-Security",
                  value: "max-age=31536000; includeSubDomains; preload",
                },
              ]
            : []),
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
        ],
      },
    ];
  },
};

export default nextConfig;
