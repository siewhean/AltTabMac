import { BetaReleasePage } from "@/components/release/beta-release-page";

export const dynamic = "force-dynamic";

export default function BetaPage() {
  return <BetaReleasePage kind="download" />;
}
