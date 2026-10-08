import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";

const base = process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000";
const databaseURL = process.env.DATABASE_URL;
if (!databaseURL || !["127.0.0.1", "localhost", "[::1]"].includes(new URL(databaseURL).hostname)) throw new Error("Use a disposable loopback PostgreSQL database only.");
if (!["127.0.0.1", "localhost", "[::1]"].includes(new URL(base).hostname)) throw new Error("Waitlist mutation checks require a loopback server.");
const sql = postgres(databaseURL, { max: 1 });
const marker = `waitlist-qa-${randomUUID()}`;
const email = `${marker}@example.invalid`;
const headers = { "content-type": "application/json", origin: new URL(base).origin, "x-real-ip": `qa-${marker}` };
const submit = (body, customHeaders = {}) => fetch(`${base}/api/waitlist`, { method: "POST", headers: { ...headers, ...customHeaders }, body: JSON.stringify(body) });
try {
  for (const path of ["/trial", "/buy"]) {
    const result = await fetch(`${base}${path}?utm_source=qa&utm_campaign=waitlist`, { redirect: "manual" });
    assert.equal(result.status, 308);
    assert.match(result.headers.get("location"), /\/waitlist\?utm_source=qa&utm_campaign=waitlist$/);
  }
  assert.equal((await fetch(`${base}/waitlist`)).status, 200);
  const release = await fetch(`${base}/releases/stable.json`);
  assert.equal(release.status, 503);
  const releaseBody = await release.json();
  assert.equal(releaseBody.error, "waitlist_only");
  assert.equal("dmgURL" in releaseBody, false);
  assert.equal((await fetch(`${base}/api/trial/reminder`)).status, 403);
  assert.equal((await fetch(`${base}/api/trial/start`, { method: "POST", headers, body: JSON.stringify({ installId: "a".repeat(64) }) })).status, 403);
  assert.equal((await submit({ email })).status, 400, "explicit waitlist consent required");
  assert.equal((await submit({ email, consent: true }, { origin: "https://attacker.invalid" })).status, 403);
  assert.equal((await submit({ email, consent: true, honeypot: "bot" })).status, 400);
  const payload = { email, consent: true, source: "waitlist_qa", metadata: { utm_source: "qa" } };
  const first = await submit(payload);
  assert.equal(first.status, 200);
  const result = await first.json();
  assert.equal(result.ok, true);
  assert.equal(result.notificationDelivered, false, "run the server without email credentials; no outbound messages allowed");
  const repeat = await submit(payload);
  assert.equal(repeat.status, 200);
  const rows = await sql`select email, source, metadata, notification_status from waitlist_signups where email = ${email}`;
  assert.equal(rows.length, 1);
  assert.equal(rows[0].metadata.consent, "waitlist_updates_v1");
  assert.equal(rows[0].metadata.utm_source, "qa");
  assert.equal(rows[0].notification_status, "failed");
  let limited = false;
  for (let index = 0; index < 7; index++) {
    const response = await submit(payload);
    if (response.status === 429) { assert.ok(response.headers.get("retry-after")); limited = true; break; }
  }
  assert.equal(limited, true, "existing form rate limit must remain enforced");
  console.log("PASS: waitlist redirects, closed trial API, explicit consent, origin protection, honeypot, real persistence, unique email, email outage, rate limit.");
} finally {
  await sql`delete from waitlist_signups where email = ${email}`.catch(() => undefined);
  await sql.end();
}
