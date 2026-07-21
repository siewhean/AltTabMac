import postgres from "postgres";

import { fail, requiredTables } from "./lib.mjs";

const lockId = 4_826_191_338;
const migrationTable = "schema_migrations";
const managedTables = [...requiredTables, migrationTable];
const rolePasswords = [
  ["cmdtab_migrator", "CMDTAB_MIGRATOR_PASSWORD"],
  ["cmdtab_runtime", "CMDTAB_RUNTIME_PASSWORD"],
  ["cmdtab_maintenance", "CMDTAB_MAINTENANCE_PASSWORD"],
  ["cmdtab_backup", "CMDTAB_BACKUP_PASSWORD"],
];

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function requiredSecret(name) {
  const value = process.env[name];
  if (!value || !value.trim()) throw new Error(`${name} is required`);
  return value;
}

function quoteIdentifier(identifier) {
  return `"${identifier.replaceAll('"', '""')}"`;
}

async function executeFormatted(sql, format, ...parameters) {
  const placeholders = parameters.map((_, index) => `$${index + 2}`).join(", ");
  const [row] = await sql.unsafe(
    `select format($1${placeholders ? `, ${placeholders}` : ""}) as statement`,
    [format, ...parameters],
  );
  if (!row?.statement) throw new Error("Failed to construct role statement");
  await sql.unsafe(row.statement);
}

async function configureLoginRole(sql, role, password) {
  const [existing] = await sql`select 1 from pg_roles where rolname = ${role}`;
  const action = existing ? "alter" : "create";
  await executeFormatted(
    sql,
    `${action} role %I with login noinherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls password %L`,
    role,
    password,
  );
}

let sql;
try {
  const adminUrl = requiredEnvironment("DATABASE_ADMIN_URL");
  const passwords = rolePasswords.map(([role, variable]) => [
    role,
    requiredSecret(variable),
  ]);
  sql = postgres(adminUrl, {
    max: 1,
    connect_timeout: 10,
    idle_timeout: 5,
    prepare: false,
    onnotice: () => {},
  });

  await sql`select pg_advisory_lock(${lockId})`;
  try {
    await sql.begin(async (transaction) => {
      const relations = await transaction`
        select table_name
        from information_schema.tables
        where table_schema = 'public'
          and table_name = any(${managedTables}::text[])
      `;
      const present = new Set(relations.map((row) => row.table_name));

      for (const [role, password] of passwords) {
        await configureLoginRole(transaction, role, password);
      }

      const managedRoleNames = rolePasswords.map(([role]) => role);
      const inheritedRoles = await transaction`
        select parent.rolname as granted_role, member.rolname as member_role
        from pg_auth_members membership
        join pg_roles parent on parent.oid = membership.roleid
        join pg_roles member on member.oid = membership.member
        where member.rolname = any(${managedRoleNames}::text[])
      `;
      for (const membership of inheritedRoles) {
        await executeFormatted(
          transaction,
          "revoke %I from %I",
          membership.granted_role,
          membership.member_role,
        );
      }

      const [{ database_name: databaseName, admin_role: adminRole }] = await transaction`
        select current_database() as database_name, current_user as admin_role
      `;
      await executeFormatted(
        transaction,
        "grant cmdtab_migrator to %I with admin option",
        adminRole,
      );
      await executeFormatted(
        transaction,
        "revoke all privileges on database %I from public",
        databaseName,
      );
      for (const role of managedRoleNames) {
        await executeFormatted(
          transaction,
          "revoke all privileges on database %I from %I",
          databaseName,
          role,
        );
      }
      await executeFormatted(
        transaction,
        "grant connect on database %I to cmdtab_migrator, cmdtab_runtime, cmdtab_maintenance, cmdtab_backup",
        databaseName,
      );

      await transaction.unsafe("alter schema public owner to cmdtab_migrator");
      await transaction.unsafe("revoke all on schema public from public");
      await transaction.unsafe(
        "revoke all on schema public from cmdtab_runtime, cmdtab_maintenance, cmdtab_backup",
      );
      await transaction.unsafe(
        "grant usage on schema public to cmdtab_runtime, cmdtab_maintenance, cmdtab_backup",
      );

      for (const table of managedTables.filter((table) => present.has(table))) {
        await transaction.unsafe(
          `alter table public.${quoteIdentifier(table)} owner to cmdtab_migrator`,
        );
        await transaction.unsafe(`revoke all on table public.${quoteIdentifier(table)} from public`);
        await transaction.unsafe(
          `revoke all on table public.${quoteIdentifier(table)} from cmdtab_runtime, cmdtab_maintenance, cmdtab_backup`,
        );
      }

      const presentAppTables = requiredTables.filter((table) => present.has(table));
      const appTableList = presentAppTables
        .map((table) => `public.${quoteIdentifier(table)}`)
        .join(", ");
      if (presentAppTables.length > 0) {
        await transaction.unsafe(
          `grant select, insert, update, delete on table ${appTableList} to cmdtab_runtime`,
        );
        await transaction.unsafe(
          `grant select, update, delete on table ${appTableList} to cmdtab_maintenance`,
        );
      }
      if (present.has(migrationTable)) {
        await transaction.unsafe(
          "grant select on table public.schema_migrations to cmdtab_runtime, cmdtab_maintenance",
        );
      }
      const backupTables = managedTables.filter((table) => present.has(table));
      if (backupTables.length > 0) {
        await transaction.unsafe(
          `grant select on table ${backupTables.map((table) => `public.${quoteIdentifier(table)}`).join(", ")} to cmdtab_backup`,
        );
      }

      await transaction.unsafe(
        "alter default privileges for role cmdtab_migrator in schema public revoke all on tables from public",
      );
      await transaction.unsafe(
        "alter default privileges for role cmdtab_migrator in schema public revoke all on sequences from public",
      );
      await transaction.unsafe(
        "alter default privileges for role cmdtab_migrator in schema public revoke execute on functions from public",
      );
      await transaction.unsafe(
        "alter default privileges for role cmdtab_migrator in schema public revoke all on tables from cmdtab_runtime, cmdtab_maintenance, cmdtab_backup",
      );
      await transaction.unsafe(
        "alter default privileges for role cmdtab_migrator in schema public grant select, insert, update, delete on tables to cmdtab_runtime",
      );
      await transaction.unsafe(
        "alter default privileges for role cmdtab_migrator in schema public grant select, update, delete on tables to cmdtab_maintenance",
      );
      await transaction.unsafe(
        "alter default privileges for role cmdtab_migrator in schema public grant select on tables to cmdtab_backup",
      );
    });
  } finally {
    await sql`select pg_advisory_unlock(${lockId})`;
  }
  console.log(JSON.stringify({ ok: true, operation: "database-configure-roles" }));
} catch (error) {
  fail(error, "database-configure-roles");
} finally {
  if (sql) await sql.end({ timeout: 5 });
}
