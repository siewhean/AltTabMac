import { permanentRedirect } from "next/navigation";
import { waitlistRedirectPath } from "@/lib/waitlist-redirect";

export default async function LegacyAccessPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  permanentRedirect(waitlistRedirectPath(await searchParams));
}
