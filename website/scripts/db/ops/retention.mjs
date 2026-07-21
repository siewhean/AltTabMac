import { createHash } from "node:crypto";

import { fail, withConnection } from "./lib.mjs";

function boundedInteger(name, fallback, minimum, maximum) {
  const raw = process.env[name]?.trim();
  const value = raw ? Number.parseInt(raw, 10) : fallback;
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer between ${minimum} and ${maximum}`);
  }
  return value;
}

try {
  const batchSize = boundedInteger("DB_RETENTION_BATCH_SIZE", 500, 1, 5_000);
  await withConnection(async (sql) => {
    const analytics = await sql`
      with victims as (
        select id from site_analytics_events
        where occurred_at < now() - interval '90 days'
        order by occurred_at
        limit ${batchSize}
        for update skip locked
      )
      delete from site_analytics_events target
      using victims
      where target.id = victims.id
      returning target.id
    `;
    const usage = await sql`
      with victims as (
        select id from app_usage_events
        where occurred_at < now() - interval '180 days'
        order by occurred_at
        limit ${batchSize}
        for update skip locked
      )
      delete from app_usage_events target
      using victims
      where target.id = victims.id
      returning target.id
    `;
    const trialClaims = await sql`
      with victims as (
        select id from trial_claims
        where ends_at < now() - interval '24 months'
        order by ends_at
        limit ${batchSize}
        for update skip locked
      )
      delete from trial_claims target
      using victims
      where target.id = victims.id
      returning target.id
    `;
    const licenseRequests = await sql`
      with victims as (
        select id from license_requests
        where created_at < now() - interval '24 months'
        order by created_at
        limit ${batchSize}
        for update skip locked
      )
      delete from license_requests target
      using victims
      where target.id = victims.id
      returning target.id
    `;
    const waitlist = await sql`
      with victims as (
        select id from waitlist_signups
        where created_at < now() - interval '12 months'
        order by created_at
        limit ${batchSize}
        for update skip locked
      )
      delete from waitlist_signups target
      using victims
      where target.id = victims.id
      returning target.id
    `;
    const fulfillmentsAnonymized = await sql.begin(async (transaction) => {
      const rows = await transaction`
        select id, order_identifier, order_hash
        from license_fulfillments
        where anonymized_at is null
          and created_at < now() - interval '24 months'
        order by created_at
        limit ${batchSize}
        for update skip locked
      `;
      for (const row of rows) {
        const orderHash = row.order_hash ?? createHash("sha256")
          .update(row.order_identifier ?? row.id)
          .digest("hex");
        await transaction`
          update license_fulfillments
          set
            order_identifier = null,
            order_hash = ${orderHash},
            order_number = null,
            purchaser_email = null,
            purchaser_name = null,
            product_name = null,
            variant_name = null,
            receipt_url = null,
            currency = null,
            total = null,
            total_formatted = null,
            store_id = null,
            lemonsqueezy_order_id = null,
            license_id = null,
            license_token = null,
            delivery_error = null,
            anonymized_at = now(),
            updated_at = now()
          where id = ${row.id}
            and anonymized_at is null
        `;
      }
      return rows.length;
    });
    const fulfillmentsDeleted = await sql`
      with victims as (
        select id from license_fulfillments
        where anonymized_at is not null
          and created_at < now() - interval '7 years'
        order by created_at
        limit ${batchSize}
        for update skip locked
      )
      delete from license_fulfillments target
      using victims
      where target.id = victims.id
      returning target.id
    `;
    console.log(JSON.stringify({
      ok: true,
      operation: "database-retention",
      analyticsDeleted: analytics.length,
      appUsageDeleted: usage.length,
      trialClaimsDeleted: trialClaims.length,
      licenseRequestsDeleted: licenseRequests.length,
      waitlistDeleted: waitlist.length,
      fulfillmentsAnonymized,
      fulfillmentsDeleted: fulfillmentsDeleted.length,
      batchSize,
      policy: {
        analyticsDays: 90,
        appTelemetryDays: 180,
        trialClaimsAfterEndMonths: 24,
        licenseRequestsMonths: 24,
        waitlistMonths: 12,
        fulfillmentAnonymizationMonths: 24,
        anonymizedFulfillmentYears: 7,
      },
    }));
  }, "DATABASE_MAINTENANCE_URL");
} catch (error) {
  fail(error, "database-retention");
}
