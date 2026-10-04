#!/usr/bin/env node
import { readFile, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import postgres from "postgres";

const artifactDir = path.resolve(process.env.VERIFY_ARTIFACT_DIR || "verification-artifacts");
const databaseUrl = process.env.DATABASE_URL || process.env.POSTGRES_URL || process.env.POSTGRES_PRISMA_URL;
let sql;
try {
  if (!databaseUrl) throw new Error("Analytics persistence verification requires DATABASE_URL");
  const report = JSON.parse(await readFile(path.join(artifactDir, "browser-report.json"), "utf8"));
  const { verificationRunId, rateLimitStatuses } = report.analyticsContractReport || {};
  if (!verificationRunId || !Array.isArray(rateLimitStatuses) || !rateLimitStatuses.includes(429)) {
    throw new Error("Browser report must include this run's analytics marker and rate-limit evidence");
  }
  const accepted = rateLimitStatuses.filter((status) => status === 204).length;
  if (!accepted) throw new Error("Browser run did not accept any analytics events");
  sql = postgres(databaseUrl, { max: 1, connect_timeout: 10, prepare: false });
  const [result] = await sql`
    select count(*)::int as persisted
    from site_analytics_events
    where event_name = 'rate_limit_contract'
      and event_data->>'verificationRunId' = ${verificationRunId}
  `;
  if (result.persisted !== accepted) {
    throw new Error(`Analytics persisted ${result.persisted} events; browser acknowledged ${accepted}`);
  }
  await mkdir(artifactDir, { recursive: true });
  await writeFile(path.join(artifactDir, "analytics-storage-report.json"), JSON.stringify({
    verificationRunId, accepted, persisted: result.persisted, rateLimited: true,
  }, null, 2) + "\n");
  console.log(`Analytics persistence passed: ${accepted} accepted events stored; rate limit returned 429.`);
} catch (error) {
  // PostgreSQL error objects can contain connection details; print bounded diagnostics only.
  console.error(error.code ? `Analytics persistence verification failed (${error.code})` : error.message);
  process.exitCode = 1;
} finally {
  if (sql) await sql.end({ timeout: 5 });
}
