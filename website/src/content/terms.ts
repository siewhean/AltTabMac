import { productFacts } from "@/content/product-facts";

export const termsReviewedAt = "2026-07-27";

export const termsSections = [
  {
    title: "License and permitted use",
    body: [
      `A purchase grants one person a perpetual, non-transferable license to use CmdTab on up to ${productFacts.licensedMacs} personally owned Macs. The license is not a subscription and device slots do not expire automatically.`,
      `The license includes ${productFacts.updateEntitlement}. A future major version may be offered separately, but the purchased 1.x version remains licensed.`,
      "You may not resell, sublicense, distribute, reverse engineer, or use a personal license as a shared organization license except where applicable law does not allow that restriction.",
    ],
  },
  {
    title: "Trial",
    body: [
      `The trial lasts ${productFacts.trialLength}. It is intended for evaluating CmdTab before purchase and does not create a paid license.`,
      "Trial availability may require online registration. Changing local clocks, identifiers, or stored entitlement data to extend a trial is not permitted.",
    ],
  },
  {
    title: "Devices, deactivation, and recovery",
    body: [
      `A license can have up to ${productFacts.licensedMacs} active Macs. If every slot is in use, deactivate an old Mac in the license portal before activating another one.`,
      "Device deactivation frees a slot immediately. License recovery is authenticated through the email address used at checkout; the public recovery form gives the same response whether or not an address has a matching purchase.",
      "If self-service recovery or deactivation is unavailable, use the Help page. CmdTab may request enough purchase information to verify ownership but will never ask for your account password.",
    ],
  },
  {
    title: "Refunds and revocation",
    body: [
      `You may request a ${productFacts.refundPolicy} from the Help page. Refund eligibility is measured from the purchase timestamp and may also be governed by mandatory consumer law.`,
      "A partial refund does not revoke the license. A full refund, chargeback, payment dispute, fraud determination, or manual revocation ends the license and may leave a non-personal revocation record so access is not restored later.",
    ],
  },
  {
    title: "Updates and support",
    body: [
      "CmdTab 1.x uses the stable update channel. Update packages must be signed and published through CmdTab's release feed; beta updates are not part of the version 1 offer.",
      "Updates may change behavior to preserve compatibility, security, or platform support. The current minimum macOS version and release notes are published on the Trial and Changelog pages.",
      "Support is provided through the Help page and is not a guarantee of a particular response time or continued support for an unsupported macOS release.",
    ],
  },
  {
    title: "Warranty and liability",
    body: [
      "CmdTab is provided as available and without warranties beyond those required by law. Window close and application quit actions can cause unsaved work to be lost; review the selected target before using them.",
      "To the maximum extent permitted by law, CmdTab is not liable for indirect, incidental, special, or consequential loss. Nothing here excludes rights or liability that cannot legally be excluded.",
    ],
  },
  {
    title: "Privacy, retention, and changes",
    body: [
      "The Privacy page describes optional analytics, app telemetry, product operations, third parties, and the available access or deletion request path.",
      "CmdTab currently keeps purchase, license, activation, fulfilment, fraud-prevention, refund, revocation, and support records while they are needed to operate and recover perpetual licenses. Non-personal order, license, refund, chargeback, dispute, and revocation tombstones may be retained indefinitely so recovery cannot bypass payment or revocation state.",
      "Material changes to these terms apply prospectively and will be shown with a new review date. Terms that applied to an existing purchase remain subject to applicable law.",
    ],
  },
] as const;
