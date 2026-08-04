-- Native telemetry v2: event aggregates are intentionally not linkable to a
-- device, install, license, account, window, or other local content. Retain
-- legacy columns for safe application rollback, but clear their values and
-- make them nullable before the v2 server begins accepting the closed payload.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = current_schema()
      and table_name = 'app_usage_events'
      and column_name = 'install_id'
  ) then
    alter table app_usage_events alter column install_id drop not null;
    update app_usage_events set install_id = null where install_id is not null;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = current_schema()
      and table_name = 'app_usage_events'
      and column_name = 'license_id'
  ) then
    update app_usage_events set license_id = null where license_id is not null;
  end if;
end
$$;
