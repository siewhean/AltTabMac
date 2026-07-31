import { BetaReleasePage } from "@/components/release/beta-release-page";

export const dynamic = "force-dynamic";

export default function BetaInstallationPage() {
  return <BetaReleasePage kind="installation" />;
}
