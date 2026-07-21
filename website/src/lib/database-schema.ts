export const expectedMigrations = [
  {
    name: "0001_baseline.sql",
    checksum: "96ffbd88613ab1dfaf799dd70e256aaeb4b9fccd7e516bf6583aa0d2cbeae628",
  },
] as const;

export const requiredDatabaseStructure = {
  tables: 7,
  indexes: 22,
  constraints: 21,
  migrationColumns: 3,
  fulfillmentColumns: 7,
} as const;

export const requiredCoreColumns = {
  admin_settings: ["key", "value", "updated_at"],
  app_usage_events: [
    "id", "install_id", "event_name", "license_state", "license_id", "app_version",
    "os_version", "metadata", "occurred_at", "created_at",
  ],
  license_fulfillments: [
    "id", "order_identifier", "order_hash", "order_number", "event_name",
    "purchaser_email", "purchaser_name", "product_name", "variant_name", "receipt_url",
    "currency", "total", "total_formatted", "store_id", "lemonsqueezy_order_id",
    "license_id", "license_token", "processing_token", "delivery_status", "delivery_error",
    "test_mode", "fulfilled_at", "refunded_at", "anonymized_at", "created_at", "updated_at",
  ],
  license_requests: [
    "id", "email", "name", "purchase_email", "reason", "message", "metadata", "request_id",
    "notification_status", "notification_error", "created_at", "updated_at",
  ],
  site_analytics_events: [
    "id", "event_type", "event_name", "path", "referrer", "context", "event_data",
    "visitor_id", "session_id", "occurred_at", "created_at",
  ],
  trial_claims: [
    "id", "email", "install_id", "app_version", "os_version", "started_at", "ends_at",
    "last_seen_at", "reminder_sent_at", "created_at", "updated_at",
  ],
  waitlist_signups: [
    "id", "email", "name", "source", "metadata", "request_id", "notification_status",
    "notification_error", "created_at", "updated_at",
  ],
} as const;

export const requiredConstraintDefinitions = {
  "admin_settings.admin_settings_pkey": "primary key (key)",
  "app_usage_events.app_usage_events_pkey": "primary key (id)",
  "app_usage_events.app_usage_events_event_name_check":
    "check (event_name = any (array['app_activation'::text, 'app_heartbeat'::text, 'license_activated'::text, 'trial_started'::text]))",
  "app_usage_events.app_usage_events_license_state_check":
    "check (license_state = any (array['unregistered'::text, 'trial_active'::text, 'trial_expired'::text, 'licensed'::text]))",
  "license_fulfillments.license_fulfillments_pkey": "primary key (id)",
  "license_fulfillments.license_fulfillments_order_identifier_key":
    "unique (order_identifier)",
  "license_fulfillments.license_fulfillments_delivery_status_check":
    "check (delivery_status = any (array['stored'::text, 'processing'::text, 'delivered'::text, 'failed'::text, 'refunded'::text]))",
  "license_fulfillments.license_fulfillments_order_hash_check":
    "check (order_hash is null or order_hash ~ '^[0-9a-f]{64}$'::text)",
  "license_fulfillments.license_fulfillments_processing_token_check":
    "check (delivery_status <> 'processing'::text or processing_token is not null)",
  "license_requests.license_requests_pkey": "primary key (id)",
  "license_requests.license_requests_request_id_key": "unique (request_id)",
  "license_requests.license_requests_notification_status_check":
    "check (notification_status = any (array['stored'::text, 'delivered'::text, 'failed'::text]))",
  "site_analytics_events.site_analytics_events_pkey": "primary key (id)",
  "site_analytics_events.site_analytics_events_event_type_check":
    "check (event_type = any (array['pageview'::text, 'event'::text]))",
  "trial_claims.trial_claims_pkey": "primary key (id)",
  "trial_claims.trial_claims_email_key": "unique (email)",
  "trial_claims.trial_claims_install_id_key": "unique (install_id)",
  "trial_claims.trial_claims_window_check": "check (ends_at > started_at)",
  "waitlist_signups.waitlist_signups_pkey": "primary key (id)",
  "waitlist_signups.waitlist_signups_email_key": "unique (email)",
  "waitlist_signups.waitlist_signups_notification_status_check":
    "check (notification_status = any (array['stored'::text, 'delivered'::text, 'failed'::text]))",
} as const;

export const requiredIndexDefinitions = {
  admin_settings_updated_at_idx:
    "create index admin_settings_updated_at_idx on admin_settings using btree (updated_at desc)",
  app_usage_events_install_idx:
    "create index app_usage_events_install_idx on app_usage_events using btree (install_id, occurred_at desc)",
  app_usage_events_name_idx:
    "create index app_usage_events_name_idx on app_usage_events using btree (event_name, occurred_at desc)",
  app_usage_events_occurred_at_idx:
    "create index app_usage_events_occurred_at_idx on app_usage_events using btree (occurred_at desc)",
  license_fulfillments_stale_idx:
    "create index license_fulfillments_stale_idx on license_fulfillments using btree (created_at) where delivery_status = 'stored'",
  license_fulfillments_anonymization_idx:
    "create index license_fulfillments_anonymization_idx on license_fulfillments using btree (created_at) where anonymized_at is null",
  license_fulfillments_status_idx:
    "create index license_fulfillments_status_idx on license_fulfillments using btree (delivery_status, updated_at desc)",
  license_fulfillments_order_hash_key:
    "create unique index license_fulfillments_order_hash_key on license_fulfillments using btree (order_hash)",
  license_fulfillments_updated_at_idx:
    "create index license_fulfillments_updated_at_idx on license_fulfillments using btree (updated_at desc)",
  license_requests_request_id_key:
    "create unique index license_requests_request_id_key on license_requests using btree (request_id)",
  license_requests_created_at_idx:
    "create index license_requests_created_at_idx on license_requests using btree (created_at)",
  license_requests_status_idx:
    "create index license_requests_status_idx on license_requests using btree (notification_status, updated_at desc)",
  license_requests_updated_at_idx:
    "create index license_requests_updated_at_idx on license_requests using btree (updated_at desc)",
  site_analytics_events_name_idx:
    "create index site_analytics_events_name_idx on site_analytics_events using btree (event_name, occurred_at desc)",
  site_analytics_events_occurred_at_idx:
    "create index site_analytics_events_occurred_at_idx on site_analytics_events using btree (occurred_at desc)",
  site_analytics_events_path_idx:
    "create index site_analytics_events_path_idx on site_analytics_events using btree (path, occurred_at desc)",
  site_analytics_events_type_idx:
    "create index site_analytics_events_type_idx on site_analytics_events using btree (event_type, occurred_at desc)",
  trial_claims_ends_at_idx:
    "create index trial_claims_ends_at_idx on trial_claims using btree (ends_at)",
  trial_claims_reminder_due_idx:
    "create index trial_claims_reminder_due_idx on trial_claims using btree (ends_at) where reminder_sent_at is null",
  waitlist_signups_status_idx:
    "create index waitlist_signups_status_idx on waitlist_signups using btree (notification_status, updated_at desc)",
  waitlist_signups_created_at_idx:
    "create index waitlist_signups_created_at_idx on waitlist_signups using btree (created_at)",
  waitlist_signups_updated_at_idx:
    "create index waitlist_signups_updated_at_idx on waitlist_signups using btree (updated_at desc)",
} as const;
