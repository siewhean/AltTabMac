import {
  compareMigrations,
  fail,
  loadMigrations,
  readAppliedMigrations,
  requiredColumns,
  requiredConstraintDefinitions,
  requiredConstraints,
  requiredIndexes,
  requiredTables,
  normalizeConstraintDefinition,
  withConnection,
} from "./lib.mjs";

try {
  await withConnection(async (sql) => {
    const files = await loadMigrations();
    const applied = await readAppliedMigrations(sql);
    const history = compareMigrations(files, applied);
    const tables = await sql`
      select table_name
      from information_schema.tables
      where table_schema = 'public'
        and table_name = any(${requiredTables}::text[])
    `;
    const present = new Set(tables.map((row) => row.table_name));
    const missingTables = requiredTables.filter((name) => !present.has(name));
    const indexes = await sql`
      select indexname
      from pg_indexes
      where schemaname = 'public'
        and indexname = any(${requiredIndexes}::text[])
    `;
    const presentIndexes = new Set(indexes.map((row) => row.indexname));
    const missingIndexes = requiredIndexes.filter((name) => !presentIndexes.has(name));
    const constraints = await sql`
      select conname, convalidated, pg_get_constraintdef(oid, true) as definition
      from pg_constraint
      where connamespace = 'public'::regnamespace
        and conname = any(${requiredConstraints}::text[])
    `;
    const presentConstraints = new Set(constraints.map((row) => row.conname));
    const missingConstraints = requiredConstraints.filter(
      (name) => !presentConstraints.has(name),
    );
    const unvalidatedConstraints = constraints
      .filter((row) => !row.convalidated)
      .map((row) => row.conname);
    const constraintByName = new Map(constraints.map((row) => [row.conname, row]));
    const invalidConstraints = requiredConstraints.filter((name) => {
      const actual = constraintByName.get(name);
      return actual && normalizeConstraintDefinition(actual.definition) !==
        normalizeConstraintDefinition(requiredConstraintDefinitions[name]);
    });
    const columns = await sql`
      select table_name, column_name, is_nullable, udt_name, column_default
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'license_fulfillments'
    `;
    const columnByName = new Map(
      columns.map((row) => [`${row.table_name}.${row.column_name}`, row]),
    );
    const invalidColumns = requiredColumns
      .filter((column) => {
        const actual = columnByName.get(`${column.table}.${column.column}`);
        return !actual ||
          (actual.is_nullable === "YES") !== column.nullable ||
          actual.udt_name !== column.type ||
          (actual.column_default ?? null) !== column.default;
      })
      .map((column) => `${column.table}.${column.column}`);
    const ok =
      history.pending.length === 0 &&
      history.changed.length === 0 &&
      history.missing.length === 0 &&
      missingTables.length === 0 &&
      missingIndexes.length === 0 &&
      missingConstraints.length === 0 &&
      unvalidatedConstraints.length === 0 &&
      invalidConstraints.length === 0 &&
      invalidColumns.length === 0;
    console.log(JSON.stringify({
      ok,
      connectivity: "ok",
      migrations: {
        pending: history.pending.map((item) => item.name),
        changed: history.changed.map((item) => item.name),
        missing: history.missing.map((item) => item.name),
      },
      missingTables,
      missingIndexes,
      missingConstraints,
      unvalidatedConstraints,
      invalidConstraints,
      invalidColumns,
    }, null, 2));
    if (!ok) process.exitCode = 1;
  }, "DATABASE_MAINTENANCE_URL");
} catch (error) {
  fail(error, "database-check");
}
