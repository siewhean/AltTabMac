export function waitlistRedirectPath(params: Record<string, string | string[] | undefined>) {
  const query = new URLSearchParams();
  for (const key of ["utm_source", "utm_medium", "utm_campaign", "utm_content"]) {
    const value = params[key];
    if (typeof value === "string" && /^[a-z0-9._-]{1,120}$/i.test(value)) query.set(key, value);
  }
  return query.size ? `/waitlist?${query.toString()}` : "/waitlist";
}
