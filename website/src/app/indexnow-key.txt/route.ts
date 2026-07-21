import { NextResponse } from "next/server";

import committedIndexNowKey from "@/content/indexnow-key.json";

export const dynamic = "force-dynamic";

function configuredKey() {
  const environmentKey = process.env.INDEXNOW_KEY?.trim();
  const key = environmentKey || committedIndexNowKey.key.trim();
  return /^[A-Za-z0-9-]{8,128}$/.test(key) ? key : undefined;
}

export async function GET() {
  const key = configuredKey();
  if (!key) {
    return new NextResponse("Not configured\n", {
      status: 404,
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
      },
    });
  }

  return new NextResponse(`${key}\n`, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "public, max-age=300, s-maxage=300",
      "X-Robots-Tag": "noindex, nofollow, noarchive",
    },
  });
}
