create table if not exists admin_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists app_usage_events (
  id text primary key,
  install_id text not null,
  event_name text not null,
  license_state text not null,
  license_id text,
  app_version text,
  os_version text,
  metadata jsonb,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint app_usage_events_event_name_check
    check (event_name in ('app_activation', 'app_heartbeat', 'license_activated', 'trial_started')),
  constraint app_usage_events_license_state_check
    check (license_state in ('unregistered', 'trial_active', 'trial_expired', 'licensed'))
);

create table if not exists license_fulfillments (
  id text primary key,
  order_identifier text unique,
  order_hash text,
  order_number integer,
  event_name text not null,
  purchaser_email text,
  purchaser_name text,
  product_name text,
  variant_name text,
  receipt_url text,
  currency text,
  total text,
  total_formatted text,
  store_id integer,
  lemonsqueezy_order_id text,
  license_id text,
  license_token text,
  processing_token text,
  delivery_status text not null default 'stored',
  delivery_error text,
  test_mode boolean not null default false,
  fulfilled_at timestamptz,
  refunded_at timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint license_fulfillments_delivery_status_check
    check (delivery_status in ('stored', 'processing', 'delivered', 'failed', 'refunded')),
  constraint license_fulfillments_processing_token_check
    check (delivery_status <> 'processing' or processing_token is not null)
);

create table if not exists license_requests (
  id text primary key,
  email text not null,
  name text,
  purchase_email text,
  reason text not null,
  message text not null,
  metadata jsonb,
  request_id text not null unique,
  notification_status text not null default 'stored',
  notification_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint license_requests_notification_status_check
    check (notification_status in ('stored', 'delivered', 'failed'))
);

create table if not exists site_analytics_events (
  id text primary key,
  event_type text not null,
  event_name text,
  path text not null,
  referrer text,
  context text,
  event_data jsonb,
  visitor_id text,
  session_id text,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint site_analytics_events_event_type_check
    check (event_type in ('pageview', 'event'))
);

create table if not exists trial_claims (
  id text primary key,
  email text not null unique,
  install_id text not null unique,
  app_version text,
  os_version text,
  started_at timestamptz not null,
  ends_at timestamptz not null,
  last_seen_at timestamptz not null default now(),
  reminder_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trial_claims_window_check check (ends_at > started_at)
);

create table if not exists waitlist_signups (
  id text primary key,
  email text not null unique,
  name text,
  source text,
  metadata jsonb,
  request_id text not null,
  notification_status text not null default 'stored',
  notification_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint waitlist_signups_notification_status_check
    check (notification_status in ('stored', 'delivered', 'failed'))
);

alter table trial_claims
  add column if not exists reminder_sent_at timestamptz;

alter table license_fulfillments
  add column if not exists order_hash text,
  add column if not exists anonymized_at timestamptz,
  add column if not exists processing_token text,
  alter column order_identifier drop not null,
  alter column purchaser_email drop not null,
  alter column license_id drop not null,
  alter column license_token drop not null;

update license_fulfillments
set
  delivery_status = 'failed',
  delivery_error = coalesce(delivery_error, 'Processing claim invalidated during ownership-token migration'),
  updated_at = now()
where delivery_status = 'processing'
  and processing_token is null;

update license_fulfillments
set order_hash = encode(sha256(convert_to(order_identifier, 'UTF8')), 'hex')
where order_hash is null
  and order_identifier is not null;

alter table app_usage_events drop constraint if exists app_usage_events_event_name_check;
alter table app_usage_events add constraint app_usage_events_event_name_check
  check (event_name in ('app_activation', 'app_heartbeat', 'license_activated', 'trial_started')) not valid;
alter table app_usage_events drop constraint if exists app_usage_events_license_state_check;
alter table app_usage_events add constraint app_usage_events_license_state_check
  check (license_state in ('unregistered', 'trial_active', 'trial_expired', 'licensed')) not valid;
alter table license_fulfillments drop constraint if exists license_fulfillments_delivery_status_check;
alter table license_fulfillments add constraint license_fulfillments_delivery_status_check
  check (delivery_status in ('stored', 'processing', 'delivered', 'failed', 'refunded')) not valid;
alter table license_fulfillments drop constraint if exists license_fulfillments_order_hash_check;
alter table license_fulfillments add constraint license_fulfillments_order_hash_check
  check (order_hash is null or order_hash ~ '^[0-9a-f]{64}$') not valid;
alter table license_fulfillments drop constraint if exists license_fulfillments_processing_token_check;
alter table license_fulfillments add constraint license_fulfillments_processing_token_check
  check (delivery_status <> 'processing' or processing_token is not null) not valid;
alter table license_requests drop constraint if exists license_requests_notification_status_check;
alter table license_requests add constraint license_requests_notification_status_check
  check (notification_status in ('stored', 'delivered', 'failed')) not valid;
alter table site_analytics_events drop constraint if exists site_analytics_events_event_type_check;
alter table site_analytics_events add constraint site_analytics_events_event_type_check
  check (event_type in ('pageview', 'event')) not valid;
alter table trial_claims drop constraint if exists trial_claims_window_check;
alter table trial_claims add constraint trial_claims_window_check
  check (ends_at > started_at) not valid;
alter table waitlist_signups drop constraint if exists waitlist_signups_notification_status_check;
alter table waitlist_signups add constraint waitlist_signups_notification_status_check
  check (notification_status in ('stored', 'delivered', 'failed')) not valid;

alter table app_usage_events validate constraint app_usage_events_event_name_check;
alter table app_usage_events validate constraint app_usage_events_license_state_check;
alter table license_fulfillments validate constraint license_fulfillments_delivery_status_check;
alter table license_fulfillments validate constraint license_fulfillments_order_hash_check;
alter table license_fulfillments validate constraint license_fulfillments_processing_token_check;
alter table license_requests validate constraint license_requests_notification_status_check;
alter table site_analytics_events validate constraint site_analytics_events_event_type_check;
alter table trial_claims validate constraint trial_claims_window_check;
alter table waitlist_signups validate constraint waitlist_signups_notification_status_check;

create index if not exists admin_settings_updated_at_idx
  on admin_settings (updated_at desc);
create index if not exists app_usage_events_occurred_at_idx
  on app_usage_events (occurred_at desc);
create index if not exists app_usage_events_name_idx
  on app_usage_events (event_name, occurred_at desc);
create index if not exists app_usage_events_install_idx
  on app_usage_events (install_id, occurred_at desc);
create index if not exists license_fulfillments_updated_at_idx
  on license_fulfillments (updated_at desc);
create unique index if not exists license_fulfillments_order_hash_key
  on license_fulfillments (order_hash);
create index if not exists license_fulfillments_status_idx
  on license_fulfillments (delivery_status, updated_at desc);
create index if not exists license_fulfillments_stale_idx
  on license_fulfillments (created_at)
  where delivery_status = 'stored';
create index if not exists license_fulfillments_anonymization_idx
  on license_fulfillments (created_at)
  where anonymized_at is null;
create index if not exists license_requests_updated_at_idx
  on license_requests (updated_at desc);
create index if not exists license_requests_created_at_idx
  on license_requests (created_at);
create unique index if not exists license_requests_request_id_key
  on license_requests (request_id);
create index if not exists license_requests_status_idx
  on license_requests (notification_status, updated_at desc);
create index if not exists site_analytics_events_occurred_at_idx
  on site_analytics_events (occurred_at desc);
create index if not exists site_analytics_events_type_idx
  on site_analytics_events (event_type, occurred_at desc);
create index if not exists site_analytics_events_path_idx
  on site_analytics_events (path, occurred_at desc);
create index if not exists site_analytics_events_name_idx
  on site_analytics_events (event_name, occurred_at desc);
create index if not exists trial_claims_ends_at_idx
  on trial_claims (ends_at);
create index if not exists trial_claims_reminder_due_idx
  on trial_claims (ends_at)
  where reminder_sent_at is null;
create index if not exists waitlist_signups_updated_at_idx
  on waitlist_signups (updated_at desc);
create index if not exists waitlist_signups_created_at_idx
  on waitlist_signups (created_at);
create index if not exists waitlist_signups_status_idx
  on waitlist_signups (notification_status, updated_at desc);
