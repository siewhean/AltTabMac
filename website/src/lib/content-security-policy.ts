function policyDirectives(
  scriptSources: string,
  styleElementSources: string,
  production: boolean,
) {
  const developmentScriptPolicy = production ? "" : " 'unsafe-eval'";
  return [
    "default-src 'self'",
    "base-uri 'self'",
    `connect-src 'self'${production ? "" : " ws: wss:"}`,
    "font-src 'self' data:",
    "frame-src 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    "img-src 'self' data: blob:",
    "manifest-src 'self'",
    "media-src 'self' blob:",
    "object-src 'none'",
    `script-src ${scriptSources}${developmentScriptPolicy}`,
    `style-src-elem ${styleElementSources}`,
    "style-src-attr 'unsafe-inline'",
    "worker-src 'self' blob:",
    "upgrade-insecure-requests",
  ].join("; ");
}

/**
 * Strict per-request policy for dynamically rendered surfaces (the
 * authenticated dashboard): only nonce-carrying scripts and what they load run.
 */
export function contentSecurityPolicy(
  nonce: string,
  production = process.env.NODE_ENV === "production",
) {
  if (!/^[A-Za-z0-9+/=_-]+$/.test(nonce)) {
    throw new Error("CSP nonce contains unsupported characters.");
  }
  return policyDirectives(
    `'self' 'nonce-${nonce}' 'strict-dynamic'`,
    `'self' 'nonce-${nonce}'`,
    production,
  );
}

/**
 * Policy for statically prerendered marketing pages. Build-time pages cannot
 * carry a request nonce, and the App Router hydrates them with inline
 * payload scripts, so same-origin and inline scripts are allowed (the
 * documented Next.js approach for static pages). These pages render no user
 * data and hold no session; scripts from other origins, plugins, framing, and
 * cross-origin form posts remain blocked.
 */
export function staticContentSecurityPolicy(
  production = process.env.NODE_ENV === "production",
) {
  return policyDirectives("'self' 'unsafe-inline'", "'self' 'unsafe-inline'", production);
}
