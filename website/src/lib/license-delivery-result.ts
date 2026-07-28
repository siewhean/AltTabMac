export type DeliveryProviderResult = {
  data?: { id?: string } | null;
  error?: { message?: string } | null;
};

export function requireAcceptedDelivery(result: DeliveryProviderResult) {
  if (result.error || !result.data?.id) {
    throw new Error(
      result.error?.message ?? "The delivery provider did not accept the email.",
    );
  }
  return result.data.id;
}
