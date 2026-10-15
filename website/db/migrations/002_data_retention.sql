-- CmdTab data retention v1 (owner decision 2026-10-15). Idempotent and
-- additive. The runtime schema step in src/lib/trial-claim-store.ts applies
-- the same DDL, so production picks it up on the next trial request or
-- retention purge even if this file is not applied by hand.
--
-- trial_claims rows are created lazily by the website; create the base table
-- here too so this file can be applied to an empty database.
create table if not exists trial_claims (
  id text primary key,
  email text unique,
  install_id text not null unique,
  app_version text,
  os_version text,
  started_at timestamptz not null,
  ends_at timestamptz not null,
  last_seen_at timestamptz not null default now(),
  reminder_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table trial_claims
  add column if not exists reminder_sent_at timestamptz,
  add column if not exists hardware_id text,
  -- Set when the retention purge anonymises a claim 90 days after it ended.
  add column if not exists anonymized_at timestamptz;

create unique index if not exists trial_claims_hardware_idx
  on trial_claims (hardware_id) where hardware_id is not null;

-- Anonymised claims keep only hashed identifiers and trial dates; the email
-- is removed. The unique constraint still applies to the remaining emails.
alter table trial_claims alter column email drop not null;
