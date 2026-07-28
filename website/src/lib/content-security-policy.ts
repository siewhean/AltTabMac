export function contentSecurityPolicy(
  nonce: string,
  production = process.env.NODE_ENV === "production",
) {
  if (!/^[A-Za-z0-9+/=_-]+$/.test(nonce)) {
    throw new Error("CSP nonce contains unsupported characters.");
  }
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
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${developmentScriptPolicy}`,
    `style-src-elem 'self' 'nonce-${nonce}'`,
    "style-src-attr 'unsafe-inline'",
    "worker-src 'self' blob:",
    "upgrade-insecure-requests",
  ].join("; ");
}
