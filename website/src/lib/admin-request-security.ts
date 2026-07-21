const MAX_ADMIN_FORM_BYTES = 4 * 1024;

export class InvalidAdminRequestError extends Error {}

export function isSameOriginAdminRequest(request: Request) {
  const requestOrigin = new URL(request.url).origin;
  const origin = request.headers.get("origin");
  const referer = request.headers.get("referer");

  if (origin) return origin === requestOrigin;
  if (referer) {
    try {
      return new URL(referer).origin === requestOrigin;
    } catch {
      return false;
    }
  }

  const fetchSite = request.headers.get("sec-fetch-site")?.toLowerCase();
  return fetchSite === "same-origin";
}

export async function readAdminForm(request: Request) {
  const contentType = request.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.startsWith("application/x-www-form-urlencoded")) {
    throw new InvalidAdminRequestError("Unsupported form content type.");
  }

  const declaredLength = Number.parseInt(request.headers.get("content-length") ?? "", 10);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_ADMIN_FORM_BYTES) {
    throw new InvalidAdminRequestError("Form is too large.");
  }

  const body = await request.text();
  if (Buffer.byteLength(body, "utf8") > MAX_ADMIN_FORM_BYTES) {
    throw new InvalidAdminRequestError("Form is too large.");
  }

  return new URLSearchParams(body);
}
