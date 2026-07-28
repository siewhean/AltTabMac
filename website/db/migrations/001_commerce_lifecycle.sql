-- CmdTab commerce lifecycle v1. Idempotent and additive for existing installs.
create table if not exists license_fulfillments (
  id text primary key,
  order_identifier text not null unique,
  order_number integer,
  event_name text not null,
  purchaser_email text not null,
  purchaser_name text,
  product_name text,
  variant_name text,
  receipt_url text,
  currency text,
  total text,
  total_formatted text,
  store_id integer,
  lemonsqueezy_order_id text,
  license_id text not null,
  license_token text not null,
  delivery_status text not null default 'stored',
  delivery_error text,
  test_mode boolean not null default false,
  fulfilled_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists license_access_states (
  license_lookup_hash text primary key,
  order_lookup_hash text not null,
  access_status text not null default 'active'
    check (access_status in ('active', 'partial_refund', 'revoked')),
  reason text,
  refunded_amount bigint,
  order_total bigint,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table license_fulfillments
  add column if not exists order_lookup_hash text,
  add column if not exists license_lookup_hash text,
  add column if not exists email_lookup_hash text,
  add column if not exists activation_credential_hash text,
  add column if not exists lifecycle_backfilled_at timestamptz;

create unique index if not exists license_fulfillments_activation_credential_idx
  on license_fulfillments (activation_credential_hash)
  where activation_credential_hash is not null;

create unique index if not exists license_fulfillments_order_lookup_idx
  on license_fulfillments (order_lookup_hash)
  where order_lookup_hash is not null;

create index if not exists license_fulfillments_email_lookup_idx
  on license_fulfillments (email_lookup_hash)
  where email_lookup_hash is not null;

create unique index if not exists license_access_states_order_idx
  on license_access_states (order_lookup_hash);

create table if not exists license_activations (
  id text primary key,
  license_lookup_hash text not null,
  device_lookup_hash text not null,
  device_name text not null,
  activated_at timestamptz not null default now(),
  deactivated_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (license_lookup_hash, device_lookup_hash)
);

create index if not exists license_activations_active_idx
  on license_activations (license_lookup_hash, activated_at)
  where deactivated_at is null;

create table if not exists license_delivery_outbox (
  id text primary key,
  dedupe_key text not null unique,
  kind text not null check (kind in ('license_delivery', 'license_recovery')),
  recipient_email text not null,
  payload jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'delivered', 'failed', 'dead')),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  last_error text,
  delivered_at timestamptz,
  claim_token text,
  lease_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table license_delivery_outbox
  add column if not exists claim_token text,
  add column if not exists lease_expires_at timestamptz;

create index if not exists license_delivery_outbox_due_idx
  on license_delivery_outbox (available_at, created_at)
  where status in ('pending', 'failed');

create index if not exists license_delivery_outbox_lease_idx
  on license_delivery_outbox (lease_expires_at)
  where status = 'processing';

create table if not exists license_recovery_requests (
  id text primary key,
  email_lookup_hash text not null,
  request_fingerprint text not null,
  created_at timestamptz not null default now()
);

create index if not exists license_recovery_requests_recent_idx
  on license_recovery_requests (email_lookup_hash, created_at desc);

-- Persistent public-form and ingest throttling. These tables make abuse controls
-- survive serverless cold starts and prevent production from silently falling
-- back to process-local memory.
create table if not exists ingest_rate_limits (
  bucket_key text not null,
  window_start bigint not null,
  event_count integer not null check (event_count > 0),
  expires_at timestamptz not null,
  primary key (bucket_key, window_start)
);

create index if not exists ingest_rate_limits_expiry_idx
  on ingest_rate_limits (expires_at);

create table if not exists request_deduplication (
  fingerprint text primary key,
  expires_at timestamptz not null
);

create index if not exists request_deduplication_expiry_idx
  on request_deduplication (expires_at);
