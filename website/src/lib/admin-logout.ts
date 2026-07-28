export async function completeAdminLogout(
  clearSession: () => Promise<void>,
  recordAudit: () => Promise<unknown>,
  reportAuditFailure: (error: unknown) => void = (error) => {
    console.error("Dashboard logout audit write failed.", error);
  },
) {
  await clearSession();
  try {
    await recordAudit();
  } catch (error) {
    reportAuditFailure(error);
  }
}
