import { getSql, isDatabaseConfigured } from "@/lib/postgres";
import { getSiteAnalyticsOverview } from "@/lib/site-analytics-store";

export type DiscoveryBreakdownItem = {
  label: string;
  count: number;
};

export type AIDiscoveryOverview = {
  pageviews30d: number;
  visitors30d: number;
  sources: DiscoveryBreakdownItem[];
  landingPages: DiscoveryBreakdownItem[];
};

export function isDiscoveryAnalyticsConfigured() {
  return isDatabaseConfigured();
}

export async function getAIDiscoveryOverview(days = 30): Promise<AIDiscoveryOverview> {
  if (!isDatabaseConfigured()) {
    return {
      pageviews30d: 0,
      visitors30d: 0,
      sources: [],
      landingPages: [],
    };
  }

  // Reuse the main analytics store's idempotent schema setup before querying
  // the event_data discovery labels added by the client tracker.
  await getSiteAnalyticsOverview();

  const sql = getSql();
  const safeDays = Math.max(1, Math.min(days, 365));

  const [summary] = await sql<
    {
      pageviews: number;
      visitors: number;
    }[]
  >`
    select
      count(*)::int as pageviews,
      count(distinct coalesce(nullif(visitor_id, ''), session_id))::int as visitors
    from site_analytics_events
    where event_type = 'pageview'
      and occurred_at >= now() - (${safeDays} * interval '1 day')
      and coalesce(event_data ->> 'discoverySource', '') in (
        'chatgpt',
        'perplexity',
        'microsoft_copilot',
        'google_gemini',
        'claude'
      )
  `;

  const sources = await sql<DiscoveryBreakdownItem[]>`
    select
      event_data ->> 'discoverySource' as label,
      count(*)::int as count
    from site_analytics_events
    where event_type = 'pageview'
      and occurred_at >= now() - (${safeDays} * interval '1 day')
      and coalesce(event_data ->> 'discoverySource', '') in (
        'chatgpt',
        'perplexity',
        'microsoft_copilot',
        'google_gemini',
        'claude'
      )
    group by 1
    order by count desc, label asc
  `;

  const landingPages = await sql<DiscoveryBreakdownItem[]>`
    select
      path as label,
      count(*)::int as count
    from site_analytics_events
    where event_type = 'pageview'
      and occurred_at >= now() - (${safeDays} * interval '1 day')
      and coalesce(event_data ->> 'discoverySource', '') in (
        'chatgpt',
        'perplexity',
        'microsoft_copilot',
        'google_gemini',
        'claude'
      )
    group by path
    order by count desc, path asc
    limit 12
  `;

  return {
    pageviews30d: summary?.pageviews ?? 0,
    visitors30d: summary?.visitors ?? 0,
    sources,
    landingPages,
  };
}
